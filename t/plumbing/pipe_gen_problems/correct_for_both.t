#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input  = slurp('t/plumbing/pipe_gen_problems/correct_for_both.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[nc][pd]AW[qf][rd]CA[UTF-8]CR[qc]GC[correct_for_both]PL[B]SZ[19]
;B[qc]
;GB[1]W[qi])
(
;GM[1]FF[4]AB[nc][pd][qc]AW[qf][rd]CA[UTF-8]GC[correct_for_both]LB[qc:1]PL[W]SZ[19]
;GB[1]W[qi]
;GB[1]W[qi])
(
;GM[1]FF[4]AB[cq][dp][fq][nc][pd]AW[bp][ck][cn][qf][rd]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LN[aa:ss]PL[B]SZ[19]
;B[qc]LN[aa:ss]
;GB[1]LN[aa:ss]W[qi])
(
;GM[1]FF[4]AB[cq][dp][fq][nc][pd][qc]AW[bp][ck][cn][qf][rd]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LB[qc:1]LN[aa:ss]PL[W]SZ[19]
;LN[aa:ss]W[qi]
;GB[1]LN[aa:ss]W[qi])
EODATA
gen_problems_ok(correct_for_both => $input, $expect);
done_testing;
