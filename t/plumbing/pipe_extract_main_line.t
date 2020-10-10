#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use Test::More;
use Test::Differences;
my %files;
$files{'extract_main_line-input'} = <<'EODATA';
(;GM[1]FF[4]SZ[19]AP[SmartGo:0.8.9]
PW[Foo]
PB[Bar]
DT[2018-07-09]
KM[6.5]
RU[Simple];B[pd];W[dp];B[pp];W[dd];B[pj]
C[sanrensei]
(;W[nc]
(;B[lc];W[qc];B[qd];W[pc];B[od];W[nb];B[me];W[nq];B[pn]
C[normal])
(;B[qf];W[pb];B[qc];W[kc])
(;B[oe]
C[Takemiya-style]))
(;W[jd];B[jp]
C[rare]))
EODATA
$files{'extract_main_line-expect'} = <<'EODATA';
(;GM[1]FF[4]AP[SmartGo:0.8.9]DT[2018-07-09]KM[6.5]PB[Bar]PW[Foo]RU[Simple]SZ[19];B[pd];W[dp];B[pp];W[dd];B[pj]C[sanrensei];W[nc];B[lc];W[qc];B[qd];W[pc];B[od];W[nb];B[me];W[nq];B[pn]C[normal])
EODATA
pipe_ok($_) for qw(extract_main_line);
done_testing;

sub pipe_ok ($prefix) {
    my $got_sgf =
      pipe_extract_main_line()->(parse_sgf(sgf => $files{"$prefix-input"}))->[0]->as_sgf;
    my $expect_sgf = parse_sgf(sgf => $files{"$prefix-expect"})->[0]->as_sgf;
    eq_or_diff($got_sgf, $expect_sgf, $prefix);
}
