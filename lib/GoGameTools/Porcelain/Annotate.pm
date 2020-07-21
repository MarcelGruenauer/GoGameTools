package GoGameTools::Porcelain::Annotate;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::Log;
use File::Spec;
use GoGameTools::Class qw($file);

# Read the annotations file. Each tree in the collection has its filename and
# index in the metadata. For each tree, process all annotations for this tree.
#
# Only annotate nodes that are marked as good moves (TE[]). Otherwise too many
# unwanted, irrelevant, moves would match the patterns. But make a {{ note }}
# on moves without TE[] so that the user can search for those notes and
# possibly choose to add TE[].
#
# Tree paths:
#
# 'a-b-c' means 'at move "a", choose variation "b", then go to move "c". #
# Because of how the tree is represented in GoGameTools::Tree, getting to the
# final node is rather straightforward. Examples: '1-2-0' becomes
# $tree->[3][0]. '4-1-3-1-5' becomes $tree->[5][4][0]
#
# The base starts at the root of the tree. While the remaining tree path starts
# with '<number>-<number>-', go to that point in the node/variation array,
# which then becomes the new base. In the end, there is only one number in the
# tree path left, and that's the wanted node's array index.
#
# For example, in the above '4-1-3-1-5', we first get '4-1-' and go to
# $tree->[5]. Then we get '3-1-' and go to $tree->[5][4]. Then we get '0' and
# finally reach $tree->[5][4][0].
#
# Both tree paths and array indices are zero-based.
sub run ($self) {
    my $annotations = $self->parse_annotations_file;
    return sub ($collection) {
        for my $tree ($collection->@*) {
            my ($filename, $index) = $tree->metadata->@{qw(filename index)};
            for my $spec ($annotations->{$filename}{$index}->@*) {
                my ($tree_path, $annotation) = $spec->@*;
                my $node = $tree->get_node_for_tree_path($tree_path);
                unless (defined $node) {

                    # maybe the tree changed since the annotation list was created
                    fatal($tree->with_location("pipe_annotate: no node with tree path $tree_path"));
                }
                my $comment = $node->get('C') // '';
                if ($node->has('TE')) {
                    if (index($comment, $annotation) == -1) {
                        $comment = "$annotation:p\n$comment";
                    } else {
                        warning(
                            $tree->with_location(
                                "pipe_annotate: tag $annotation exists for node $tree_path")
                        );
                    }
                } else {

                    # Make a note if it doesn't already exist. Don't include
                    # the hashtag so it's not confused with real tags.
                    substr($annotation, 0, 1) = '';
                    my $note = "{{ note skip annotation $annotation }}";
                    if (index($comment, $note) == -1) {
                        $comment = "$note\n$comment";
                    }
                }
                $node->add(C => $comment);
            }
        }
        return $collection;
    };
}

sub parse_annotations_file ($self) {
    my @lines = split /\n/, slurp($self->file);
    my %annotations;
    for my $line (@lines) {
        my ($filename, $index, $tree_path, $annotation) = split /\t/, $line;
        $filename = File::Spec->rel2abs($filename);
        push $annotations{$filename}{$index}->@*, [ $tree_path, $annotation ];
    }
    return \%annotations;
}
1;
