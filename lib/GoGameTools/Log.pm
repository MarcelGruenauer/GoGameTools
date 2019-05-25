package GoGameTools::Log;
use GoGameTools::features;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(set_log_level fatal warning info debug);
}

# 0  = only fatal() and warning()
# 1  = also info()
# 2+ = also debug()
my $log_level = 0;

sub _make_message ($message) {
    1 while chomp $message;
    my $time = localtime();
    return "$time $message\n";
}

sub _write ($message, $is_fatal = 0) {

    # You can set $GoGameTools::Log::mock = 1 and then inspect the
    # @GoGameTools::Log::log. In that case, the message will not be printed to
    # STDERR and it will not have a timestamp. This makes testing easier.
    if (our $mock) {
        push our(@log), $message;
    } else {
        if ($is_fatal) {
            die _make_message($message);
        } else {
            warn _make_message($message);
        }
    }
}

sub set_log_level ($level) {
    fatal('log level must be a single digit') unless $level =~ /^\d$/;
    $log_level = $level;
}

sub fatal ($message) {
    _write($message, 1);
}

sub warning ($message) {
    _write($message);
}

sub info ($message) {
    _write($message) if $log_level >= 1;
}

sub debug ($message) {
    _write($message) if $log_level >= 2;
}
1;
__END__

add tests for this package

also use it in the site's Makefile
