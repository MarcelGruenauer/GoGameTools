#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/answer.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[md][qf][qi][rd]AW[jc][nd][pd][qc]C[Which moves are common?]CA[UTF-8]CR[jj]GC[question task]LB[mc:B][me:D][nc:A][ne:C]MN[-1]PL[B]SZ[19]
;B[jj]
;AE[jj]C[A is slow. B, C and D are common.]GB[1]LB[mc:B][me:D][nc:A][ne:C])
EODATA
gen_problems_ok(answer => $input, $expect);
done_testing;
