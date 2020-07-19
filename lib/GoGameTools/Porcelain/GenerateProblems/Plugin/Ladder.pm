package GoGameTools::Porcelain::GenerateProblems::Plugin::Ladder;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Log;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'needs_ladder'
      || $args{directive} eq 'ladder_good_for';
}

sub handle_cloned_node_for_problem ($self, %args) {
    if (my $l = $args{cloned_node}->directives->{ladder_good_for}) {

        # Remember only the definition closest to the leaf node
        $args{problem}->ladder_good_for($l)
          unless defined $args{problem}->ladder_good_for;
        $args{cloned_node}->directives->{condition} =
          sprintf('The ladder is good for %s.', name_for_color_const($l));

        # do what the Condition plugin would have done
        $args{cloned_node}->directives->{user_is_guided} = 1;
    }
    if ($args{cloned_node}->directives->{needs_ladder}) {
        fatal(
            $args{original_node}->with_location(
                'Saw {{ needs_ladder }} but no {{ ladder_good_for }} directive')
        ) unless defined $args{problem}->ladder_good_for;
        my $move_color = $args{cloned_node}->move_color;
        if ($move_color eq $args{problem}->ladder_good_for) {
            $args{cloned_node}->directives->{condition} =
              sprintf('The ladder is good for %s.', name_for_color_const($move_color));

            # do what the Condition plugin would have done
            $args{cloned_node}->directives->{user_is_guided} = 1;
        } else {

            # Do what {{ bad_move }} would do. But don't just set the
            # 'bad_move' directive because plugins run in an undefined order.
            $args{problem}->labels_for_correct_node->{ $args{cloned_node}->move } =
              $args{generator}->viewer_delegate->label_for_bad_move;
        }
    }
}
1;
