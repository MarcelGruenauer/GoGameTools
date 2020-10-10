#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Util;
use Test::More;
my $sgf  = slurp('t/tree_paths/tree_paths.sgf');
my $tree = parse_sgf(sgf => $sgf)->[0];

# The test sgf file has the expected tree path in each node's comments.
# Traverse the tree and check the get_node_for_tree_path() returns the same
# node.
subtest get_node_for_tree_path => sub {
    $tree->traverse(
        sub ($node, $) {
            my $expect_tree_path = $node->get('C');
            my $got_node         = $tree->get_node_for_tree_path($expect_tree_path);
            ok defined($got_node), "found a node for tree path $expect_tree_path...";
            my $got_tree_path = $got_node->get('C');
            is $got_tree_path, $expect_tree_path,
              "...and the node has the expected tree path";
        }
    );
};
subtest get_tree_path_for_node => sub {
    $tree->traverse(
        sub ($node, $context) {
            my $got    = $context->get_tree_path_for_node($node);
            my $expect = $node->get('C');
            is $got, $expect, "tree path $expect";
        }
    );
};
done_testing;
