#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/show_choices.sgf');
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
;GM[1]FF[4]AB[md][qd]AW[oc]C[What are good choices for White's next move?]CA[UTF-8]CR[jj]GC[question show_choices task]MN[-1]PL[W]SZ[19]
;CR[ne][oe][pe]W[jj]
;AE[jj]C[The circled White moves are good.]CR[ne][oe][pe]GB[1])
EODATA
gen_problems_ok(show_choices => $input, $expect);
$input = slurp('t/plumbing/pipe_gen_problems/show_choices_at_variation_start.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[qd]CA[UTF-8]LB[qd:1]PL[W]SZ[19]
;W[pd]
;B[od]CR[pc]
;GB[1]W[pc])
(
;GM[1]FF[4]AB[qd]CA[UTF-8]LB[qd:1]PL[W]SZ[19]
;W[pd]
;B[od]CR[pe]
;GB[1]W[pe])
(
;GM[1]FF[4]AB[od][qd]AW[pd]C[What are good choices for White's next move?]CA[UTF-8]CR[jj]GC[question show_choices task]LB[od:3][pd:2][qd:1]MN[-1]PL[W]SZ[19]
;CR[pc][pe]W[jj]
;AE[jj]C[The circled White moves are good.]CR[pc][pe]GB[1])
(
;GM[1]FF[4]AB[qd]CA[UTF-8]LB[qd:1]PL[W]SZ[19]
;W[pd]
;B[oc]
;GB[1]LB[oc:?]W[pc])
EODATA
gen_problems_ok(show_choices_at_variation_start => $input, $expect);
done_testing;
