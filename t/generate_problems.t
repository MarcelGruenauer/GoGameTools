#!/usr/bin/env perl
use GoGameTools::features;
use Test::More;
use Test::Differences;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use GoGameTools::GenerateProblems;
use GoGameTools::TagHandler;
use GoGameTools::GenerateProblems::Problem;
use GoGameTools::GenerateProblems::Viewer::Glift;
register_tags();

sub get_converted_tree_from_sgf {
    my $sgf        = shift;
    my $collection = parse_sgf($sgf);
    my $tree       = pipe_convert_markup_to_directives->($collection)->[0];
    my $o          = GoGameTools::GenerateProblems->new;
    $o->preprocess_directives($tree);
    $o->propagate_metadata($tree);
    return $tree;
}

sub get_finalized_tree_from_sgf {
    my $sgf        = shift;
    my $collection = parse_sgf($sgf);
    my $tree       = pipe_convert_markup_to_directives->($collection)->[0];
    my $problem    = GoGameTools::GenerateProblems::Problem->new(tree => $tree);
    my $o =
      GoGameTools::GenerateProblems->new(
        viewer_delegate => GoGameTools::GenerateProblems::Viewer::Glift->new);
    $o->finalize_metadata($problem);
    $o->finalize_directives($problem);
    return $tree;
}
subtest convert_markup => sub {
    subtest 'MA[]' => sub {
        subtest "a single cross on the node's move" => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]MA[cd])");
            my $node = $tree->get_node(2);
            ok !$node->has('MA'), 'node has no MA[]';
            eq_or_diff $node->directives, { bad_move => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
        subtest
          "two crosses, one on an empty intersection; the other on the node's move" =>
          sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]MA[cd][ef])");
            my $node = $tree->get_node(2);
            ok !$node->has('MA'), 'node has no MA[]';
            eq_or_diff $node->directives, { bad_move => 1, barrier => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
          };
        subtest 'a single cross on an empty intersection' => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]MA[ef])");
            my $node = $tree->get_node(2);
            ok !$node->has('MA'), 'node has no MA[]';
            eq_or_diff $node->directives, { barrier => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
    };
    subtest 'SQ[]' => sub {
        subtest "a square on the node’s move; no other squares" => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[cd])");
            my $node = $tree->get_node(2);
            ok !$node->has('SQ'), 'node has no SQ[]';
            eq_or_diff $node->directives, { good_move => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
        subtest "a single square on an empty intersection" => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[ef])");
            my $node = $tree->get_node(2);
            ok !$node->has('SQ'), 'node has no SQ[]';
            eq_or_diff $node->directives, { correct => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
        subtest
          "two squares, one on an empty intersection; the other on the node's move" =>
          sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[cd][ef])");
            my $node = $tree->get_node(2);
            ok !$node->has('SQ'), 'node has no SQ[]';
            eq_or_diff $node->directives, { correct => 1, good_move => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
          };
        subtest
          "two squares, one on an empty intersection; the other on an opponent stone"
          => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[ab][ef])");
            my $node = $tree->get_node(2);
            ok !$node->has('SQ'), 'node has no SQ[]';
            eq_or_diff $node->directives,
              { correct_for_both => 1,
                correct          => 1,
                copy             => 1,
              },
              'directives';
            eq_or_diff [ map { $_->as_spec } $node->tags->@* ], [qw(correct_for_both)],
              'tags';
          };
        subtest 'two squares on empty intersections' => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[ef][gh])");
            my $node = $tree->get_node(2);
            ok !$node->has('SQ'), 'node has no SQ[]';
            eq_or_diff $node->directives, { assemble => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
    };
    subtest 'CR[]' => sub {
        subtest "a circle on the node’s move; no other circles" => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]CR[cd])");
            my $node = $tree->get_node(2);
            ok !$node->has('CR'), 'node has no CR[]';
            eq_or_diff $node->directives, { guide => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
        subtest 'two circles on empty intersections' => sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]CR[ef:eg])");
            my $node = $tree->get_node(2);
            ok !$node->has('CR'), 'node has no CR[]';
            eq_or_diff $node->directives, { has_all_good_responses => 1 }, 'directives';
            eq_or_diff $node->tags, [], 'tags';
        };
        subtest
          "three circles, two on empty intersections; the other on the node's move" =>
          sub {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]CR[cd][ef][gh])");
            my $node = $tree->get_node(2);
            ok !$node->has('CR'), 'node has no CR[]';
            eq_or_diff $node->directives,
              { has_all_good_responses => 1, guide => 1 },
              'directives';
            eq_or_diff $node->tags, [], 'tags';
          };
    };
};

# '(;SZ[19];B[ab];W[cd])'
subtest preprocess_directives => sub {
    subtest 'tree tags' => sub {
        my $tree =
          get_converted_tree_from_sgf(
            '(;SZ[19](;C[ {{ tags correct_for_both living:a }} ]B[ab];C[ {{ tags seki }} ]W[cd])(;C[ {{ tags loose_ladder:a }} ]B[ef];W[gh]))'
          );
        my @tags;
        $tree->traverse(sub { push @tags, [ node_tags($_[0]) ] });
        eq_or_diff \@tags,
          [ [], [qw(correct_for_both living:a)],
            [qw(living:a seki)], [qw(loose_ladder:a)],
            [qw(loose_ladder:a)]
          ],
          'tree tags are applied to all nodes';
    };
};
subtest finalize_directives => sub {
    subtest 'leaf node is correet' => sub {
        my $tree = get_finalized_tree_from_sgf('(;SZ[19];B[ab];W[cd])');
        is $tree->as_sgf, '(;SZ[19];B[ab];GB[1]W[cd])',
          'leaf node was marked as correct';
    };

    # TODO: answer, condition
};
done_testing;

sub node_tags ($node) {

    # temp var due to sort()
    my @tags = sort map { $_->as_spec } $node->tags->@*;
    return @tags;
}
__END__

    subtest correct => sub {
        my $tree = get_converted_tree_from_sgf('(;SZ[19];B[ab];W[cd]CH[2])');
        ok $tree->get_node(-1)->has('correct'), 'last node has "correct" property';
    };
