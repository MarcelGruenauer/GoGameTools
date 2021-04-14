use 5.008001;
use strict;
use warnings;

package Path::Tiny;
# ABSTRACT: File path utility

our $VERSION = '0.118';

# Dependencies
use Config;
use Exporter 5.57   (qw/import/);
use File::Spec 0.86 ();          # shipped with 5.8.1
use Carp ();

our @EXPORT    = qw/path/;
our @EXPORT_OK = qw/cwd rootdir tempfile tempdir/;

use constant {
    PATH     => 0,
    CANON    => 1,
    VOL      => 2,
    DIR      => 3,
    FILE     => 4,
    TEMP     => 5,
    IS_WIN32 => ( $^O eq 'MSWin32' ),
};

use overload (
    q{""}    => sub    { $_[0]->[PATH] },
    bool     => sub () { 1 },
    fallback => 1,
);

# FREEZE/THAW per Sereal/CBOR/Types::Serialiser protocol
sub FREEZE { return $_[0]->[PATH] }
sub THAW   { return path( $_[2] ) }
{ no warnings 'once'; *TO_JSON = *FREEZE };

my $HAS_UU; # has Unicode::UTF8; lazily populated

sub _check_UU {
    local $SIG{__DIE__}; # prevent outer handler from being called
    !!eval {
        require Unicode::UTF8;
        Unicode::UTF8->VERSION(0.58);
        1;
    };
}

my $HAS_PU;              # has PerlIO::utf8_strict; lazily populated

sub _check_PU {
    local $SIG{__DIE__}; # prevent outer handler from being called
    !!eval {
        # MUST preload Encode or $SIG{__DIE__} localization fails
        # on some Perl 5.8.8 (maybe other 5.8.*) compiled with -O2.
        require Encode;
        require PerlIO::utf8_strict;
        PerlIO::utf8_strict->VERSION(0.003);
        1;
    };
}

my $HAS_FLOCK = $Config{d_flock} || $Config{d_fcntl_can_lock} || $Config{d_lockf};

# notions of "root" directories differ on Win32: \\server\dir\ or C:\ or \
my $SLASH      = qr{[\\/]};
my $NOTSLASH   = qr{[^\\/]};
my $DRV_VOL    = qr{[a-z]:}i;
my $UNC_VOL    = qr{$SLASH $SLASH $NOTSLASH+ $SLASH $NOTSLASH+}x;
my $WIN32_ROOT = qr{(?: $UNC_VOL $SLASH | $DRV_VOL $SLASH | $SLASH )}x;

sub _win32_vol {
    my ( $path, $drv ) = @_;
    require Cwd;
    my $dcwd = eval { Cwd::getdcwd($drv) }; # C: -> C:\some\cwd
    # getdcwd on non-existent drive returns empty string
    # so just use the original drive Z: -> Z:
    $dcwd = "$drv" unless defined $dcwd && length $dcwd;
    # normalize dwcd to end with a slash: might be C:\some\cwd or D:\ or Z:
    $dcwd =~ s{$SLASH?\z}{/};
    # make the path absolute with dcwd
    $path =~ s{^$DRV_VOL}{$dcwd};
    return $path;
}

# This is a string test for before we have the object; see is_rootdir for well-formed
# object test
sub _is_root {
    return IS_WIN32() ? ( $_[0] =~ /^$WIN32_ROOT\z/ ) : ( $_[0] eq '/' );
}

BEGIN {
    *_same = IS_WIN32() ? sub { lc( $_[0] ) eq lc( $_[1] ) } : sub { $_[0] eq $_[1] };
}

# mode bits encoded for chmod in symbolic mode
my %MODEBITS = ( om => 0007, gm => 0070, um => 0700 ); ## no critic
{ my $m = 0; $MODEBITS{$_} = ( 1 << $m++ ) for qw/ox ow or gx gw gr ux uw ur/ };

sub _symbolic_chmod {
    my ( $mode, $symbolic ) = @_;
    for my $clause ( split /,\s*/, $symbolic ) {
        if ( $clause =~ m{\A([augo]+)([=+-])([rwx]+)\z} ) {
            my ( $who, $action, $perms ) = ( $1, $2, $3 );
            $who =~ s/a/ugo/g;
            for my $w ( split //, $who ) {
                my $p = 0;
                $p |= $MODEBITS{"$w$_"} for split //, $perms;
                if ( $action eq '=' ) {
                    $mode = ( $mode & ~$MODEBITS{"${w}m"} ) | $p;
                }
                else {
                    $mode = $action eq "+" ? ( $mode | $p ) : ( $mode & ~$p );
                }
            }
        }
        else {
            Carp::croak("Invalid mode clause '$clause' for chmod()");
        }
    }
    return $mode;
}

# flock doesn't work on NFS on BSD or on some filesystems like lustre.
# Since program authors often can't control or detect that, we warn once
# instead of being fatal if we can detect it and people who need it strict
# can fatalize the 'flock' category

#<<< No perltidy
{ package flock; use warnings::register }
#>>>

my $WARNED_NO_FLOCK = 0;

sub _throw {
    my ( $self, $function, $file, $msg ) = @_;
    if (   $function =~ /^flock/
        && $! =~ /operation not supported|function not implemented/i
        && !warnings::fatal_enabled('flock') )
    {
        if ( !$WARNED_NO_FLOCK ) {
            warnings::warn( flock => "Flock not available: '$!': continuing in unsafe mode" );
            $WARNED_NO_FLOCK++;
        }
    }
    else {
        $msg = $! unless defined $msg;
        Path::Tiny::Error->throw( $function, ( defined $file ? $file : $self->[PATH] ),
            $msg );
    }
    return;
}

# cheapo option validation
sub _get_args {
    my ( $raw, @valid ) = @_;
    if ( defined($raw) && ref($raw) ne 'HASH' ) {
        my ( undef, undef, undef, $called_as ) = caller(1);
        $called_as =~ s{^.*::}{};
        Carp::croak("Options for $called_as must be a hash reference");
    }
    my $cooked = {};
    for my $k (@valid) {
        $cooked->{$k} = delete $raw->{$k} if exists $raw->{$k};
    }
    if ( keys %$raw ) {
        my ( undef, undef, undef, $called_as ) = caller(1);
        $called_as =~ s{^.*::}{};
        Carp::croak( "Invalid option(s) for $called_as: " . join( ", ", keys %$raw ) );
    }
    return $cooked;
}

#--------------------------------------------------------------------------#
# Constructors
#--------------------------------------------------------------------------#


sub path {
    my $path = shift;
    Carp::croak("Path::Tiny paths require defined, positive-length parts")
      unless 1 + @_ == grep { defined && length } $path, @_;

    # non-temp Path::Tiny objects are effectively immutable and can be reused
    if ( !@_ && ref($path) eq __PACKAGE__ && !$path->[TEMP] ) {
        return $path;
    }

    # stringify objects
    $path = "$path";

    # expand relative volume paths on windows; put trailing slash on UNC root
    if ( IS_WIN32() ) {
        $path = _win32_vol( $path, $1 ) if $path =~ m{^($DRV_VOL)(?:$NOTSLASH|\z)};
        $path .= "/" if $path =~ m{^$UNC_VOL\z};
    }

    # concatenations stringifies objects, too
    if (@_) {
        $path .= ( _is_root($path) ? "" : "/" ) . join( "/", @_ );
    }

    # canonicalize, but with unix slashes and put back trailing volume slash
    my $cpath = $path = File::Spec->canonpath($path);
    $path =~ tr[\\][/] if IS_WIN32();
    $path = "/" if $path eq '/..'; # for old File::Spec
    $path .= "/" if IS_WIN32() && $path =~ m{^$UNC_VOL\z};

    # root paths must always have a trailing slash, but other paths must not
    if ( _is_root($path) ) {
        $path =~ s{/?\z}{/};
    }
    else {
        $path =~ s{/\z}{};
    }

    # do any tilde expansions
    if ( $path =~ m{^(~[^/]*).*} ) {
        require File::Glob;
        my ($homedir) = File::Glob::bsd_glob($1);
        $homedir =~ tr[\\][/] if IS_WIN32();
        $path =~ s{^(~[^/]*)}{$homedir};
    }

    bless [ $path, $cpath ], __PACKAGE__;
}


sub new { shift; path(@_) }


sub cwd {
    require Cwd;
    return path( Cwd::getcwd() );
}


sub rootdir { path( File::Spec->rootdir ) }


sub tempfile {
    shift if @_ && $_[0] eq 'Path::Tiny'; # called as method
    my $opts = ( @_ && ref $_[0] eq 'HASH' ) ? shift @_ : {};
    $opts = _get_args( $opts, qw/realpath/ );

    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);
    # File::Temp->new demands TEMPLATE
    $args->{TEMPLATE} = $maybe_template->[0] if @$maybe_template;

    require File::Temp;
    my $temp = File::Temp->new( TMPDIR => 1, %$args );
    close $temp;
    my $self = $opts->{realpath} ? path($temp)->realpath : path($temp)->absolute;
    $self->[TEMP] = $temp;                # keep object alive while we are
    return $self;
}

sub tempdir {
    shift if @_ && $_[0] eq 'Path::Tiny'; # called as method
    my $opts = ( @_ && ref $_[0] eq 'HASH' ) ? shift @_ : {};
    $opts = _get_args( $opts, qw/realpath/ );

    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);

    # File::Temp->newdir demands leading template
    require File::Temp;
    my $temp = File::Temp->newdir( @$maybe_template, TMPDIR => 1, %$args );
    my $self = $opts->{realpath} ? path($temp)->realpath : path($temp)->absolute;
    $self->[TEMP] = $temp;                # keep object alive while we are
    # Some ActiveState Perls for Windows break Cwd in ways that lead
    # File::Temp to get confused about what path to remove; this
    # monkey-patches the object with our own view of the absolute path
    $temp->{REALNAME} = $self->[CANON] if IS_WIN32;
    return $self;
}

# normalize the various ways File::Temp does templates
sub _parse_file_temp_args {
    my $leading_template = ( scalar(@_) % 2 == 1 ? shift(@_) : '' );
    my %args = @_;
    %args = map { uc($_), $args{$_} } keys %args;
    my @template = (
          exists $args{TEMPLATE} ? delete $args{TEMPLATE}
        : $leading_template      ? $leading_template
        :                          ()
    );
    return ( \@template, \%args );
}

#--------------------------------------------------------------------------#
# Private methods
#--------------------------------------------------------------------------#

sub _splitpath {
    my ($self) = @_;
    @{$self}[ VOL, DIR, FILE ] = File::Spec->splitpath( $self->[PATH] );
}

sub _resolve_symlinks {
    my ($self) = @_;
    my $new = $self;
    my ( $count, %seen ) = 0;
    while ( -l $new->[PATH] ) {
        if ( $seen{ $new->[PATH] }++ ) {
            $self->_throw( 'readlink', $self->[PATH], "symlink loop detected" );
        }
        if ( ++$count > 100 ) {
            $self->_throw( 'readlink', $self->[PATH], "maximum symlink depth exceeded" );
        }
        my $resolved = readlink $new->[PATH] or $new->_throw( 'readlink', $new->[PATH] );
        $resolved = path($resolved);
        $new = $resolved->is_absolute ? $resolved : $new->sibling($resolved);
    }
    return $new;
}

#--------------------------------------------------------------------------#
# Public methods
#--------------------------------------------------------------------------#


sub absolute {
    my ( $self, $base ) = @_;

    # absolute paths handled differently by OS
    if (IS_WIN32) {
        return $self if length $self->volume;
        # add missing volume
        if ( $self->is_absolute ) {
            require Cwd;
            # use Win32::GetCwd not Cwd::getdcwd because we're sure
            # to have the former but not necessarily the latter
            my ($drv) = Win32::GetCwd() =~ /^($DRV_VOL | $UNC_VOL)/x;
            return path( $drv . $self->[PATH] );
        }
    }
    else {
        return $self if $self->is_absolute;
    }

    # no base means use current directory as base
    require Cwd;
    return path( Cwd::getcwd(), $_[0]->[PATH] ) unless defined $base;

    # relative base should be made absolute; we check is_absolute rather
    # than unconditionally make base absolute so that "/foo" doesn't become
    # "C:/foo" on Windows.
    $base = path($base);
    return path( ( $base->is_absolute ? $base : $base->absolute ), $_[0]->[PATH] );
}


sub append {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;
    my $mode = $args->{truncate} ? ">" : ">>";
    my $fh = $self->filehandle( { locked => 1 }, $mode, $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw('close');
}

sub append_raw {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    $args->{binmode} = ':unix';
    append( $self, $args, @data );
}

sub append_utf8 {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        $args->{binmode} = ":unix";
        append( $self, $args, map { Unicode::UTF8::encode_utf8($_) } @data );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $args->{binmode} = ":unix:utf8_strict";
        append( $self, $args, @data );
    }
    else {
        $args->{binmode} = ":unix:encoding(UTF-8)";
        append( $self, $args, @data );
    }
}


sub assert {
    my ( $self, $assertion ) = @_;
    return $self unless $assertion;
    if ( ref $assertion eq 'CODE' ) {
        local $_ = $self;
        $assertion->()
          or Path::Tiny::Error->throw( "assert", $self->[PATH], "failed assertion" );
    }
    else {
        Carp::croak("argument to assert must be a code reference argument");
    }
    return $self;
}


sub basename {
    my ( $self, @suffixes ) = @_;
    $self->_splitpath unless defined $self->[FILE];
    my $file = $self->[FILE];
    for my $s (@suffixes) {
        my $re = ref($s) eq 'Regexp' ? qr/$s\z/ : qr/\Q$s\E\z/;
        last if $file =~ s/$re//;
    }
    return $file;
}


sub canonpath { $_[0]->[CANON] }


sub cached_temp {
    my $self = shift;
    $self->_throw( "cached_temp", $self, "has no cached File::Temp object" )
      unless defined $self->[TEMP];
    return $self->[TEMP];
}


sub child {
    my ( $self, @parts ) = @_;
    return path( $self->[PATH], @parts );
}


sub children {
    my ( $self, $filter ) = @_;
    my $dh;
    opendir $dh, $self->[PATH] or $self->_throw('opendir');
    my @children = readdir $dh;
    closedir $dh or $self->_throw('closedir');

    if ( not defined $filter ) {
        @children = grep { $_ ne '.' && $_ ne '..' } @children;
    }
    elsif ( $filter && ref($filter) eq 'Regexp' ) {
        @children = grep { $_ ne '.' && $_ ne '..' && $_ =~ $filter } @children;
    }
    else {
        Carp::croak("Invalid argument '$filter' for children()");
    }

    return map { path( $self->[PATH], $_ ) } @children;
}


sub chmod {
    my ( $self, $new_mode ) = @_;

    my $mode;
    if ( $new_mode =~ /\d/ ) {
        $mode = ( $new_mode =~ /^0/ ? oct($new_mode) : $new_mode );
    }
    elsif ( $new_mode =~ /[=+-]/ ) {
        $mode = _symbolic_chmod( $self->stat->mode & 07777, $new_mode ); ## no critic
    }
    else {
        Carp::croak("Invalid mode argument '$new_mode' for chmod()");
    }

    CORE::chmod( $mode, $self->[PATH] ) or $self->_throw("chmod");

    return 1;
}


# XXX do recursively for directories?
sub copy {
    my ( $self, $dest ) = @_;
    require File::Copy;
    File::Copy::copy( $self->[PATH], $dest )
      or Carp::croak("copy failed for $self to $dest: $!");

    return -d $dest ? path( $dest, $self->basename ) : path($dest);
}


sub digest {
    my ( $self, @opts ) = @_;
    my $args = ( @opts && ref $opts[0] eq 'HASH' ) ? shift @opts : {};
    $args = _get_args( $args, qw/chunk_size/ );
    unshift @opts, 'SHA-256' unless @opts;
    require Digest;
    my $digest = Digest->new(@opts);
    if ( $args->{chunk_size} ) {
        my $fh = $self->filehandle( { locked => 1 }, "<", ":unix" );
        my $buf;
        $digest->add($buf) while read $fh, $buf, $args->{chunk_size};
    }
    else {
        $digest->add( $self->slurp_raw );
    }
    return $digest->hexdigest;
}


sub dirname {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return length $self->[DIR] ? $self->[DIR] : ".";
}


sub edit {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/binmode/ );
    Carp::croak("Callback for edit() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    local $_ =
      $self->slurp( exists( $args->{binmode} ) ? { binmode => $args->{binmode} } : () );
    $cb->();
    $self->spew( $args, $_ );

    return;
}

# this is done long-hand to benefit from slurp_utf8 optimizations
sub edit_utf8 {
    my ( $self, $cb ) = @_;
    Carp::croak("Callback for edit_utf8() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    local $_ = $self->slurp_utf8;
    $cb->();
    $self->spew_utf8($_);

    return;
}

sub edit_raw { $_[2] = { binmode => ":unix" }; goto &edit }


sub edit_lines {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/binmode/ );
    Carp::croak("Callback for edit_lines() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    my $binmode = $args->{binmode};
    # get default binmode from caller's lexical scope (see "perldoc open")
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;

    # writing need to follow the link and create the tempfile in the same
    # dir for later atomic rename
    my $resolved_path = $self->_resolve_symlinks;
    my $temp          = path( $resolved_path . $$ . int( rand( 2**31 ) ) );

    my $temp_fh = $temp->filehandle( { exclusive => 1, locked => 1 }, ">", $binmode );
    my $in_fh = $self->filehandle( { locked => 1 }, '<', $binmode );

    local $_;
    while (<$in_fh>) {
        $cb->();
        $temp_fh->print($_);
    }

    close $temp_fh or $self->_throw( 'close', $temp );
    close $in_fh or $self->_throw('close');

    return $temp->move($resolved_path);
}

sub edit_lines_raw { $_[2] = { binmode => ":unix" }; goto &edit_lines }

sub edit_lines_utf8 {
    $_[2] = { binmode => ":raw:encoding(UTF-8)" };
    goto &edit_lines;
}


sub exists { -e $_[0]->[PATH] }

sub is_file { -e $_[0]->[PATH] && !-d _ }

sub is_dir { -d $_[0]->[PATH] }


# Note: must put binmode on open line, not subsequent binmode() call, so things
# like ":unix" actually stop perlio/crlf from being added

sub filehandle {
    my ( $self, @args ) = @_;
    my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
    $args = _get_args( $args, qw/locked exclusive/ );
    $args->{locked} = 1 if $args->{exclusive};
    my ( $opentype, $binmode ) = @args;

    $opentype = "<" unless defined $opentype;
    Carp::croak("Invalid file mode '$opentype'")
      unless grep { $opentype eq $_ } qw/< +< > +> >> +>>/;

    $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $opentype, -1, 1 ) }
      unless defined $binmode;
    $binmode = "" unless defined $binmode;

    my ( $fh, $lock, $trunc );
    if ( $HAS_FLOCK && $args->{locked} && !$ENV{PERL_PATH_TINY_NO_FLOCK} ) {
        require Fcntl;
        # truncating file modes shouldn't truncate until lock acquired
        if ( grep { $opentype eq $_ } qw( > +> ) ) {
            # sysopen in write mode without truncation
            my $flags = $opentype eq ">" ? Fcntl::O_WRONLY() : Fcntl::O_RDWR();
            $flags |= Fcntl::O_CREAT();
            $flags |= Fcntl::O_EXCL() if $args->{exclusive};
            sysopen( $fh, $self->[PATH], $flags ) or $self->_throw("sysopen");

            # fix up the binmode since sysopen() can't specify layers like
            # open() and binmode() can't start with just :unix like open()
            if ( $binmode =~ s/^:unix// ) {
                # eliminate pseudo-layers
                binmode( $fh, ":raw" ) or $self->_throw("binmode (:raw)");
                # strip off real layers until only :unix is left
                while ( 1 < ( my $layers =()= PerlIO::get_layers( $fh, output => 1 ) ) ) {
                    binmode( $fh, ":pop" ) or $self->_throw("binmode (:pop)");
                }
            }

            # apply any remaining binmode layers
            if ( length $binmode ) {
                binmode( $fh, $binmode ) or $self->_throw("binmode ($binmode)");
            }

            # ask for lock and truncation
            $lock  = Fcntl::LOCK_EX();
            $trunc = 1;
        }
        elsif ( $^O eq 'aix' && $opentype eq "<" ) {
            # AIX can only lock write handles, so upgrade to RW and LOCK_EX if
            # the file is writable; otherwise give up on locking.  N.B.
            # checking -w before open to determine the open mode is an
            # unavoidable race condition
            if ( -w $self->[PATH] ) {
                $opentype = "+<";
                $lock     = Fcntl::LOCK_EX();
            }
        }
        else {
            $lock = $opentype eq "<" ? Fcntl::LOCK_SH() : Fcntl::LOCK_EX();
        }
    }

    unless ($fh) {
        my $mode = $opentype . $binmode;
        open $fh, $mode, $self->[PATH] or $self->_throw("open ($mode)");
    }

    do { flock( $fh, $lock ) or $self->_throw("flock ($lock)") } if $lock;
    do { truncate( $fh, 0 ) or $self->_throw("truncate") } if $trunc;

    return $fh;
}


sub is_absolute { substr( $_[0]->dirname, 0, 1 ) eq '/' }

sub is_relative { substr( $_[0]->dirname, 0, 1 ) ne '/' }


sub is_rootdir {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return $self->[DIR] eq '/' && $self->[FILE] eq '';
}


sub iterator {
    my $self = shift;
    my $args = _get_args( shift, qw/recurse follow_symlinks/ );
    my @dirs = $self;
    my $current;
    return sub {
        my $next;
        while (@dirs) {
            if ( ref $dirs[0] eq 'Path::Tiny' ) {
                if ( !-r $dirs[0] ) {
                    # Directory is missing or not readable, so skip it.  There
                    # is still a race condition possible between the check and
                    # the opendir, but we can't easily differentiate between
                    # error cases that are OK to skip and those that we want
                    # to be exceptions, so we live with the race and let opendir
                    # be fatal.
                    shift @dirs and next;
                }
                $current = $dirs[0];
                my $dh;
                opendir( $dh, $current->[PATH] )
                  or $self->_throw( 'opendir', $current->[PATH] );
                $dirs[0] = $dh;
                if ( -l $current->[PATH] && !$args->{follow_symlinks} ) {
                    # Symlink attack! It was a real dir, but is now a symlink!
                    # N.B. we check *after* opendir so the attacker has to win
                    # two races: replace dir with symlink before opendir and
                    # replace symlink with dir before -l check above
                    shift @dirs and next;
                }
            }
            while ( defined( $next = readdir $dirs[0] ) ) {
                next if $next eq '.' || $next eq '..';
                my $path = $current->child($next);
                push @dirs, $path
                  if $args->{recurse} && -d $path && !( !$args->{follow_symlinks} && -l $path );
                return $path;
            }
            shift @dirs;
        }
        return;
    };
}


sub lines {
    my $self    = shift;
    my $args    = _get_args( shift, qw/binmode chomp count/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open<'} unless defined $binmode;
    my $fh = $self->filehandle( { locked => 1 }, "<", $binmode );
    my $chomp = $args->{chomp};
    # XXX more efficient to read @lines then chomp(@lines) vs map?
    if ( $args->{count} ) {
        my ( $counter, $mod, @result ) = ( 0, abs( $args->{count} ) );
        while ( my $line = <$fh> ) {
            $line =~ s/(?:\x{0d}?\x{0a}|\x{0d})\z// if $chomp;
            $result[ $counter++ ] = $line;
            # for positive count, terminate after right number of lines
            last if $counter == $args->{count};
            # for negative count, eventually wrap around in the result array
            $counter %= $mod;
        }
        # reorder results if full and wrapped somewhere in the middle
        splice( @result, 0, 0, splice( @result, $counter ) )
          if @result == $mod && $counter % $mod;
        return @result;
    }
    elsif ($chomp) {
        return map { s/(?:\x{0d}?\x{0a}|\x{0d})\z//; $_ } <$fh>; ## no critic
    }
    else {
        return wantarray ? <$fh> : ( my $count =()= <$fh> );
    }
}

sub lines_raw {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if ( $args->{chomp} && !$args->{count} ) {
        return split /\n/, slurp_raw($self);                    ## no critic
    }
    else {
        $args->{binmode} = ":raw";
        return lines( $self, $args );
    }
}

my $CRLF = qr/(?:\x{0d}?\x{0a}|\x{0d})/;

sub lines_utf8 {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if (   ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) )
        && $args->{chomp}
        && !$args->{count} )
    {
        my $slurp = slurp_utf8($self);
        $slurp =~ s/$CRLF\z//; # like chomp, but full CR?LF|CR
        return split $CRLF, $slurp, -1; ## no critic
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $args->{binmode} = ":unix:utf8_strict";
        return lines( $self, $args );
    }
    else {
        $args->{binmode} = ":raw:encoding(UTF-8)";
        return lines( $self, $args );
    }
}


sub mkpath {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{error} = \$err unless defined $args->{error};
    require File::Path;
    my @dirs = File::Path::make_path( $self->[PATH], $args );
    if ( $err && @$err ) {
        my ( $file, $message ) = %{ $err->[0] };
        Carp::croak("mkpath failed for $file: $message");
    }
    return @dirs;
}


sub move {
    my ( $self, $dst ) = @_;

    return rename( $self->[PATH], $dst )
      || $self->_throw( 'rename', $self->[PATH] . "' -> '$dst" );
}


# map method names to corresponding open mode
my %opens = (
    opena  => ">>",
    openr  => "<",
    openw  => ">",
    openrw => "+<"
);

while ( my ( $k, $v ) = each %opens ) {
    no strict 'refs';
    # must check for lexical IO mode hint
    *{$k} = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        my ($binmode) = @args;
        $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $v, -1, 1 ) }
          unless defined $binmode;
        $self->filehandle( $args, $v, $binmode );
    };
    *{ $k . "_raw" } = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        $self->filehandle( $args, $v, ":raw" );
    };
    *{ $k . "_utf8" } = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        $self->filehandle( $args, $v, ":raw:encoding(UTF-8)" );
    };
}


# XXX this is ugly and coverage is incomplete.  I think it's there for windows
# so need to check coverage there and compare
sub parent {
    my ( $self, $level ) = @_;
    $level = 1 unless defined $level && $level > 0;
    $self->_splitpath unless defined $self->[FILE];
    my $parent;
    if ( length $self->[FILE] ) {
        if ( $self->[FILE] eq '.' || $self->[FILE] eq ".." ) {
            $parent = path( $self->[PATH] . "/.." );
        }
        else {
            $parent = path( _non_empty( $self->[VOL] . $self->[DIR] ) );
        }
    }
    elsif ( length $self->[DIR] ) {
        # because of symlinks, any internal updir requires us to
        # just add more updirs at the end
        if ( $self->[DIR] =~ m{(?:^\.\./|/\.\./|/\.\.\z)} ) {
            $parent = path( $self->[VOL] . $self->[DIR] . "/.." );
        }
        else {
            ( my $dir = $self->[DIR] ) =~ s{/[^\/]+/\z}{/};
            $parent = path( $self->[VOL] . $dir );
        }
    }
    else {
        $parent = path( _non_empty( $self->[VOL] ) );
    }
    return $level == 1 ? $parent : $parent->parent( $level - 1 );
}

sub _non_empty {
    my ($string) = shift;
    return ( ( defined($string) && length($string) ) ? $string : "." );
}


# Win32 and some Unixes need parent path resolved separately so realpath
# doesn't throw an error resolving non-existent basename
sub realpath {
    my $self = shift;
    $self = $self->_resolve_symlinks;
    require Cwd;
    $self->_splitpath if !defined $self->[FILE];
    my $check_parent =
      length $self->[FILE] && $self->[FILE] ne '.' && $self->[FILE] ne '..';
    my $realpath = eval {
        # pure-perl Cwd can carp
        local $SIG{__WARN__} = sub { };
        Cwd::realpath( $check_parent ? $self->parent->[PATH] : $self->[PATH] );
    };
    # parent realpath must exist; not all Cwd::realpath will error if it doesn't
    $self->_throw("resolving realpath")
      unless defined $realpath && length $realpath && -e $realpath;
    return ( $check_parent ? path( $realpath, $self->[FILE] ) : path($realpath) );
}


sub relative {
    my ( $self, $base ) = @_;
    $base = path( defined $base && length $base ? $base : '.' );

    # relative paths must be converted to absolute first
    $self = $self->absolute if $self->is_relative;
    $base = $base->absolute if $base->is_relative;

    # normalize volumes if they exist
    $self = $self->absolute if !length $self->volume && length $base->volume;
    $base = $base->absolute if length $self->volume  && !length $base->volume;

    # can't make paths relative across volumes
    if ( !_same( $self->volume, $base->volume ) ) {
        Carp::croak("relative() can't cross volumes: '$self' vs '$base'");
    }

    # if same absolute path, relative is current directory
    return path(".") if _same( $self->[PATH], $base->[PATH] );

    # if base is a prefix of self, chop prefix off self
    if ( $base->subsumes($self) ) {
        $base = "" if $base->is_rootdir;
        my $relative = "$self";
        $relative =~ s{\A\Q$base/}{};
        return path($relative);
    }

    # base is not a prefix, so must find a common prefix (even if root)
    my ( @common, @self_parts, @base_parts );
    @base_parts = split /\//, $base->_just_filepath;

    # if self is rootdir, then common directory is root (shown as empty
    # string for later joins); otherwise, must be computed from path parts.
    if ( $self->is_rootdir ) {
        @common = ("");
        shift @base_parts;
    }
    else {
        @self_parts = split /\//, $self->_just_filepath;

        while ( @self_parts && @base_parts && _same( $self_parts[0], $base_parts[0] ) ) {
            push @common, shift @base_parts;
            shift @self_parts;
        }
    }

    # if there are any symlinks from common to base, we have a problem, as
    # you can't guarantee that updir from base reaches the common prefix;
    # we must resolve symlinks and try again; likewise, any updirs are
    # a problem as it throws off calculation of updirs needed to get from
    # self's path to the common prefix.
    if ( my $new_base = $self->_resolve_between( \@common, \@base_parts ) ) {
        return $self->relative($new_base);
    }

    # otherwise, symlinks in common or from common to A don't matter as
    # those don't involve updirs
    my @new_path = ( ("..") x ( 0+ @base_parts ), @self_parts );
    return path(@new_path);
}

sub _just_filepath {
    my $self     = shift;
    my $self_vol = $self->volume;
    return "$self" if !length $self_vol;

    ( my $self_path = "$self" ) =~ s{\A\Q$self_vol}{};

    return $self_path;
}

sub _resolve_between {
    my ( $self, $common, $base ) = @_;
    my $path = $self->volume . join( "/", @$common );
    my $changed = 0;
    for my $p (@$base) {
        $path .= "/$p";
        if ( $p eq '..' ) {
            $changed = 1;
            if ( -e $path ) {
                $path = path($path)->realpath->[PATH];
            }
            else {
                $path =~ s{/[^/]+/..\z}{/};
            }
        }
        if ( -l $path ) {
            $changed = 1;
            $path    = path($path)->realpath->[PATH];
        }
    }
    return $changed ? path($path) : undef;
}


sub remove {
    my $self = shift;

    return 0 if !-e $self->[PATH] && !-l $self->[PATH];

    return unlink( $self->[PATH] ) || $self->_throw('unlink');
}


sub remove_tree {
    my ( $self, $args ) = @_;
    return 0 if !-e $self->[PATH] && !-l $self->[PATH];
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{error} = \$err unless defined $args->{error};
    $args->{safe}  = 1     unless defined $args->{safe};
    require File::Path;
    my $count = File::Path::remove_tree( $self->[PATH], $args );

    if ( $err && @$err ) {
        my ( $file, $message ) = %{ $err->[0] };
        Carp::croak("remove_tree failed for $file: $message");
    }
    return $count;
}


sub sibling {
    my $self = shift;
    return path( $self->parent->[PATH], @_ );
}


sub slurp {
    my $self    = shift;
    my $args    = _get_args( shift, qw/binmode/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open<'} unless defined $binmode;
    my $fh = $self->filehandle( { locked => 1 }, "<", $binmode );
    if ( ( defined($binmode) ? $binmode : "" ) eq ":unix"
        and my $size = -s $fh )
    {
        my $buf;
        read $fh, $buf, $size; # File::Slurp in a nutshell
        return $buf;
    }
    else {
        local $/;
        return scalar <$fh>;
    }
}

sub slurp_raw { $_[1] = { binmode => ":unix" }; goto &slurp }

sub slurp_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        return Unicode::UTF8::decode_utf8( slurp( $_[0], { binmode => ":unix" } ) );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $_[1] = { binmode => ":unix:utf8_strict" };
        goto &slurp;
    }
    else {
        $_[1] = { binmode => ":raw:encoding(UTF-8)" };
        goto &slurp;
    }
}


# XXX add "unsafe" option to disable flocking and atomic?  Check benchmarks on append() first.
sub spew {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode/ );
    my $binmode = $args->{binmode};
    # get default binmode from caller's lexical scope (see "perldoc open")
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;

    # spewing need to follow the link
    # and create the tempfile in the same dir
    my $resolved_path = $self->_resolve_symlinks;

    my $temp = path( $resolved_path . $$ . int( rand( 2**31 ) ) );
    my $fh = $temp->filehandle( { exclusive => 1, locked => 1 }, ">", $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw( 'close', $temp->[PATH] );

    return $temp->move($resolved_path);
}

sub spew_raw { splice @_, 1, 0, { binmode => ":unix" }; goto &spew }

sub spew_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        my $self = shift;
        spew(
            $self,
            { binmode => ":unix" },
            map { Unicode::UTF8::encode_utf8($_) } map { ref eq 'ARRAY' ? @$_ : $_ } @_
        );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        splice @_, 1, 0, { binmode => ":unix:utf8_strict" };
        goto &spew;
    }
    else {
        splice @_, 1, 0, { binmode => ":unix:encoding(UTF-8)" };
        goto &spew;
    }
}


# XXX break out individual stat() components as subs?
sub stat {
    my $self = shift;
    require File::stat;
    return File::stat::stat( $self->[PATH] ) || $self->_throw('stat');
}

sub lstat {
    my $self = shift;
    require File::stat;
    return File::stat::lstat( $self->[PATH] ) || $self->_throw('lstat');
}


sub stringify { $_[0]->[PATH] }


sub subsumes {
    my $self = shift;
    Carp::croak("subsumes() requires a defined, positive-length argument")
      unless defined $_[0];
    my $other = path(shift);

    # normalize absolute vs relative
    if ( $self->is_absolute && !$other->is_absolute ) {
        $other = $other->absolute;
    }
    elsif ( $other->is_absolute && !$self->is_absolute ) {
        $self = $self->absolute;
    }

    # normalize volume vs non-volume; do this after absolute path
    # adjustments above since that might add volumes already
    if ( length $self->volume && !length $other->volume ) {
        $other = $other->absolute;
    }
    elsif ( length $other->volume && !length $self->volume ) {
        $self = $self->absolute;
    }

    if ( $self->[PATH] eq '.' ) {
        return !!1; # cwd subsumes everything relative
    }
    elsif ( $self->is_rootdir ) {
        # a root directory ("/", "c:/") already ends with a separator
        return $other->[PATH] =~ m{^\Q$self->[PATH]\E};
    }
    else {
        # exact match or prefix breaking at a separator
        return $other->[PATH] =~ m{^\Q$self->[PATH]\E(?:/|\z)};
    }
}


sub touch {
    my ( $self, $epoch ) = @_;
    if ( !-e $self->[PATH] ) {
        my $fh = $self->openw;
        close $fh or $self->_throw('close');
    }
    if ( defined $epoch ) {
        utime $epoch, $epoch, $self->[PATH]
          or $self->_throw("utime ($epoch)");
    }
    else {
        # literal undef prevents warnings :-(
        utime undef, undef, $self->[PATH]
          or $self->_throw("utime ()");
    }
    return $self;
}


sub touchpath {
    my ($self) = @_;
    my $parent = $self->parent;
    $parent->mkpath unless $parent->exists;
    $self->touch;
}


sub visit {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/recurse follow_symlinks/ );
    Carp::croak("Callback for visit() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';
    my $next  = $self->iterator($args);
    my $state = {};
    while ( my $file = $next->() ) {
        local $_ = $file;
        my $r = $cb->( $file, $state );
        last if ref($r) eq 'SCALAR' && !$$r;
    }
    return $state;
}


sub volume {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[VOL];
    return $self->[VOL];
}

package Path::Tiny::Error;

our @CARP_NOT = qw/Path::Tiny/;

use overload ( q{""} => sub { (shift)->{msg} }, fallback => 1 );

sub throw {
    my ( $class, $op, $file, $err ) = @_;
    chomp( my $trace = Carp::shortmess );
    my $msg = "Error $op on '$file': $err$trace\n";
    die bless { op => $op, file => $file, err => $err, msg => $msg }, $class;
}

1;
