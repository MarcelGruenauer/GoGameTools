#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/bad_moves.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[nc][pd]AW[qf][rd]CA[UTF-8]CR[qc]LB[nc:3][pd:1][qf:2][rd:4]PL[B]SZ[19]
;B[qc]GB[1])
(
;GM[1]FF[4]AB[nc][pd]AW[qf][rd]CA[UTF-8]CR[qh]LB[nc:3][pd:1][qf:2][rd:4]PL[B]SZ[19]
;B[qh]
;W[qc]
;B[qe]
;W[re]
;B[pf]
;W[pg]
;B[qg]
;W[rf]
;B[og]GB[1])
(
;GM[1]FF[4]AB[nc][pd]AW[qf]CA[UTF-8]GC[refute_bad_move]LB[nc:3][pd:1][qf:2]PL[W]SZ[19]
;W[rd]
;B[rc]
;W[qc]
;B[qd]
;GB[1]LB[rc:?]W[rb])
(
;GM[1]FF[4]AB[nc][pd]AW[qf][rc]CA[UTF-8]GC[refute_bad_move]LB[nc:3][pd:1][qf:2][rc:4]PL[B]SZ[19]
;B[qc]GB[1]LB[rc:?])
(
;GM[1]FF[4]AB[nc][pd][qd]AW[qf][rc]CA[UTF-8]GC[refute_bad_move]LB[nc:3][pd:1][qd:5][qf:2][rc:4]PL[W]SZ[19]
;GB[1]LB[qd:?][rc:?]W[rd])
EODATA
gen_problems_ok(bad_moves => $input, $expect);
done_testing;
