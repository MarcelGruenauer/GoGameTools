package GoGameTools::GenerateProblems::Plugin::Debug;
use GoGameTools::features;
use GoGameTools::Assemble;
use parent 'GoGameTools::GenerateProblems::Plugin';

# If requested, annotation the problem's game information node's comment with
# location, tags and refs. Do this after assembling so the comment doesn't
# interfere with assembling.
sub finalize_problem_2 ($self, %args) {
    return unless $args{generator}->annotate;
    my $game_info_node = $args{problem}->tree->get_node(0);

    # show the metadata
    my %metadata = $args{problem}->tree->metadata->%*;
    $game_info_node->prepend_comment(
        sprintf "location %s\n\n%s",
        $metadata{location},
        join("\n",
            (map { "#$_" } $metadata{tags}->@*),
            (map { "\@$_" } $metadata{refs}->@*))
    );
}
1;
