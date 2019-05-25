#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/ladder_related_directives.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[lc][md][qd]AW[ld][mc][oc]CA[UTF-8]LB[ld:1]PL[B]SZ[19]
;B[nc]
;W[mb]
;B[me]C[The ladder is good for Black.]
;W[nd]
;B[ne]
;W[nb]
;B[pe]
;W[kd]
;B[qj]GB[1])
(
;GM[1]FF[4]AB[lc][md][qd]AW[mc][oc]CA[UTF-8]PL[W]SZ[19]
;W[ld]
;B[nc]
;W[mb]
;B[me]C[The ladder is good for White.]
;C[The ladder is good for White.]W[nb]
;B[kc]
;W[le]
;B[mf]
;W[pe]
;B[qe]
;W[pf]
;B[qg]
;W[pg]
;B[qh]
;GB[1]W[lf])
(
;GM[1]FF[4]AB[lc][md][qd]AW[ld][mc][oc]CA[UTF-8]LB[ld:1]PL[B]SZ[19]
;B[nc]
;W[mb]
;B[me]
;C[The ladder is good for Black.]W[nb]
;B[kd]
;W[pe]
;B[qe]
;W[pf]
;B[qg]GB[1]LB[nb:?])
EODATA
gen_problems_ok(ladder_related_directives => $input, $expect);
done_testing;
