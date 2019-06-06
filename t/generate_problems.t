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
    $collection = pipe_convert_markup_to_directives()->($collection);
    $collection = pipe_convert_directives_from_comment()->($collection);
    my $tree = $collection->[0];
    my $o    = GoGameTools::GenerateProblems->new;
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
    subtest 'property map' => sub {
        my %expect = (
            HO => ['barrier'],
            BM => ['bad_move'],
            TE => ['good_move'],
            DM => [ 'correct_for_both', 'correct', 'copy' ],
            GB => ['correct'],
            GW => ['correct'],
        );
        while (my ($property, $directives) = each %expect) {
            my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab]${property}[1])");
            subtest $property => sub {
                my $node = $tree->get_node(1);
                ok !$node->has($property), "node has no $property property";
                eq_or_diff $node->directives, { map { $_ => 1 } $directives->@* }, 'directives';
            };
        }
    };
    subtest 'two squares on empty intersections' => sub {
        my $tree = get_converted_tree_from_sgf("(;SZ[19];B[ab];W[cd]SQ[ef][gh])");
        my $node = $tree->get_node(2);
        ok !$node->has('SQ'), 'node has no SQ[]';
        eq_or_diff $node->directives, { assemble => 1 }, 'directives';
        eq_or_diff $node->tags, [], 'tags';
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
