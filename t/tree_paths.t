#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Util;
use Test::More;

# The test sgf file has the expected tree path in each node's comments.
# Traverse the tree and check the get_node_for_tree_path() returns the same
# node.
my $sgf  = slurp('t/tree_paths.sgf');
my $tree = parse_sgf($sgf)->[0];
subtest get_node_for_tree_path => sub {
    $tree->traverse(
        sub ($node, $args) {
            my $tree_path = $node->get('C');
            my $found     = $tree->get_node_for_tree_path($tree_path);
            my $is_ok     = defined $found && $found->get('C') eq $tree_path;
            ok $is_ok, "tree path $tree_path";
        }
    );
};
done_testing;
