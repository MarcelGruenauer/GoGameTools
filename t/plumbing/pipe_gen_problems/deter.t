#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/deter.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[qd]AW[oc]CA[UTF-8]CR[mc]PL[B]SZ[19]
;B[mc]
;MA[qe]W[pe]
;B[pd]
;W[od]
;B[oe]GB[1])
(
;GM[1]FF[4]AB[qd]AW[oc]CA[UTF-8]CR[mc]PL[B]SZ[19]
;B[mc]
;MA[pd]W[pe]
;B[qe]
;W[pf]
;B[qg]GB[1])
(
;GM[1]FF[4]AB[mc][qd]AW[oc]CA[UTF-8]CR[pe]GC[refute_bad_move task]LB[mc:1]PL[W]SZ[19]
;W[pe]
;B[qf]
;GB[1]LB[qf:?]W[qe])
EODATA
gen_problems_ok(deter => $input, $expect);
done_testing;
