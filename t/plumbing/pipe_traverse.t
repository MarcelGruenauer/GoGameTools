#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use Test::More;
use Test::Differences;
my %files;
$files{'uncomment-input'} = <<'EODATA';
(;GM[1]FF[4]CA[UTF-8]AP[CGoban:3]ST[2]
RU[Japanese]SZ[19]KM[0.00]
PW[White]PB[Black]GC[This is the game comment.]C[Comment on empty board.]
(;B[pd]C[Comment on first move.])
(;B[qd]C[Comment on alternative first move.]
;W[dd]
;B[dq]C[Kajiwara would not be happy.]))
EODATA
$files{'uncomment-opt'} = <<'EODATA';
eval
$_->del("C")
EODATA
$files{'uncomment-expect'} = <<'EODATA';
(;RU[Japanese]ST[2]FF[4]CA[UTF-8]GM[1]GC[This is the game comment.]KM[0.00]PB[Black]AP[CGoban:3]SZ[19]PW[White]
(;B[pd])
(;B[qd];W[dd];B[dq]))
EODATA
$files{'game_info-input'} = <<'EODATA';
(;RU[Japanese]ST[2]FF[4]CA[UTF-8]GM[1]GC[This is the game comment.]KM[0.00]PB[Black]AP[CGoban:3]SZ[19]PW[White]
(;B[pd]KM[1.2])
(;B[qd];W[dd];B[dq]))
EODATA
$files{'game_info-opt'} = <<'EODATA';
eval
if (!$_[1]->get_parent_for_node($_)) { $_->del(qw(RU ST GM GC KM PB PW DT AP)); $_->add(FB => 'Foo Bar') }
EODATA
$files{'game_info-expect'} = <<'EODATA';
(;FF[4]CA[UTF-8]FB[Foo Bar]SZ[19]
(;B[pd]KM[1.2])
(;B[qd];W[dd];B[dq]))
EODATA
traverse_ok($_) for qw(uncomment game_info);
done_testing;

sub traverse_ok ($prefix) {
    my %opt = split /\n/ => $files{"$prefix-opt"};
    my $got_sgf =
      pipe_traverse($opt{eval})->(parse_sgf($files{"$prefix-input"}))->[0]->as_sgf;
    my $expect_sgf = parse_sgf($files{"$prefix-expect"})->[0]->as_sgf;
    eq_or_diff($got_sgf, $expect_sgf, $prefix);
}
