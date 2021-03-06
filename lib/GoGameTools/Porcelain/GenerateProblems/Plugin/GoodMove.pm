package GoGameTools::Porcelain::GenerateProblems::Plugin::GoodMove;
use GoGameTools::features;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'good_move';
}

sub handle_cloned_node_for_problem ($self, %args) {
    if ($args{cloned_node}->directives->{good_move}) {
        $args{problem}->labels_for_correct_node->{ $args{cloned_node}->move } =
          $args{generator}->viewer_delegate->label_for_good_move;
    }
}
1;
