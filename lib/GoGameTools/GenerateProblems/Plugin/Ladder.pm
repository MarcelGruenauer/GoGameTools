package GoGameTools::GenerateProblems::Plugin::Ladder;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Log;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'needs_ladder' || $directive eq 'ladder_good_for';
}

sub handle_cloned_node_for_problem ($self, $cloned_node, $original_node,
    $problem, $) {
    if (my $l = $cloned_node->directives->{ladder_good_for}) {

        # Remember only the definition closest to the leaf node
        $problem->ladder_good_for($l)
          unless defined $problem->ladder_good_for;
        $cloned_node->directives->{condition} =
          sprintf('The ladder is good for %s.', name_for_color_const($l));

        # do what the Condition plugin would have done
        $cloned_node->directives->{user_is_guided} = 1;
    }
    if ($cloned_node->directives->{needs_ladder}) {
        fatal(
            $original_node->with_location(
                'Saw {{ needs_ladder }} but no {{ ladder_good_for }} directive')
        ) unless defined $problem->ladder_good_for;
        my $move_color = $cloned_node->move_color;
        if ($move_color eq $problem->ladder_good_for) {
            $cloned_node->directives->{condition} =
              sprintf('The ladder is good for %s.', name_for_color_const($move_color));

            # do what the Condition plugin would have done
            $cloned_node->directives->{user_is_guided} = 1;
        } else {
            # Do what {{ bad_move }} would do. But don't just set the
            # 'bad_move' directive because plugins run in an undefined order.
            $problem->labels_for_correct_node->{ $cloned_node->move } = '?';
        }
    }
}
1;
