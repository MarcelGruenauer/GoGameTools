package GoGameTools::Porcelain::MakeLinearStory;
use GoGameTools::features;
use GoGameTools::Plumbing;
use GoGameTools::Color;
use GoGameTools::Log;
use GoGameTools::JSON;
use GoGameTools::Util;
use GoGameTools::Munge;
use GoGameTools::Class qw($story_file $output_file);
use File::Spec;
use File::Basename;

sub run ($self) {
    my $story         = json_decode(slurp($self->story_file));
    my $abs_story_dir = dirname(File::Spec->rel2abs($self->story_file));
    my %seen_file;
    for my $spec ($story->@*) {
        $spec->{filename} = File::Spec->rel2abs($spec->{filename}, $abs_story_dir);
        $seen_file{ $spec->{filename} }++;
    }
    my @files = sort keys %seen_file;
    return (
        pipe_decode_json_from_file_list(files => \@files),
        pipe_convert_directives_from_comment(),
        pipe_each(
            sub {
                $_->traverse(
                    sub ($node, $context) {
                        track_board_in_traversal_for_node($node, $context);
                        if (defined(my $name = $node->directives->{name})) {
                            node_for_name($_->metadata->{filename}, $_->metadata->{index}, $name, $node);
                        }
                    }
                );
            }
        ),
        pipe_create_story(story => $story),
    );
}

sub pipe_create_story (%args) {
    return sub ($collection) {
        for my $spec ($args{story}->@*) {
            for my $path ($spec->{paths}->@*) {
                my $from = node_for_name($spec->{filename}, $spec->{index}, $path->{from});
                my $to   = node_for_name($spec->{filename}, $spec->{index}, $path->{to});
                use DDP; p $path; p $from; p $to;
                # FIXME
                # error if $from or $to are undef
                # now go up from $to to $from
                # error if $from can't be reached
            }
        }
    };
}

sub node_for_name ($filename, $index, $name, $new_value = undef) {
    our %node_for_name;
    if (defined $new_value) {
        $node_for_name{$filename}[$index]{$name} = $new_value;
    } else {
        return $node_for_name{$filename}[$index]{$name};
    }
}
1;

=pod

Algorithm:
- Set the result to the empty list. This will contain the linear list of nodes.
- Traverse the tree.
  - Track the board position for each node.
  - For named nodes, store a reference in a hash that maps names to nodes.
- For each path:
  - Go to the path end node using the name map.
  - Go up the ancestors until you find the path start node. Remember all nodes
    in the path.
  - Detect how the board position changes between the last node of the current
    result and the first node of the path. For each board intersection:
      - If the new board has a stone and the old board does not have a stone or
        has a stone of the opposite color, add AB[] or AW[].
      - If the new board does not have a stone and the old board has a stone,
        add AE[].

The story is in an external file because it can combine paths from different trees.

GoGameTools::Porcelain::LinearStory
needs a new directive, 'name'.

=cut
