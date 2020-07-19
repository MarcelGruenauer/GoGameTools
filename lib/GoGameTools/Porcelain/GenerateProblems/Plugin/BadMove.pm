package GoGameTools::Porcelain::GenerateProblems::Plugin::BadMove;
use GoGameTools::features;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'bad_move';
}

sub handle_cloned_node_for_problem ($self, %args) {
    if ($args{cloned_node}->directives->{bad_move}) {
        $args{problem}->labels_for_correct_node->{ $args{cloned_node}->move } =
          $args{generator}->viewer_delegate->label_for_bad_move;
    }
}

# If the problem contains a 'bad move', add the '#refute_bad_move' tag. We know
# that it's a refutation because the design philosophy is that the student
# never has to play a bad move while solving a problem.
sub finalize_problem_1 ($self, %args) {
    my $has_bad_move;
    $args{problem}->tree->traverse(
        sub ($node, $context) {
            return unless $node->directives->{bad_move};
            $has_bad_move++;
            $context->should_abort;   # finding one bad move is enough
        }
    );
    $args{problem}->tree->get_node(0)->add_tags('refute_bad_move') if $has_bad_move;
}
1;
