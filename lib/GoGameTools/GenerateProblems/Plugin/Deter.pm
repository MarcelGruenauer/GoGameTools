package GoGameTools::GenerateProblems::Plugin::Deter;
use GoGameTools::features;
use GoGameTools::Munge;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'deter';
}

# If the parent node has the {{ deter }} directive, we want to put crosses on
# all positions where we don't want the user to play. This assumes that all
# non-bad alternatives have sibling nodes so we can know where to put the
# crosses.
#
# But the crosses need to go on the parent node, which isn't yet in the problem
# tree because we unshift the nodes below. So here we just remember the
# positions in a {{ deter_pos }} directive in the problem tree node. In
# finalize_nodes(), we will actually put the crosses on the parent node.
#
# {{ deter }} has no effect on bad moves, which will be presented from the
# opponent's point of view.
sub handle_cloned_node_for_problem ($self, %args) {
    my $parent =
      $args{traversal_context}->get_parent_for_node($args{original_node});
    return unless $parent->directives->{deter};
    $args{cloned_node}->directives->{user_is_guided} = 1;
    unless ($args{original_node}->directives->{bad_move}) {
        $args{cloned_node}->directives->{deter_pos} = [
            map { $_->move } get_non_bad_siblings_of_same_color(
                $args{original_node}, $args{traversal_context}
            )
        ];
    }
}

# Don't add MA[] to "correct" nodes, that is, nodes at the end of generated
# problems.
sub finalize_node ($self, $node, $context, $parent_node) {
    my $deter_positions_ref = $node->directives->{deter_pos};
    return unless defined $deter_positions_ref;
    return unless ($node->move_color // '') eq color_to_play($context->tree);

    # return if $node->directives->{user_is_guided};
    return if $parent_node->directives->{correct};
    $parent_node->add(MA => $deter_positions_ref);
}
1;
