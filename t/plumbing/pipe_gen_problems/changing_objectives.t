#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input  = slurp('t/plumbing/pipe_gen_problems/changing_objectives.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[am][bm][cm][cn][cq][dn][do][dp][dq][dr][ds]AW[an][bn][bp][bq][br][co][cs]CA[UTF-8]GC[correct_for_both encroaching endgame offensive_endgame threatening_to_kill]PL[B]SZ[19]
;B[bo]
;W[ao]
;B[cp]
;W[ar]
;B[cr]
;W[bs]
;B[bo]
;GB[1]W[ap])
(
;GM[1]FF[4]AB[am][bm][bo][cm][cn][cq][dn][do][dp][dq][dr][ds]AW[an][bn][bp][bq][br][co][cs]CA[UTF-8]GC[correct_for_both defensive_endgame endgame stopping_encroachments]LB[bo:1]PL[W]SZ[19]
;W[ao]
;B[cp]
;W[ar]
;B[cr]
;W[bs]
;B[bo]
;GB[1]W[ap])
(
;GM[1]FF[4]AB[am][bm][cm][cn][cp][cq][dn][do][dp][dq][dr][ds]AW[an][ao][bn][bo][bp][bq][br][co][cs]C[1 at 4.]CA[UTF-8]GC[killing killing_with_ko ko]LB[ao:2][bo:4][cp:3]PL[B]SZ[19]
;B[bs]
;W[cr]
;B[ar]
;GB[1]LB[bo:?]W[as])
(
;GM[1]FF[4]AB[am][bm][cm][cn][cq][dn][do][dp][dq][dr][ds]AW[an][bn][bp][bq][br][co][cs]CA[UTF-8]GC[encroaching endgame offensive_endgame threatening_to_kill]PL[B]SZ[19]
;B[bo]
;W[ao]
;B[cp]
;W[bo]
;B[bs]
;W[cr]
;B[ar]
;GB[1]LB[bo:?]W[as])
(
;GM[1]FF[4]AB[am][bm][cm][cn][cp][cq][dn][do][dp][dq][dr][ds]AW[an][ao][bn][bo][bp][bq][br][co][cs]C[1 at 4.]CA[UTF-8]GC[killing killing_with_ko ko]LB[ao:2][bo:4][cp:3]PL[B]SZ[19]
;B[bs]
;W[as]
;B[cr]
;W[aq]
;B[bs]GB[1]LB[bo:?])
(
;GM[1]FF[4]AB[am][bm][cm][cn][cq][dn][do][dp][dq][dr][ds]AW[an][bn][bp][bq][br][co][cs]CA[UTF-8]GC[encroaching endgame offensive_endgame threatening_to_kill]PL[B]SZ[19]
;B[bo]
;W[ao]
;B[cp]
;W[bo]
;B[bs]
;W[as]
;B[cr]
;W[aq]
;B[bs]GB[1]LB[bo:?])
(
;GM[1]FF[4]AB[am][bm][cm][cn][cq][dn][do][dp][dq][dr][ds][pa][pb][pc][pd][pe][pf][qb][qc][qd][qf][qg][re][rg][sg]AW[an][bn][bp][bq][br][co][cs][qa][ra][rb][rc][rd][rf][sb][sd][se][sf]C[Copy this shape.]CA[UTF-8]GC[copy correct_for_both encroaching endgame offensive_endgame task threatening_to_kill]LN[aa:ss]PL[B]SZ[19]
;B[bo]LN[aa:ss]
;LN[aa:ss]W[ao]
;B[cp]LN[aa:ss]
;LN[aa:ss]W[ar]
;B[cr]LN[aa:ss]
;LN[aa:ss]W[bs]
;B[bo]LN[aa:ss]
;GB[1]LN[aa:ss]W[ap])
(
;GM[1]FF[4]AB[am][bm][bo][cm][cn][cq][dn][do][dp][dq][dr][ds][pa][pb][pc][pd][pe][pf][qb][qc][qd][qf][qg][re][rg][sg]AW[an][bn][bp][bq][br][co][cs][qa][ra][rb][rc][rd][rf][sb][sd][se][sf]C[Copy this shape.]CA[UTF-8]GC[copy correct_for_both defensive_endgame endgame stopping_encroachments task]LB[bo:1]LN[aa:ss]PL[W]SZ[19]
;LN[aa:ss]W[ao]
;B[cp]LN[aa:ss]
;LN[aa:ss]W[ar]
;B[cr]LN[aa:ss]
;LN[aa:ss]W[bs]
;B[bo]LN[aa:ss]
;GB[1]LN[aa:ss]W[ap])
EODATA
gen_problems_ok(ladder_related_directives => $input, $expect);
done_testing;
