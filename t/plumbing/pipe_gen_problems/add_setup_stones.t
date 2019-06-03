#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input  = slurp('t/plumbing/pipe_gen_problems/add_setup_stones.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[pd][qh]AW[gc][jc][qc][qf]CA[UTF-8]GC[correct_for_both]LB[qc:1]PL[B]SZ[19]
;B[qd]
;W[pc]
;B[od]
;W[rd]
;B[re]
;W[rc]
;B[qe]
;GB[1]W[nc])
(
;GM[1]FF[4]AB[pd][qh]AW[gc][jc][qf]CA[UTF-8]CR[qc]GC[correct_for_both]PL[W]SZ[19]
;W[qc]
;B[qd]
;W[pc]
;B[od]
;W[rd]
;B[re]
;W[rc]
;B[qe]
;GB[1]W[nc])
(
;GM[1]FF[4]AB[jd][pd][qh]AW[dd][qf]CA[UTF-8]CR[qc]GC[correct_for_both]PL[W]SZ[19]
;W[qc]
;B[pc]
;W[qd]
;B[pe]
;W[rf]
;B[og]GB[1])
(
;GM[1]FF[4]AB[jd][pd][qh]AW[dd][qc][qf]CA[UTF-8]GC[correct_for_both]LB[qc:1]PL[B]SZ[19]
;B[pc]
;W[qd]
;B[pe]
;W[rf]
;B[og]GB[1])
(
;GM[1]FF[4]AB[bo][cl][co][cp][dp][ep][pd][qh]AW[bp][bq][cn][cq][dq][fq][gc][jc][jq][mq][qc][qf]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LB[qc:1]LN[aj:sj]PL[B]SZ[19]
;B[qd]LN[aj:sj]
;LN[aj:sj]W[pc]
;B[od]LN[aj:sj]
;LN[aj:sj]W[rd]
;B[re]LN[aj:sj]
;LN[aj:sj]W[rc]
;B[qe]LN[aj:sj]
;GB[1]LN[aj:sj]W[nc])
(
;GM[1]FF[4]AB[bo][cl][co][cp][dp][ep][pd][qh]AW[bp][bq][cn][cq][dq][fq][gc][jc][jq][mq][qf]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LN[aj:sj]PL[W]SZ[19]
;LN[aj:sj]W[qc]
;B[qd]LN[aj:sj]
;LN[aj:sj]W[pc]
;B[od]LN[aj:sj]
;LN[aj:sj]W[rd]
;B[re]LN[aj:sj]
;LN[aj:sj]W[rc]
;B[qe]LN[aj:sj]
;GB[1]LN[aj:sj]W[nc])
(
;GM[1]FF[4]AB[cl][do][dp][dq][em][jd][jp][pd][qh]AW[bn][cn][cp][cq][dd][pp][qf]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LN[aj:sj]PL[W]SZ[19]
;LN[aj:sj]W[qc]
;B[pc]LN[aj:sj]
;LN[aj:sj]W[qd]
;B[pe]LN[aj:sj]
;LN[aj:sj]W[rf]
;B[og]GB[1]LN[aj:sj])
(
;GM[1]FF[4]AB[cl][do][dp][dq][em][jd][jp][pd][qh]AW[bn][cn][cp][cq][dd][pp][qc][qf]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LB[qc:1]LN[aj:sj]PL[B]SZ[19]
;B[pc]LN[aj:sj]
;LN[aj:sj]W[qd]
;B[pe]LN[aj:sj]
;LN[aj:sj]W[rf]
;B[og]GB[1]LN[aj:sj])
EODATA
gen_problems_ok(add_setup_stones => $input, $expect);
done_testing;
