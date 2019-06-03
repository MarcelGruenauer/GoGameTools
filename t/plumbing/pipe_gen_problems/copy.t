#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input  = slurp('t/plumbing/pipe_gen_problems/copy.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[mc][qd]AW[oc][pe]CA[UTF-8]LB[pe:1]PL[B]SZ[19]
;B[qe]
;W[pf]
;B[qg]GB[1])
(
;GM[1]FF[4]AB[cm][co][cp][gq][mc][qd]AW[dn][do][eq][oc][pe]C[Copy this shape.]CA[UTF-8]GC[copy task]LB[pe:1]LN[aa:ss]PL[B]SZ[19]
;B[qe]LN[aa:ss]
;LN[aa:ss]W[pf]
;B[qg]GB[1]LN[aa:ss])
EODATA
gen_problems_ok(copy => $input, $expect);
done_testing;
