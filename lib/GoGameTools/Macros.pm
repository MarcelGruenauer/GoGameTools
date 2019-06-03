package GoGameTools::Macros;
use GoGameTools::features;
use GoGameTools::Color;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      expand_macros
    );
}
my %expansions = (
    explain_eye_count => <<~EOTEXT,
        0 = no eye even if you play first.

        1/2 = one eye if you play first, no eye if the opponent plays first.

        1 = one eye even if the opponent plays first.
        EOTEXT
    unsettled => sub ($color) {
        my $c  = name_for_color_const($color);
        my $oc = name_for_color_const(other_color($color));
        "If $c plays, $c lives. If $oc plays, $c dies.";
    },
    copy_shape => 'Copy this shape.',
);

sub expand_macros ($input) {
    return $input =~ s/\{% \s* (.*?) \s* %\}/ expand_macro($1) /regx;
}

sub expand_macro ($token_str) {
    my @tokens    = split /\s+/, $token_str;
    my $name      = shift @tokens;
    my $expansion = $expansions{$name} // die "no macro $name\n";

    # Expansions can be a string or an anonymous subroutine. If it's a string
    # but there are further tokens, raise an error. Subs get the remaining
    # tokens as arguments.
    #
    # For example, '{% foo %}' either returns the string for 'foo' or calls the
    # sub without args. '{% foo bar baz %}' requires a sub for 'foo' and
    # calls it with '(bar, baz)' as arguments.
    if (ref $expansion eq ref sub { }) {
        return $expansion->(@tokens);
    } else {
        die "macro [$name] does not take arguments\n" if @tokens;
        return $expansion;
    }
}
