#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/assemble_multiple_branch_points.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[al][bk][bp][ck][cp][cq][cr][do][ek][el][eo][fm][fo][gn]AW[an][bl][bm][bo][cm][cn][co][dm][dp][dq][dr][em][fq][hq]CA[UTF-8]PL[B]SZ[19]
;B[bs]
;W[ar]
;B[ap]
;W[ds]
;B[cs]
;CR[cl]W[ao]
;B[cl]
;CR[dl]W[br]
;B[dl]
;CR[en]W[bq]
;B[en]
;W[aq]
;B[as]
;W[br]
(
;B[ak]
;W[ar]
(
;B[am]
;W[bq]
;B[aq]
;W[br]
;B[dn]GB[1]LB[bs:!])
(
;B[dn]
;W[bq]
;B[aq]
;W[br]
;B[am]GB[1]LB[bs:!]))
(
;B[dn]
;W[ar]
;B[ak]
;W[bq]
;B[aq]
;W[br]
;B[am]GB[1]LB[bs:!]))
EODATA
gen_problems_ok(assemble_multiple_branch_points => $input, $expect);
$input = slurp('t/plumbing/pipe_gen_problems/assemble_single_branch_point.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[bm][br][cm][cn][cq][dm][dq][em][eq][fm][fp][gn][go][gp]AW[bn][bo][bq][co][cp][dn][dp][en][ep][fn][fo]CA[UTF-8]GC[refute_bad_move]LB[bo:1]PL[B]SZ[19]
;B[aq]
;W[ap]
;B[bp]GB[1]LB[bo:?])
(
;GM[1]FF[4]AB[bm][br][cm][cn][cq][dm][dq][em][eq][fm][fp][gn][go][gp]AW[bn][bq][co][cp][dn][dp][en][ep][fn][fo]CA[UTF-8]PL[W]SZ[19]
(
;W[ao]
;B[aq]
;W[bp]
;B[ar]
;GB[1]W[ap])
(
;W[ap]
;B[an]
;GB[1]W[bo]))
EODATA
gen_problems_ok(assemble_single_branch_point => $input, $expect);
$input = slurp('t/plumbing/pipe_gen_problems/assemble_and_tags.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[as][bo][bp][br][cq][cr][dr][ds]AW[an][bn][bs][cn][co][cp][dq][eq][er]CA[UTF-8]GC[bent_four_in_the_corner killing rank_elementary]PL[W]SZ[19]
;W[aq]
;B[ap]
;W[ar]
;B[bq]
;W[ao]
;B[as]
;GB[1]W[ar])
(
;GM[1]FF[4]AB[as][bo][bp][br][cq][cr][dr][ds]AW[an][bn][bs][cn][co][cp][dq][eq][er]CA[UTF-8]GC[making_a_false_eye rank_elementary]PL[W]SZ[19]
;W[aq]
;B[ar]
(
;GB[1]W[ao])
(
;GB[1]W[ap]))
EODATA
gen_problems_ok(assemble_and_tags => $input, $expect);
$input = slurp('t/plumbing/pipe_gen_problems/assemble_in_game_info.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[gr][hr][ir][jr][kr][lr][mr]AW[dr][fq][fr][gq][hq][iq][jq][kq][lq][mq][nq][nr][pr]C[Test.]CA[UTF-8]GC[living rank_intro]PL[B]SZ[19]
(
;B[gs]
;W[ms]
;B[ls]GB[1])
(
;B[ms]
;W[gs]
;B[hs]GB[1]))
EODATA
gen_problems_ok(assemble_in_game_info => $input, $expect);
done_testing;
