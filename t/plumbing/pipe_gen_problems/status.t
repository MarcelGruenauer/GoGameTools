#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/status.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[gb][hb][ib][jb][kb][lb][mb]AW[fb][fc][gc][hc][ic][jc][kc][lc][mc][nb][nc]CA[UTF-8]PL[B]SZ[19]
;B[ga]
;W[ma]
;B[la]GB[1])
(
;GM[1]FF[4]AB[gb][hb][ib][jb][kb][lb][mb]AW[fb][fc][gc][hc][ic][jc][kc][lc][mc][nb][nc]CA[UTF-8]PL[W]SZ[19]
;W[ga]
;B[ha]
;W[ma]
;B[la]
;GB[1]W[ja])
(
;GM[1]FF[4]AB[gb][hb][ib][jb][kb][lb][mb]AW[fb][fc][gc][hc][ic][jc][kc][lc][mc][nb][nc]C[What is the status of this group??]CA[UTF-8]CR[jj]GC[question status task]MN[-1]PL[B]SZ[19]
;B[jj]
;AE[jj]C[Black can live. White can kill.]GB[1])
EODATA
gen_problems_ok(status => $input, $expect);
$input = slurp('t/plumbing/pipe_gen_problems/status_without_variations.sgf');
$expect = <<'EODATA';
(
;GM[1]FF[4]AB[ha][hb][ia][ic][jb][jc][kc][kd][ld][le][me][ne][oe][pc][pd]AW[ga][gb][hc][hd][id][jd][ke][lb][lc][lf][md][mf][nd][nf][od][of][pe][pf]CA[UTF-8]LB[lb:1]PL[B]SZ[19]
;B[mc]
;W[nc]
;B[nb]
;W[mb]
;B[oc]
;W[mc]
;B[ob]
;W[ka]
;B[kb]GB[1])
(
;GM[1]FF[4]AB[ha][hb][ia][ic][jb][jc][kc][kd][ld][le][me][ne][oe][pc][pd]AW[ga][gb][hc][hd][id][jd][ke][lc][lf][md][mf][nd][nf][od][of][pe][pf]C[What is the status of this group??]CA[UTF-8]CR[jj]GC[question status task]MN[-1]PL[B]SZ[19]
;B[jj]
;AE[jj]C[Black is alive.]GB[1])
EODATA
gen_problems_ok(status_without_variations => $input, $expect);
done_testing;
