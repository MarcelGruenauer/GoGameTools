package GoGameTools::Porcelain::GenerateProblems::Plugin::GameInfo;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::Class;

# If requested, write the problem's game information to the node's comment, if
# it is an actual game. Do this after assembling so the comment doesn't
# interfere with assembling.
sub finalize_problem_2 ($self, %args) {

    # If a tree has the 'game' tag, we want to copy the game information
    # from the source tree.
    return unless grep { $_ eq 'game' } $args{problem}->tree->metadata->{tags}->@*;
    my $source_game_info_node = $args{generator}->source_tree->get_node(0);
    my $game_info_node        = $args{problem}->tree->get_node(0);
    for my $property (qw(PW WR PB BR DT KM RE EV PC RO)) {
        my $value = $source_game_info_node->get($property);
        next unless defined $value;
        $game_info_node->add($property => $value);
    }
}
1;
