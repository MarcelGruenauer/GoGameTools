#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input  = slurp('t/plumbing/pipe_gen_problems/has_all_good_responses.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[md][qd]AW[oc][oe]CA[UTF-8]LB[oe:1]PL[B]SZ[19]
;B[pf]GB[1])
(
;GM[1]FF[4]AB[md][qd]AW[oc]CA[UTF-8]MA[oe][pe]PL[W]SZ[19]
;W[ne]
;B[pf]
;GB[1]W[qc])
(
;GM[1]FF[4]AB[md][qd]AW[oc]CA[UTF-8]MA[ne][oe]PL[W]SZ[19]
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
;GM[1]FF[4]AB[md][qd]AW[oc]C[Which marked moves are good for White and which ones are bad?]CA[UTF-8]CR[jj]GC[question rate_choices task]MN[-1]PL[W]SQ[ne][oe][pe][qb]SZ[19]
;CR[ne][oe][pe]MA[qb]W[jj]
;AE[jj]C[The circled White moves are good; the crossed-out move is bad.]CR[ne][oe][pe]GB[1]MA[qb])
(
;GM[1]FF[4]AB[md][qd]AW[oc]C[What are good choices for White's next move?]CA[UTF-8]CR[jj]GC[question show_choices task]MN[-1]PL[W]SZ[19]
;CR[ne][oe][pe]W[jj]
;AE[jj]C[The circled White moves are good.]CR[ne][oe][pe]GB[1])
EODATA
gen_problems_ok(has_all_good_responses => $input, $expect);
$input  = slurp('t/plumbing/pipe_gen_problems/has_the_only_good_response.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[nc][pd][qc][qk][rh]AW[qf][qi][rd]CA[UTF-8]LB[rh:1]PL[W]SZ[19]
;GB[1]W[ri])
(
;GM[1]FF[4]AB[nc][pd][qc][qk]AW[qf][qi][rd]CA[UTF-8]CR[rh]PL[B]SZ[19]
;B[rh]
;W[qh]
;B[ri]GB[1]LB[qh:?])
(
;GM[1]FF[4]AB[nc][pd][qc][qk][rh]AW[qf][qi][rd]C[Which marked moves are good for White and which ones are bad?]CA[UTF-8]CR[jj]GC[question rate_choices task]LB[rh:1]MN[-1]PL[W]SQ[qh][ri]SZ[19]
;CR[ri]MA[qh]W[jj]
;AE[jj]C[The circled White move is good; the crossed-out move is bad.]CR[ri]GB[1]MA[qh])
EODATA
gen_problems_ok(has_the_only_good_response => $input, $expect);
done_testing;
