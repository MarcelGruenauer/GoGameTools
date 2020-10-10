#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use GoGameTools::Log;
use GoGameTools::Porcelain::MakeOpeningTree;
use Test::More;
use Test::Differences;
set_log_level(2);
$GoGameTools::Log::mock = 1;

# mock tree with test filenames
sub input_tree ($sgf) {
    my $collection = parse_sgf(sgf => $sgf);
    my $i          = 1;
    for ($collection->@*) {
        $_->metadata->{filename} = sprintf 'test%d.sgf', $i;
        $i++;
    }
    return $collection;
}

sub porcelain_ok (%args) {
    @GoGameTools::Log::log = ();
    $args{args} //= {};
    my $input     = input_tree($args{input});
    my $porcelain = GoGameTools::Porcelain::MakeOpeningTree->new($args{args}->%*);
    my ($collection) = run_pipe(sub { $input }, $porcelain->run);
    if ($args{expect_sgf}) {
        eq_or_diff $collection->[0]->as_sgf, $args{expect_sgf}, 'assembled SGF';
    }
    if ($args{expect_log}) {
        eq_or_diff \@GoGameTools::Log::log, $args{expect_log}, 'log';
    }

    # my @sgf = map { $_->as_sgf } $collection->@*; use DDP; p @sgf;
    return $collection;
}

sub log_ok (@expect_log) {
}
subtest 'single input tree' => sub {
    porcelain_ok(
        input      => '(;GM[1]FF[4]SZ[19];B[pd];W[dq])',
        args       => { moves => 10, should_add_game_info => 0, should_add_stats => 0 },
        expect_sgf => '(;GM[1]FF[4]CA[UTF-8]SZ[19];B[pd];W[dq])',
        expect_log => ['taking 1 game']
    );
};
subtest 'single input tree; first node has White move' => sub {
    porcelain_ok(
        input      => '(;GM[1]FF[4]SZ[19];W[pd];B[dq])',
        args       => { moves => 10, should_add_game_info => 0, should_add_stats => 0 },
        expect_log => [
            'reject test1.sgf: node 1 has no black move', 'no games meet the criteria'
        ],
    );
};
subtest 'two input trees differing in move 1' => sub {
    porcelain_ok(
        input => join('',
            '(;GM[1]FF[4]DT[2019-01-02]PW[White1]WR[3k]PB[Black1]BR[6k]SZ[19];B[cc];W[dq])',
            '(;GM[1]FF[4]DT[2019-03-04]PW[White2]WR[5d]PB[Black2]BR[2d]SZ[19];B[pd];W[qf])'),
        args       => { moves => 10, should_add_game_info => 0, should_add_stats => 0 },
        expect_sgf => "(;GM[1]FF[4]CA[UTF-8]SZ[19]\n(;B[cc];W[dq])\n(;B[pd];W[qf]))",
        expect_log => ['taking 2 games']
    );
};
subtest 'two input trees differing in move 3' => sub {
    porcelain_ok(
        input      => '(;GM[1]FF[4]SZ[19];B[pd];W[dq])(;GM[1]FF[4]SZ[19];B[pd];W[qf])',
        args       => { moves => 10, should_add_game_info => 0, should_add_stats => 0 },
        expect_sgf => "(;GM[1]FF[4]CA[UTF-8]SZ[19];B[pd]\n(;W[dq])\n(;W[qf]))",
        expect_log => ['taking 2 games']
    );
};
done_testing;
