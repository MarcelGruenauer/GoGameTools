package GoGameTools::GenerateProblems::Plugin::Condition;
use GoGameTools::features;
use GoGameTools::Node;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'condition';
}

sub handle_higher_level_directive ($self, $node, $) {

    # The {{ condition }} directive indicates that there is a condition for
    # playing this move. For example, you might want to teach one move if the
    # user has ko threats and another one if he doesn't.
    #
    # Therefore suppress the circle guide.
    if ($node->directives->{condition}) {
        $node->directives->{user_is_guided} = 1;
    }
}

sub finalize_node ($self, $node, $, $parent_node) {
    if (my $condition = $node->directives->{condition}) {
        $parent_node->append_comment($condition);

        # If the node contains triangle markup, move it to the parent so the
        # condition can refer to "the marked stone" or "the triangled stone".
        # So the assumption is that the triangles aren't intended for this node
        # at all.
        #
        # This is just an assumption, though, and if it turns out to be too
        # naive, we'll have to look for something more specific and resilient.
        my @tr = $node->get('TR')->@*;
        if (@tr) {
            $parent_node->add(TR => \@tr);
            $node->del('TR');
        }
    }
}
1;
