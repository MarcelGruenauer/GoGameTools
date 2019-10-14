package GoGameTools::GenerateProblems::Plugin::Tenuki;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Board;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'tenuki';
}

# Handle {{ tenuki }}. Use this directive on a response node; it doesn't matter
# where the move is. We only need the move to know which color is to play. The
# node will be replaced by a list of variations, one for each tenuki response.
sub finalize_problem_1 ($self, %args) {
    $args{problem}->tree->traverse(
        sub ($node, $context) {
            return unless $context->is_variation_end($node);
            my $tree = $context->tree;
            return unless $node->directives->{tenuki};
            my $color_to_tenuki = $node->move_color;
            my $text            = $node->directives->{tenuki};
            my @variations;

            # Get the tenuki coordinates from the parent; we don't want to exclude the
            # {{ tenuki }} node's move and its neighbors.
            my $last_parent = $context->get_parent_for_node($node);
            for my $coord (_get_tenuki_coordinates($last_parent, $context)) {
                my $tenuki_node = GoGameTools::Node->new;
                $tenuki_node->add($color_to_tenuki => $coord);
                $tenuki_node->directives->{correct} = 1;
                $tenuki_node->append_comment($text);
                push @variations, [$tenuki_node];
            }

            # splice the variations in place of the 'tenuki' node
            splice $tree->tree->@*, -1, 1, @variations;
        }
    );
}

# Given a node, returns a list of coordinates that count as tenuki for
# problem-solving purposes.
#
# Set up the position leading up to the given node on a new node. Tenuki spans
# the whole board except for the stones in the positions, their neighbors and
# the neighbors' neighbors.
sub _get_tenuki_coordinates ($node, $context) {
    state sub get_neighbors_for_coordinates (@coords) {
        my $board = GoGameTools::Board->new;
        my %seen_coord;
        for my $coord (@coords) {
            $seen_coord{$_}++ for $board->neighbors($coord)->@*;
        }
        my @neighbors = sort keys %seen_coord;
        return @neighbors;
    }

    # setup the position on a new node
    my $setup_node = GoGameTools::Node->new;
    my $board      = GoGameTools::Board->new;
    $board->play_node($_) for $context->get_ancestors_for_node($node)->@*;
    $board->setup_on_node($setup_node);
    my @occupied         = ($setup_node->get('AB')->@*, $setup_node->get('AW')->@*);
    my @direct_neighbors = get_neighbors_for_coordinates(@occupied);
    my @indirect_neighbors = get_neighbors_for_coordinates(@direct_neighbors);
    my %is_not_tenuki =
      map { $_ => 1 } (@occupied, @direct_neighbors, @indirect_neighbors);
    my @tenuki_coords;

    for my $x ('a' .. 's') {
        for my $y ('a' .. 's') {
            my $coord = "$x$y";
            next if $is_not_tenuki{$coord};
            push @tenuki_coords, $coord;
        }
    }
    return @tenuki_coords;
}
1;
