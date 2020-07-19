package GoGameTools::Porcelain::GenerateProblems::Plugin::AddSetup;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Log;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'add_setup';
}

# The {{ add_setup }} directive guides the user to choose a move
# depending on the presence of the added stones. So here we don't want
# the guide circle to appear.
sub handle_higher_level_directive ($self, %args) {
    my $parent_node = $args{traversal_context}->get_parent_for_node($args{node});
    if (defined($parent_node) && $parent_node->directives->{add_setup}) {
        $args{node}->directives->{user_is_guided} = 1;
    }
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
