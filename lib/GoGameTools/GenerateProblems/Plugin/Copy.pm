package GoGameTools::GenerateProblems::Plugin::Copy;
use GoGameTools::features;
use GoGameTools::Board;
use GoGameTools::Node;
use GoGameTools::Log;
use GoGameTools::Macros;
use GoGameTools::GenerateProblems::Problem;
use Storable qw(dclone);
use GoGameTools::Class qw(new);

sub handles_directive ($self, %args) {
    return $args{directive} eq 'copy';
}

# Handle the {{ copy }} directive. Make a clone of the problem tree. Play it
# out on a board until the end, then transpose it to the opponent's view. Setup
# the result on the cloned problem tree.
sub finalize_problem_1 ($self, %args) {
    $args{problem}->tree->traverse(
        sub ($node, $context) {
            return unless $context->is_variation_end($node);
            my $tree = $context->tree;
            return unless $node->directives->{copy};

            # setup the position at the end of the copy on the setup node
            my $setup_node = GoGameTools::Node->new;
            my $board      = GoGameTools::Board->new;
            $board->play_node($_)
              for $context->get_ancestors_for_node($tree->get_node(-1))->@*;
            $board->setup_on_node($setup_node);

            # Check that there are at most two quadrants with stones. If more, we can't
            # transpose without overlapping stones somewhere during the problem.
            my %quadrants = _get_occupied_quadrants($setup_node);
            my $count_quadrants =
              $quadrants{UL} + $quadrants{UR} + $quadrants{LL} + $quadrants{LR};
            if ($count_quadrants > 2) {
                debug($tree->with_location('setup too big, skipping {{ copy }}'));
                return;
            }
            $setup_node->transpose_to_opponent_view;
            my $copy           = dclone($tree);
            my $game_info_node = $copy->get_node(0);
            $game_info_node->add($_ => $setup_node->get($_)) for qw(AB AW);
            $game_info_node->append_comment(expand_macros('{% copy_shape %}'));
            $copy->get_node(0)->add_tags('copy');
            my %separator = get_separator_for_quadrants(quadrants => \%quadrants);
            $copy->traverse(
                sub ($node, $) {
                    $node->{directives}{user_is_guided} = 1;
                    while (my ($k, $v) = each %separator) {
                        $node->add($k, $v);
                    }
                }
            );
            push $args{generator}->problems->@*,
              GoGameTools::GenerateProblems::Problem->new(tree => $copy);
        }
    );
}

sub _get_occupied_quadrants ($node) {
    my @stones = ($node->get('AB')->@*, $node->get('AW')->@*);
    my %quadrants = map { $_ => 0 } qw(UL UR LL LR);
    for (@stones) {
        $quadrants{UL} = 1 if /^[a-j][a-j]$/;
        $quadrants{UR} = 1 if /^[j-s][a-j]$/;
        $quadrants{LL} = 1 if /^[a-j][j-s]$/;
        $quadrants{LR} = 1 if /^[j-s][j-s]$/;
    }
    return %quadrants;
}

# For each node, we want to draw a line between the model and the area in which
# we want the user to copy the model. So if the model is one the upper or lower
# side, we want to draw a horizontal line. If it is on the left or right side,
# we want to draw a vertical line.
sub get_separator_for_quadrants (%args) {
    my %quadrants = $args{quadrants}->%*;
    my $count_quadrants =
      $quadrants{UL} + $quadrants{UR} + $quadrants{LL} + $quadrants{LR};
    my @tr_axis = qw(a c e g i k m o q s);
    if ($count_quadrants == 2) {
        if (   ($quadrants{UL} == 1 && $quadrants{UR} == 1)
            || ($quadrants{LL} == 1 && $quadrants{LR} == 1)) {
            return (LN => [ [qw(aj sj)] ]);
        } elsif (($quadrants{UL} == 1 && $quadrants{LL} == 1)
            || ($quadrants{UR} == 1 && $quadrants{LR} == 1)) {
            return (LN => [ [qw(ja js)] ]);
        }

        # No line for UL+LR or UR+LL
    } elsif ($count_quadrants == 1) {

        # If UL or LR, draw from UR corner to LL corner.
        # If UR or LL, draw from UL corner to LR corner.
        if (($quadrants{UL} == 1 || $quadrants{LR} == 1)) {
            return (LN => [ [qw(sa as)] ]);
        } elsif (($quadrants{UR} == 1 || $quadrants{LL} == 1)) {
            return (LN => [ [qw(aa ss)] ]);
        }
    }
    return ();
}
1;
