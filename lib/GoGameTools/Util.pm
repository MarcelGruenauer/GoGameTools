package GoGameTools::Util;
use GoGameTools::features;
use GoGameTools;
use GoGameTools::Log;
use File::Spec;
use File::Path qw(make_path);
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
      load_viewer_class);
}

sub get_options (%args) {
    my @extra_opts = @{ $args{extra_opts} // [] };
    my %opt;
    GetOptions(\%opt, @extra_opts, qw(log=s help|h man version))
      or pod2usage(-exitval => 2);
    pod2usage(-exitval => 1) if $opt{help};
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

sub slurp ($filename) {

    # If there is an encoding problem like
    #   UTF-8 "\xC9" does not map to Unicode at
    # we want to see the filename where the problem occurred.
    local $SIG{__WARN__} = sub {
        my $message = shift;
        print STDERR "$filename: $message";
    };
    open my $fh, '<:encoding(UTF-8)', $filename
      or fatal("can't open $filename: $!");
    local $/;
    my $contents = <$fh>;
    close $fh or fatal("can't close $filename: $!");
    return $contents;
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
    my $viewer_class = "GoGameTools::GenerateProblems::Viewer::$viewer";
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

1;
