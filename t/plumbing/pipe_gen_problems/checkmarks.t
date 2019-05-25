#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use Test::More;
my $input = slurp('t/plumbing/pipe_gen_problems/checkmarks.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[nc][pd][qc]AW[qf][qi][rd]C[Big endgame move?]CA[UTF-8]PL[B]SZ[19]
;B[rc]GB[1])
(
;GM[1]FF[4]AB[nc][pd][qc][rc]AW[qf][qi][rd]CA[UTF-8]LB[qd:A][qe:B][rc:1][re:C]PL[W]SZ[19]
;GB[1]W[qe])
(
;GM[1]FF[4]AB[nc][pd][qc][rc][re]AW[qf][qi][rd]C[Play endgame moves.]CA[UTF-8]LB[re:1]PL[W]SZ[19]
;W[qe]
;B[qd]
;GB[1]W[rf])
(
;GM[1]FF[4]AB[nc][pd][qc][rc]AW[qf][qi][rd]C[Play endgame moves.]CA[UTF-8]PL[B]SZ[19]
;B[re]
;W[qe]
;B[qd]
;W[rf]
;B[sd]GB[1])
(
;GM[1]FF[4]AB[nc][pd][qc]AW[qf][qi][rd]C[Big endgame move?]CA[UTF-8]PL[W]SZ[19]
;GB[1]W[rc])
EODATA
gen_problems_ok(checkmarks => $input, $expect);
done_testing;
