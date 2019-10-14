#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Test;
use GoGameTools::Util;
use Test::More;
my $input = slurp('t/plumbing/pipe_gen_problems/tenuki.sgf');
my $got_tenuki_template = <<'EODATA';
(
;GM[1]FF[4]AB[mb][ob][oc][od][pd][qd][rd][rf]AW[pb][pc][qc][rc]CA[UTF-8]PL[W]SZ[19]
%s)
EODATA
my $node = GoGameTools::Node->new;
$node->add(
    AB => [ 'aa:js',
    'ka', 'kc:ks', 'ld:ls', 'me:ms', 'nf:ns', 'og:os', 'pg:ps', 'qh:qs', 'ri:rs',
    'sa', 'sh:ss' ]
);
my $expect = sprintf $got_tenuki_template, join "\n",
  map { "(\n;C[Tenuki is right. White is already dead.]GB[1]W[$_])" }
  $node->expand_rectangles($node->get('AB'))->@*;

gen_problems_ok(tenuki => $input, $expect);
done_testing;
