package GoGameTools::GenerateProblems::Plugin::AddSetup;
use GoGameTools::features;
use GoGameTools::Node;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'add_setup';
}

sub handle_cloned_node_for_problem ($self, $, $original_node, $problem, $) {
    push $problem->finalize_callbacks->@*, sub ($problem) {
        $problem->tree->get_node(0)->add($_ => $original_node->get($_)) for qw(AB AW);
    };
}

sub is_pseudo_node ($self, $node) {
    return $node->directives->{add_setup};
}
1;
