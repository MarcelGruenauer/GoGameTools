package GoGameTools::GenerateProblems::Plugin::CorrectForBoth;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Log;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'correct_for_both';
}

sub handle_higher_level_directive ($self, $node, $context) {
    if ($node->directives->{correct_for_both}) {
        $node->directives->{$_} = 1 for qw(correct copy);
        my $parent = $context->get_parent_for_node($node);
        fatal('no parent') unless defined $parent;
        $parent->directives->{$_} = 1 for qw(correct copy);

        # Use an internal directive, marked by a leading underscore, to
        # communicate the opponent response node that needs to be added to the
        # tree that starts with the parent of the {{ correct_for_both }} node.
        $parent->directives->{_correct_for_both_response} = $node->public_clone;
        $_->add_tags('correct_for_both') for $node, $parent;
    }
}

sub handle_cloned_node_for_problem ($self, $cloned_node, $, $problem, $) {

    # If the previous code, called in an earlier traversal, indicated that we
    # should append an opponent response node then do so.
    if (my $response_node =
        delete $cloned_node->directives->{_correct_for_both_response}) {
        $problem->tree->unshift_node($response_node);
    }
}
1;
