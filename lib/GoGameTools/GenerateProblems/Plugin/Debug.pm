package GoGameTools::GenerateProblems::Plugin::Debug;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::Class;

# If requested, write the problem's metadata to the generated problem's root
# node's GC[] property with location, tags and/or refs. Do this after
# assembling so the comment doesn't interfere with assembling. The viewer can
# then choose to display this data.
sub finalize_problem_2 ($self, %args) {
    my @debug;
    my %metadata = $args{problem}->tree->metadata->%*;
    if ($args{generator}->should_comment_location) {
        push @debug, sprintf 'file %s index %s', $metadata{filename}, $metadata{index};
    }
    if ($args{generator}->should_comment_tags) {
        push @debug, join "\n", map { "#$_" } $metadata{tags}->@*;
    }
    if ($args{generator}->should_comment_refs) {
        push @debug, join "\n", map { "\@$_" } $metadata{refs}->@*;
    }
    $args{problem}->tree->get_node(0)->add(GC => join "\n\n", @debug) if @debug;
}
1;
