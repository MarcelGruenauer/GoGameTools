#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/condition.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[nc][pd][qc][qg][qk]AW[qf][qi][rd]CA[UTF-8]CR[pg]LB[qg:1]PL[W]SZ[19]
;W[pg]
;B[qh]
;W[ph]
;B[rf]C[White does not have ko threats.]LB[ne:B][pd:A]TR[lc][nc]
;W[ri]
;B[qe]
;W[pf]
;B[re]
;GB[1]LB[qh:?]W[rg])
(
;GM[1]FF[4]AB[nc][pd][qc][qg][qk]AW[qf][qi][rd]CA[UTF-8]CR[pg]LB[qg:1]PL[W]SZ[19]
;W[pg]
;B[qh]
;W[ph]
;B[rf]C[White has ko threats.]
;W[rg]
;B[rh]
;W[ri]
;B[sg]
;W[re]
;B[qe]
;W[pf]
;B[rc]
;W[si]
;B[sh]
;W[sf]
;B[se]
;GB[1]LB[qh:?]W[sd])
EODATA
gen_problems_ok(condition => $input, $expect);
done_testing;
