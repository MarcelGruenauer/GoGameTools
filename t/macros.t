#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Macros;
use Data::Dumper;
use Test::More;
use Test::Differences;
subtest 'string macro without arguments' => sub {
    my $s      = 'before {% explain_eye_count %} after';
    my $result = expand_macros($s);
    like $result, qr/^before 0 = no eye/, 'expansion start';
};
subtest 'exception from string macro with arguments' => sub {
    my $s = 'before {% explain_eye_count foo %} after';
    eval { expand_macros($s) };
    is $@, "macro [explain_eye_count] does not take arguments\n", 'exception';
};
subtest 'subroutine macro' => sub {
    my $s      = '{% unsettled W %}';
    my $result = expand_macros($s);
    is $result, 'White lives or dies by sente.', 'expansion 1';

    # different argument
    $s      = '{% unsettled B %}';
    $result = expand_macros($s);
    is $result, 'Black lives or dies by sente.', 'expansion 2';
};
done_testing;
