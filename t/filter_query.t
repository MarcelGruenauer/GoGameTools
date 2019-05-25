#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::FilterQuery;
use Test::More;

# Instead of 'foo', 'bar' and 'baz' use '#orange', '#android' and '#notice'
# because these words start with 'or', 'and' and 'not', so this also tests that
# they are not mistaken for operators.
subtest 'tags' => sub {
    query_ok(query => '#orange', tags => [qw(orange android notice)], expect => 1);
    query_ok(query => '#notice', tags => [qw(orange android)],        expect => 0);
    query_ok(
        query  => '#orange and #android',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#orange and #android and #notice',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#hoge and #android',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => '#orange or #android',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#hoge or #android',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#hoge or #piyo',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => 'not #orange',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => 'not #hoge',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#orange and not #hoge',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => 'not #hoge and not #piyo',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#hoge or not #piyo',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => 'not #orange and not #android',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => 'not #hoge and not #piyo',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => 'not not #orange',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => 'not not #hoge',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => '(#orange)',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '(((#orange)))',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#orange and (#android and #notice)',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '(#orange and #android) and #notice',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#hoge or (#piyo or #orange)',
        tags   => [qw(orange android notice)],
        expect => 1
    );
    query_ok(
        query  => '#orange and (#hoge or #piyo)',
        tags   => [qw(orange android notice)],
        expect => 0
    );
    query_ok(
        query  => '#orange and (#hoge or not #piyo)',
        tags   => [qw(orange android notice)],
        expect => 1
    );
};
subtest 'refs' => sub {
    query_ok(
        query  => '@foo',
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@bar',
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => '@foo/3/4',
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@foo/3/45',
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => '@3/4',
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => '@foo or @bar',
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@foo and @bar',
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => 'not @foo',
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => 'not @bar',
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@foo/3 and not @3/4',
        refs   => [qw(foo/3 foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@foo/3 and not @3/4',
        refs   => [qw(foo/3 foo/3/5)],
        expect => 1
    );
};
subtest 'tags and refs' => sub {
    query_ok(
        query  => '@foo and #orange',
        tags   => [qw(orange android notice)],
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@foo or #hoge',
        tags   => [qw(orange android notice)],
        refs   => [qw(foo/3/4)],
        expect => 1
    );
    query_ok(
        query  => '@orange or #hoge',
        tags   => [qw(orange android notice)],
        refs   => [qw(foo/3/4)],
        expect => 0
    );
    query_ok(
        query  => '#orange and not @bar',
        tags   => [qw(orange android notice)],
        refs   => [qw(foo/3/4)],
        expect => 1
    );
};
subtest 'malformed queries' => sub {
    malformed_query_ok('and');
    malformed_query_ok('or');
    malformed_query_ok('not');
    malformed_query_ok('#orange #android');
    malformed_query_ok('#orange and');
    malformed_query_ok('and #orange');
    malformed_query_ok('#orange and and');
    malformed_query_ok('or #orange');
    malformed_query_ok('#orange or or');
    malformed_query_ok('#orange and or');
    malformed_query_ok('#orange or and');
    malformed_query_ok('not not');
    malformed_query_ok('#orange not');
    malformed_query_ok('#orange not #orange');
    malformed_query_ok('#orange and not');
    malformed_query_ok('#orange or not');
    malformed_query_ok('and or not');
    malformed_query_ok('(#orange');
    malformed_query_ok('#orange)');
    malformed_query_ok('#orange and (#android or #notice))');
};
done_testing;

# $query, @tags, $expect
sub query_ok (%args) {
    $args{$_} //= [] for qw(tags refs);
    my $test_name = sprintf "'%s' (%s) : %s", $args{query},
      join(' ', (map { "\#$_" } $args{tags}->@*), (map { "\@$_" } $args{refs}->@*)),
      ($args{expect} ? 'yes' : 'no');
    my $expr = parse_filter_query($args{query});
    my %sgj = (metadata => { tags => $args{tags}, refs => $args{refs}});
    my $got  = eval_query(expr => $expr, vars => query_vars_from_sgj(\%sgj));
    is $got, $args{expect}, $test_name;
}

sub malformed_query_ok ($query) {
    is parse_filter_query($query), undef, "malformed query '$query'";
}
