#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/rate_choices.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[md][qd]AW[oc][oe]CA[UTF-8]LB[oe:1]PL[B]SZ[19]
;B[pf]GB[1])
(
;GM[1]FF[4]AB[md][qd]AW[oc]CA[UTF-8]CR[ne]PL[W]SZ[19]
;W[ne]
;B[pf]
;GB[1]W[qc])
(
;GM[1]FF[4]AB[md][qd]AW[oc]CA[UTF-8]CR[pe]PL[W]SZ[19]
;W[pe]
;B[qe]
;GB[1]W[pf])
(
;GM[1]FF[4]AB[md][qd]AW[oc][pe]CA[UTF-8]CR[pd]LB[pe:1]PL[B]SZ[19]
;B[pd]
;W[od]
;B[oe]GB[1])
(
;GM[1]FF[4]AB[md][qd]AW[oc][qb]CA[UTF-8]LB[qb:1]PL[B]SZ[19]
;B[od]GB[1]LB[qb:?])
(
;GM[1]FF[4]AB[md][qd]AW[oc]C[Which marked moves are good and bad for White?]CA[UTF-8]CR[jj]GC[question rate_choices task]MN[-1]PL[W]SQ[ne][oe][pe][qb]SZ[19]
;CR[ne][oe][pe]MA[qb]W[jj]
;AE[jj]C[The circled White moves are good; the crossed-out move is bad.]CR[ne][oe][pe]GB[1]MA[qb])
EODATA
gen_problems_ok(rate_choices => $input, $expect);
done_testing;
