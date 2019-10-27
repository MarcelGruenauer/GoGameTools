package GoGameTools::GenerateProblems::Plugin::Debug;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::Class;

# If requested, write the problem's metadata to the generated problem's root
# node's GC[] property with location, tags and refs. Do this after assembling
# so the comment doesn't interfere with assembling. The viewer can then choose
# to display this data.
sub finalize_problem_2 ($self, %args) {
    return unless $args{generator}->should_comment_metadata;
    my $game_info_node = $args{problem}->tree->get_node(0);
    my %metadata       = $args{problem}->tree->metadata->%*;
    $game_info_node->add(
        GC => sprintf(
            "file %s index %s\n\n%s",
            $metadata{filename},
            $metadata{index},
            join("\n",
                (map { "#$_" } $metadata{tags}->@*),
                (map { "\@$_" } $metadata{refs}->@*))
        )
    );
}
1;
