package GoGameTools::Munge;
use GoGameTools::features;
use GoGameTools::Board;
use GoGameTools::Color;
use GoGameTools::Coordinate;
use GoGameTools::Log;
use utf8;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      get_non_bad_siblings_of_same_color
      has_non_bad_siblings_of_same_color
      divide_children_into_good_and_bad
      color_to_play
      track_board_in_traversal_for_node
      pos_rel_to_UR_LL_diagonal
      parse_annotations
    );
}

sub get_non_bad_siblings_of_same_color ($node, $context) {
    my $node_color = $node->move_color;
    return () unless defined $node_color;
    my @siblings =
      grep {
             (!$_->directives->{bad_move})
          && ($_->move_color // '') eq $node_color
      } $context->get_siblings_for_node($node)->@*;
    return @siblings;
}

sub has_non_bad_siblings_of_same_color ($node, $args) {
    my @siblings = get_non_bad_siblings_of_same_color($node, $args);
    return @siblings > 0;
}

sub divide_children_into_good_and_bad ($node, $context) {
    my $node_color = $node->move_color;
    my (@good_children, @bad_children);
    for (grep { defined $_->move_color } $context->get_children_for_node($node)->@*)
    {
        if ($_->directives->{bad_move}) {
            push @bad_children, $_;
        } else {
            push @good_children, $_;
        }
    }
    return (\@good_children, \@bad_children);
}
# The color to play in the problem is determined by the first move - which
# should also be the color of the last move.
#
# The first node could be an arrayref for a variation; this could happen with
# the 'tenuki' directive. In that case, keep looking into the first node of
# that array until you find something that's node an arrayref.
sub color_to_play ($tree) {
    my $first_node = $tree->get_node(1);
    while (ref $first_node eq ref []) {
        $first_node = $first_node->[0];
    }
    return $first_node->move_color;
}

# Call this in traverse() callbacks while traversing a tree if you need to keep
# track of the current board position. Keeps a separate GoGameTools::Board
# object in each node object.
sub track_board_in_traversal_for_node ($node, $context) {
    if (my $parent = $context->get_parent_for_node($node)) {
        if (defined $parent->{_board}) {
            $node->{_board} = $parent->{_board}->clone;
        }
    }
    $node->{_board} //= GoGameTools::Board->new;
    $node->{_board}->play_node($node);
}

# see extensive documentation below
sub pos_rel_to_UR_LL_diagonal ($coord) {
    my ($x, $y) = coord_sgf_to_xy($coord);
    return (360 - 18 * ($x + $y)) <=> 0;
}

sub parse_annotations ($lines_ref) {
    my %annotations;
    for my $line ($lines_ref->@*) {
        my ($filename, $index, $tree_path, $annotation) = split /\t/, $line;
        $filename = File::Spec->rel2abs($filename);
        push $annotations{$filename}{$index}->@*, [ $tree_path, $annotation ];
    }
    return \%annotations;
}

1;

=pod

Various helper functions that munge nodes or trees. They are too specific to go
into the main GoGameTools::Tree or GoGameTools::Node classes or even into
GoGameTools::Util, but are used in various places.

=head1 pos_rel_to_UR_LL_diagonal

See https://www.gamedev.net/forums/topic/542870-determine-which-side-of-a-line-a-point-is/

Suppose you have a point and a line and you want to know which side of the line
the point is. Assuming that the line runs from (Ax,Ay) to (Bx,By) and that the
(Cx,Cy):

    (Bx - Ax) * (Cy - Ay) - (By - Ay) * (Cx - Ax)

This will equal zero if the point C is on the line formed by points A and B,
and will have a different sign depending on the side. Which side this is
depends on the orientation of your (x,y) coordinates, but you can plug test
values for A,B and C into this formula to determine whether negative values are
to the left or to the right.

In this case, I want to know where a point lies relative to the diagonal that
runs from the upper right (= (19, 1)) to the lower left (= (1, 19)).

SGF coordinates use 'a'..'s' for 1..19, so first we convert them.

For the above formular, A = (19, 1) and B = (1, 19).

      (Bx - Ax) * (Cy - Ay) - (By - Ay) * (Cx - Ax)
    = (1 - 19)  * (Ct - 1)  - (19 - 1)  * (Cx - 19)
    = -18 * Cy + 18 - 18 * Cx + 342
    = 360 - 18 * (Cx + Cy)

So this function returns:

    +1 = if the point is in the upper left board triangle

     0 = if the point is on the diagonal from the upper right to the lower left

    -1 = if the point is in the lower right board triangle

Demonstration:

    for my $x ('a' .. 's') {
        for my $y ('a' .. 's') {
            printf '%3s', pos_rel_to_UR_LL_diagonal("$x$y");
        }
        print "\n";
    }

prints

    1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0
    1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0 -1
    1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0 -1 -1
    1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1
    1  1  1  1  1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    1  0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
    0 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1

=cut
