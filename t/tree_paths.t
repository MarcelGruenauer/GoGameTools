#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use Test::More;

# The test sgf file has the expected tree path in each node's comments.
# Traverse the tree and check the get_node_for_tree_path() returns the same
# node.
my $sgf  = <<EOSGF;
(;GM[1]FF[4]CA[UTF-8]AP[Sabaki:0.43.3]KM[6.5]SZ[19]DT[2019-05-26]C[0];B[pd]C[1];W[dp]C[2];B[pp]C[3];W[dd]C[4](;B[fc]C[5];W[cf]C[6];B[db]C[7];W[cc]C[8];B[ic]C[9])(;B[pj]C[5-1-0];W[nc]C[5-1-1];B[lc]C[5-1-2];W[qc]C[5-1-3];B[qd]C[5-1-4];W[pc]C[5-1-5];B[od]C[5-1-6](;W[nb]C[5-1-7];B[me]C[5-1-8])(;W[nd]C[5-1-7-1-0];B[oc]C[5-1-7-1-1];W[ob]C[5-1-7-1-2];B[pb]C[5-1-7-1-3])))
EOSGF

my $tree = parse_sgf($sgf)->[0];
$tree->traverse(
    sub ($node, $args) {
        my $tree_path = $node->get('C');
        my $found     = $tree->get_node_for_tree_path($tree_path);
        my $is_ok     = defined $found && $found->get('C') eq $tree_path;
        ok $is_ok, "tree path $tree_path";
    }
);
done_testing;
