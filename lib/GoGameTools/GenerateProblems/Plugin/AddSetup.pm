package GoGameTools::GenerateProblems::Plugin::AddSetup;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Class qw(new);

sub handles_directive ($self, %args) {
    return $args{directive} eq 'add_setup';
}

sub handle_cloned_node_for_problem ($self, %args) {
    push $args{problem}->finalize_callbacks->@*, sub ($problem) {
        $args{problem}->tree->get_node(0)->add($_ => $args{original_node}->get($_))
          for qw(AB AW);
    };
}

sub is_pseudo_node ($self, %args) {
    return $args{node}->directives->{add_setup};
}
1;
