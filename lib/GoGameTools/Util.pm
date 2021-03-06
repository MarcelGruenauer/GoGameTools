package GoGameTools::Util;
use GoGameTools::features;
use GoGameTools;
use GoGameTools::Log;
use Digest::SHA qw(sha1_hex);
use File::Spec;
use File::Path qw(make_path);
use Path::Tiny;
use Getopt::Long;
use Pod::Usage;
use utf8;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      get_options
      slurp
      spew
      load_viewer_class
      absolute_path
      utf8_sha1_hex
    );
}

sub get_options (%args) {
    my @extra_opts = @{ $args{extra_opts} // [] };
    my %opt;
    GetOptions(\%opt, @extra_opts, qw(log=s help|h man version))
      or pod2usage(-exitval => 2);
    pod2usage(-exitval => 1)                                     if $opt{help};
    pod2usage(-exitval => 0, -verbose => 2, -output => \*STDERR) if $opt{man};
    if ($opt{version}) {
        printf "version %s\n", GoGameTools->VERSION;
        return 0;
    }
    if (@ARGV && $args{expect_stdin}) {
        pod2usage(
            -exitval => 2,
            -msg     => 'expect input on STDIN, not non-option arguments'
        );
    }
    if ($args{required}) {
        for my $required ($args{required}->@*) {
            next if defined $opt{$required};
            pod2usage(-exitval => 2, -msg => "Need --$required");
        }
    }
    set_log_level($opt{log}) if defined $opt{log};
    return %opt;
}

# If there is an encoding problem like chars that don't map to UTF-8, we want
# to see the filename where the problem occurred. Path::Tiny then reports the
# detailed message.
sub slurp ($filename, $utf8_mode = 1) {
    local $SIG{__DIE__} = sub {
        print STDERR "$filename: slurp: ";
    };
    if ($utf8_mode) {
        return path($filename)->slurp_utf8;
    } else {
        return path($filename)->slurp;
    }
}

sub spew ($filename, $contents) {
    my ($volume, $directory, $file) = File::Spec->splitpath($filename);
    make_path($volume . $directory);
    open my $fh, '>:encoding(UTF-8)', $filename
      or fatal("can't open $filename for writing: $!");
    print $fh $contents;
    close $fh or fatal("can't close $filename $!");
}

sub load_viewer_class ($viewer) {
    my $viewer_class = "GoGameTools::Porcelain::GenerateProblems::Viewer::$viewer";
    eval "require $viewer_class";
    if ($@) {
        if ($@ =~ /^Can't locate GoGameTools/) {
            fatal("No viewer class found for [$viewer]");
        } else {
            fatal($@);    # some other error
        }
    }
    return $viewer_class;
}

# There is a weird behaviour, at least on macOS, where Cwd returns bytes, not
# decoded UTF-8, for directories that contain UTF-8 characters. And because
# both File::Spec->rel2abs and Path::Tiny->absolute() use Cwd, it affects them
# too. This function works around this behaviour. For relative paths, it gets
# the parent, fixes the encoding and appends the relative filename again.
sub absolute_path ($filename) {
    my $p = path($filename);
    return $p->stringify if $p->is_absolute;
    my $parent = path($filename)->parent->absolute->stringify;
    utf8::decode($parent);
    return path($parent)->child($filename)->stringify;
}

# sha1_hex() can't deal with Unicode, so this version converts it to bytes
sub utf8_sha1_hex ($data) {
    utf8::encode($data);
    return sha1_hex($data);
}
1;
