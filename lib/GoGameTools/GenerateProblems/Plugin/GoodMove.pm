package GoGameTools::GenerateProblems::Plugin::GoodMove;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'good_move';
}

sub handle_cloned_node_for_problem ($self, $cloned_node, $, $problem, $) {
    if ($cloned_node->directives->{good_move}) {
        $problem->labels_for_correct_node->{ $cloned_node->move } = '!';
    }
}
1;
