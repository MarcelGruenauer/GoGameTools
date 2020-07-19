package GoGameTools::Porcelain::GenerateProblems::Plugin::IsResponse;
use GoGameTools::features;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'is_response';
}

# If the child node - that is, the first node of the problem tree's current
# node list - has {{ is_response }}, then we'll reset the "correct color".
sub handle_cloned_node_for_problem ($self, %args) {
    my $first_node = $args{problem}->tree->get_node(0);
    return unless defined $first_node && ref $first_node eq 'GoGameTools::Node';
    if ($first_node->directives->{is_response}) {
        $args{problem}->correct_color($args{cloned_node}->move_color);
    }
}
1;
