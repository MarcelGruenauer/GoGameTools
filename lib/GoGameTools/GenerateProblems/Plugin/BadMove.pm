package GoGameTools::GenerateProblems::Plugin::BadMove;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'bad_move';
}

sub handle_cloned_node_for_problem ($self, $cloned_node, $, $problem, $) {
    if ($cloned_node->directives->{bad_move}) {
        $problem->labels_for_correct_node->{ $cloned_node->move } = '?';
    }
}
1;
