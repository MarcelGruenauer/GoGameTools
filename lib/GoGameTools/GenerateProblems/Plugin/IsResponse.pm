package GoGameTools::GenerateProblems::Plugin::IsResponse;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'is_response';
}

# If the child node - that is, the first node of the problem tree's current
# node list - has {{ is_response }}, then we'll reset the "correct color".
sub handle_cloned_node_for_problem ($self, $cloned_node, $, $problem, $) {
    my $first_node = $problem->tree->get_node(0);
    return unless defined $first_node && ref $first_node eq 'GoGameTools::Node';
    if ($first_node->directives->{is_response}) {
        $problem->correct_color($cloned_node->move_color);
    }
}
1;
