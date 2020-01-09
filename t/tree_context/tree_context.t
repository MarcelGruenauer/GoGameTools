#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Util;
use Test::More;
my $sgf  = slurp('t/tree_context/upper-lower-split.sgf');
my $tree = parse_sgf($sgf)->[0];

# Test $context->delete_node(). The test sgf file two problems on one board.
# The upper half is one problem, the lower half is another problem. It also
# contains moves for both problems. We define a rectangle of coordinates and
# remove all AB[] and AW[] that are not in the rectangle; we also use
# delete_node() to remove all nodes whose moves are not in the rectangle.
use GoGameTools::Parser::SGF;
my %wanted =
  map { $_ => 1 } GoGameTools::Parser::SGF::expand_rectangle('ak:ss');
subtest delete_node => sub {
    $tree->traverse(
        sub ($node, $context) {
            $node->filter([qw(AB AW)] => sub { $wanted{ $_[0] } });
            my $move = $node->move;
            $context->delete_node($node) if defined $move && !$wanted{ $node->move };
        }
    );
    my $expect = '(;AB[dp][fo][fp][gn][hl][hn][im][jm][jp][jq][kn][ko][lk][ll][lm][ln][no][pl][pn][po][pp][qq][qr]AW[cn][go][ho][hq][in][io][ip][jn][jo][kp][lo][lq][ml][mm][mn][mo][mp][op][oq][pq];B[iq];W[hr];B[hp];W[gp];B[gq];W[hp];B[gr])';
    is $tree->as_sgf, $expect, 'upper half board setup stones and moves';
};
done_testing;
