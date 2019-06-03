package GoGameTools::GenerateProblems::Plugin::Debug;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::Class qw(new);

# If requested, write the problem's metadata to the node's comment with
# location, tags and refs. Do this after assembling so the comment doesn't
# interfere with assembling.
sub finalize_problem_2 ($self, %args) {
    return unless $args{generator}->should_comment_metadata;
    my $game_info_node = $args{problem}->tree->get_node(0);

    # show the metadata
    my %metadata = $args{problem}->tree->metadata->%*;
    $game_info_node->prepend_comment(
        sprintf "file %s index %s\n\n%s",
        $metadata{filename},
        $metadata{index},
        join("\n",
            (map { "#$_" } $metadata{tags}->@*),
            (map { "\@$_" } $metadata{refs}->@*))
    );
}
1;
