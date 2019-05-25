#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use GoGameTools::TagHandler;
use Test::More;
register_tags();
my $input = slurp('t/plumbing/pipe_gen_problems/is_response.sgf');
my $expect = <<'EODATA';
(
;GM[1]FF[4]AB[pb][qa][qc][qd][rd][sd]AW[ob][pc][ra][rc][sb][sc]CA[UTF-8]PL[W]SZ[19]
;W[qb]
;B[rb]C[Makes use of the marked stones.]GB[1]TR[ob][pc])
EODATA
gen_problems_ok(answer => $input, $expect);
done_testing;
