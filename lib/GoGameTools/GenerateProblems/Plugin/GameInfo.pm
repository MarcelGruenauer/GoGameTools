package GoGameTools::GenerateProblems::Plugin::GameInfo;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::Class qw(new);

# If requested, write the problem's game information to the node's comment, if
# it is an actual game. Do this after assembling so the comment doesn't
# interfere with assembling.
sub finalize_problem_2 ($self, %args) {

    # If a tree has the 'game' tag, we want to copy the game information
    # from the source tree.
    return unless grep { $_ eq 'game' } $args{problem}->tree->metadata->{tags}->@*;
    my $source_game_info_node = $args{generator}->source_tree->get_node(0);

    # use an array to impose the order we want for the comment
    my @game_info = grep { defined $_->[1] }
      map { [ $_, $source_game_info_node->get($_) ] }
      qw(PW WR PB BR DT KM RE EV PC RO);
    my $game_info_node = $args{problem}->tree->get_node(0);
    $game_info_node->add($_->@*) for @game_info;
    if ($args{generator}->should_comment_game_info) {

        # game info goes at the top via prepending
        $game_info_node->prepend_comment(join("\n",
            map { sprintf('%4s: %s', $_->@*) } @game_info), "\n\n");
    }
}
1;
