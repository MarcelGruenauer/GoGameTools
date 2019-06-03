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
;GB[1]W[qi])
(
;GM[1]FF[4]AB[cq][dp][fq][nc][pd]AW[bp][ck][cn][qf][rd]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LN[aa:ss]PL[B]SZ[19]
;B[qc]LN[aa:ss]
;GB[1]LN[aa:ss]W[qi])
(
;GM[1]FF[4]AB[cq][dp][fq][nc][pd][qc]AW[bp][ck][cn][qf][rd]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task]LB[qc:1]LN[aa:ss]PL[W]SZ[19]
;GB[1]LN[aa:ss]W[qi])
EODATA
gen_problems_ok(correct_for_both => $input, $expect);
$input  = slurp('t/plumbing/pipe_gen_problems/correct_for_both_with_condition.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[of][pd][pe][pf][qc][qe]AW[nc][pg][qd][qf][re][rg]CA[UTF-8]GC[correct_for_both trumpet_connection]PL[W]SZ[19]
;C[Black wants to strengthen his corner.]W[rd]
;B[oc]GB[1])
(
;GM[1]FF[4]AB[of][pd][pe][pf][qc][qe]AW[nc][pg][qd][qf][rd][re][rg]C[Black wants to strengthen his corner.]CA[UTF-8]GC[correct_for_both trumpet_connection]LB[rd:1]PL[B]SZ[19]
;B[oc]GB[1])
(
;GM[1]FF[4]AB[of][pd][pe][pf][qc][qe]AW[nc][pg][qd][qf][re][rg]CA[UTF-8]GC[correct_for_both trumpet_connection]PL[W]SZ[19]
;C[Black wants to build the upper side.]W[rd]
;B[og]
;W[ph]
;B[kc]GB[1])
(
;GM[1]FF[4]AB[of][pd][pe][pf][qc][qe]AW[nc][pg][qd][qf][rd][re][rg]C[Black wants to build the upper side.]CA[UTF-8]GC[correct_for_both trumpet_connection]LB[rd:1]PL[B]SZ[19]
;B[og]
;W[ph]
;B[kc]GB[1])
(
;GM[1]FF[4]AB[co][cq][dn][do][dp][en][eq][of][pd][pe][pf][qc][qe]AW[bm][bo][bp][cn][cp][dm][fq][nc][pg][qd][qf][re][rg]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task trumpet_connection]LN[aa:ss]PL[W]SZ[19]
;C[Black wants to strengthen his corner.]LN[aa:ss]W[rd]
;B[oc]GB[1]LN[aa:ss])
(
;GM[1]FF[4]AB[co][cq][dn][do][dp][en][eq][of][pd][pe][pf][qc][qe]AW[bm][bo][bp][cn][cp][dm][fq][nc][pg][qd][qf][rd][re][rg]C[Construct the shape shown in the opposite corner.

Black wants to strengthen his corner.]CA[UTF-8]GC[copy correct_for_both task trumpet_connection]LB[rd:1]LN[aa:ss]PL[B]SZ[19]
;B[oc]GB[1]LN[aa:ss])
(
;GM[1]FF[4]AB[co][cq][dn][do][dp][em][en][iq][of][pd][pe][pf][qc][qe]AW[bm][bo][bp][cn][cp][dl][dm][fq][nc][pg][qd][qf][re][rg]C[Construct the shape shown in the opposite corner.]CA[UTF-8]GC[copy correct_for_both task trumpet_connection]LN[aa:ss]PL[W]SZ[19]
;C[Black wants to build the upper side.]LN[aa:ss]W[rd]
;B[og]LN[aa:ss]
;LN[aa:ss]W[ph]
;B[kc]GB[1]LN[aa:ss])
(
;GM[1]FF[4]AB[co][cq][dn][do][dp][em][en][iq][of][pd][pe][pf][qc][qe]AW[bm][bo][bp][cn][cp][dl][dm][fq][nc][pg][qd][qf][rd][re][rg]C[Construct the shape shown in the opposite corner.

Black wants to build the upper side.]CA[UTF-8]GC[copy correct_for_both task trumpet_connection]LB[rd:1]LN[aa:ss]PL[B]SZ[19]
;B[og]LN[aa:ss]
;LN[aa:ss]W[ph]
;B[kc]GB[1]LN[aa:ss])
EODATA
gen_problems_ok(correct_for_both_with_condition => $input, $expect);
done_testing;
