#!/usr/bin/env perl
use GoGameTools::features;
use Test::More;
use Test::Differences;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use GoGameTools::Porcelain::GenerateProblems;
use GoGameTools::TagHandler;
use GoGameTools::Porcelain::GenerateProblems::Problem;
use GoGameTools::Porcelain::GenerateProblems::Viewer::WGo;
register_tags();

sub get_converted_tree_from_sgf {
    my $sgf        = shift;
    my $collection = parse_sgf($sgf);
    $collection = pipe_convert_markup_to_directives()->($collection);
    $collection = pipe_convert_directives_from_comment()->($collection);
    my $tree = $collection->[0];
    my $o    = GoGameTools::Porcelain::GenerateProblems::Runner->new;
    $o->preprocess_directives($tree);
    $o->propagate_metadata($tree);
    return $tree;
}

sub get_finalized_tree_from_sgf {
    my $sgf        = shift;
    my $collection = parse_sgf($sgf);
    my $tree       = pipe_convert_markup_to_directives->($collection)->[0];
    my $problem    = GoGameTools::Porcelain::GenerateProblems::Problem->new(tree => $tree);
    my $o =
      GoGameTools::Porcelain::GenerateProblems::Runner->new(
        viewer_delegate => GoGameTools::Porcelain::GenerateProblems::Viewer::WGo->new);
    $o->finalize_metadata($problem);
    $o->finalize_directives($problem);
    return $tree;
}
subtest convert_markup => sub {
    my %expect = (
        HO => ['barrier'],
        BM => ['bad_move'],
        TE => ['good_move'],
        DM => [ 'correct_for_both', 'correct', 'copy' ],
        GB => ['correct'],
        GW => ['correct'],
    );
    while (my ($property, $directives) = each %expect) {
        my $tree = get_converted_tree_from_sgf("(;GM[1]FF[4]SZ[19];B[ab]${property}[1])");
        subtest $property => sub {
            my $node = $tree->get_node(1);
            ok !$node->has($property), "node has no $property property";
            eq_or_diff $node->directives, { map { $_ => 1 } $directives->@* }, 'directives';
        };
    }
    subtest "a circle on the node’s move; no other circles" => sub {
        my $tree = get_converted_tree_from_sgf("(;GM[1]FF[4]SZ[19];B[ab];W[cd]CR[cd])");
        my $node = $tree->get_node(2);
        ok !$node->has('CR'), 'node has no CR[]';
        eq_or_diff $node->directives, { guide => 1 }, 'directives';
        eq_or_diff $node->tags, [], 'tags';
    };
};

# '(;GM[1]FF[4]SZ[19];B[ab];W[cd])'
subtest preprocess_directives => sub {
    subtest 'tree tags' => sub {
        my $tree =
          get_converted_tree_from_sgf(
            '(;GM[1]FF[4]SZ[19](;C[ {{ tags correct_for_both living:a }} ]B[ab];C[ {{ tags seki }} ]W[cd])(;C[ {{ tags loose_ladder:a }} ]B[ef];W[gh]))'
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
        my $tree = get_finalized_tree_from_sgf('(;GM[1]FF[4]SZ[19];B[ab];W[cd])');
        is $tree->as_sgf, '(;GM[1]FF[4]SZ[19];B[ab];GB[1]W[cd])',
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
        my $tree = get_converted_tree_from_sgf('(;GM[1]FF[4]SZ[19];B[ab];W[cd]CH[2])');
        ok $tree->get_node(-1)->has('correct'), 'last node has "correct" property';
    };
