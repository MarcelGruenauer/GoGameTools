package GoGameTools::GenerateProblems::Plugin::BadMove;
use GoGameTools::features;
use GoGameTools::Class qw(new);

sub handles_directive ($self, %args) {
    return $args{directive} eq 'bad_move';
}

sub handle_cloned_node_for_problem ($self, %args) {
    if ($args{cloned_node}->directives->{bad_move}) {
        $args{problem}->labels_for_correct_node->{ $args{cloned_node}->move } =
          $args{generator}->viewer_delegate->label_for_bad_move;
    }
}
1;
