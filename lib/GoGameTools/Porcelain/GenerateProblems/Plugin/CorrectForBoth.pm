package GoGameTools::Porcelain::GenerateProblems::Plugin::CorrectForBoth;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Log;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'correct_for_both';
}

sub handle_higher_level_directive ($self, %args) {
    if ($args{node}->directives->{correct_for_both}) {
        $args{node}->directives->{$_} = 1 for qw(correct copy);
        my $parent_node = $args{traversal_context}->get_parent_for_node($args{node});
        fatal('{{ correct_for_both }}: no parent node') unless defined $parent_node;
        $parent_node->directives->{$_} = 1 for qw(correct copy);

        # Use an internal directive, marked by a leading underscore, to
        # communicate the opponent response node that needs to be added to the
        # tree that starts with the parent of the {{ correct_for_both }} node.
        $parent_node->directives->{_correct_for_both_response} =
          $args{node}->public_clone;
        $_->add_tags('correct_for_both') for $args{node}, $parent_node;
    }
}

# If the previous code, called in an earlier traversal, indicated that we
# should append an opponent response node then do so.
sub finalize_problem_1 ($self, %args) {
    if (my $response_node =
        delete $args{problem}->tree->get_node(-1)->directives->{_correct_for_both_response}) {
        $args{problem}->tree->push_node($response_node);
    }
}
1;
