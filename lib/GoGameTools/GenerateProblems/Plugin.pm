package GoGameTools::GenerateProblems::Plugin;
use GoGameTools::features;
use GoGameTools::Class qw(new);

# plugins can implement one or more of these hooks
sub handles_directive              { }
sub handle_higher_level_directive  { }
sub preprocess_node                { }
sub handle_cloned_node_for_problem { }
sub finalize_node                  { }
sub finalize_problem_1             { }
sub finalize_problem_2             { }
sub finalize_problem_collection    { }
sub is_pseudo_node                 { }

sub _divide_children_into_good_and_bad ($self, $node, $context) {
    my $node_color = $node->move_color;
    my (@good_children, @bad_children);
    for (grep { defined $_->move_color } $context->get_children_for_node($node)->@*)
    {
        if ($_->directives->{bad_move}) {
            push @bad_children, $_;
        } else {
            push @good_children, $_;
        }
    }
    return (\@good_children, \@bad_children);
}
1;
