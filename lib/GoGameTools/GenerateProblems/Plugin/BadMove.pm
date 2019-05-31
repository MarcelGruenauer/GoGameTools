package GoGameTools::GenerateProblems::Plugin::BadMove;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'bad_move';
}

sub handle_cloned_node_for_problem ($self, %args) {
    if ($args{cloned_node}->directives->{bad_move}) {
        $args{problem}->labels_for_correct_node->{ $args{cloned_node}->move } =
          $args{generator}->viewer_delegate->label_for_bad_move;
    }
}
1;
