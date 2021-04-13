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
        pipe_parse_sgf_from_file_list(files => \@files),
        pipe_convert_directives_from_comment(),
        pipe_each(
            sub {
                $_->traverse(
                    sub ($node, $context) {
                        track_board_in_traversal_for_node($node, $context);
                        our %parent_of_node;
                        parent_of_node($node, $context->get_parent_for_node($node));
                        if (defined(my $name = $node->directives->{name})) {
                            node_for_name($_->metadata->{filename}, $_->metadata->{index}, $name, $node);
                        }
                    }
                );
            }
        ),
        pipe_create_story(story => $story, output_file => $self->output_file),
    );
}

sub pipe_create_story (%args) {

    # This pipe segment doesn't actually use the collection, but builds up the
    # resulting tree from the story spec.
    return sub ($collection) {
        my @result;
        for my $spec ($args{story}->@*) {
            for my $instruction ($spec->{instructions}->@*) {
                if ($instruction->{type} eq 'path') {
                    my $from =
                      node_for_name($spec->{filename}, $spec->{index}, $instruction->{from});
                    my $to = node_for_name($spec->{filename}, $spec->{index}, $instruction->{to});
                    my @nodes_in_path;
                    my $this_node = $to;
                    while (1) {
                        unshift @nodes_in_path, $this_node;
                        last if $this_node eq $from;    # compare refaddr
                        our %parent_of_node;
                        if (defined(my $parent = parent_of_node($this_node))) {
                            $this_node = $parent;
                        } else {
                            die sprintf q!file %s index %s: cannot reach node "%s" from node "%s"\n!,
                              $spec->{filename}, $spec->{index}, $instruction->{from}, $instruction->{to};
                        }
                    }
                    if (@result) {

                        # $original_node is a node that contains the board position
                        # at the end of the current result node list.
                        my $original_node = node_for_name($spec->{filename}, $spec->{index},
                            $result[-1]->directives->{name});

                        # %board_changes contains AW[], AB[] and AE[]. Apply these
                        # to the path start node, but clone it because that node
                        # can be in more than one path.
                        my %board_changes = get_board_changes($original_node, $nodes_in_path[0]);
                        $nodes_in_path[0] = $nodes_in_path[0]->public_clone;
                        while (my ($property, $values) = each %board_changes) {
                            $nodes_in_path[0]->add($property, $values);
                        }
                    }
                    push @result, @nodes_in_path;
                } else {
                    die sprintf qq!unknown instruction type "%s"\n!, $instruction->{type};
                }
            }
        }
        my $result_tree = GoGameTools::Tree->new(tree => \@result);
        $result_tree->metadata->{filename} = $args{output_file};
        return [$result_tree];
    };
}

sub node_for_name ($filename, $index, $name, $new_value = undef) {
    our %node_for_name;
    if (defined $new_value) {
        $node_for_name{$filename}[$index]{$name} = $new_value;
    } else {
        if (defined(my $node = $node_for_name{$filename}[$index]{$name})) {
            return $node;
        } else {
            die qq!file $filename index $index: no node with name "$name"\n!;
        }
    }
}

sub parent_of_node ($node, $parent = undef) {
    our %parent_for_node;

    # the hash keys are refaddrs
    if (defined $parent) {
        $parent_for_node{$node} = $parent;
    } else {
        return $parent_for_node{$node};
    }
}

# Detect how the board position changes between two nodes. For each board
# intersection:
#
# If the new board has a stone and the old board does not have a stone or has a
# stone of the opposite color, add AB[] or AW[].
#
# If the new board does not have a stone and the old board has a stone, add
# AE[].
sub get_board_changes ($from_node, $to_node) {
    my %board_changes;
    for my $x ('a' .. 's') {
        for my $y ('a' .. 's') {
            my $coord      = "$x$y";
            my $from_value = $from_node->{_board}->stone_at_coord($coord);
            $from_value = '' unless $from_value eq 'B' || $from_value eq 'W';
            my $to_value = $to_node->{_board}->stone_at_coord($coord);
            $to_value = '' unless $to_value eq 'B' || $to_value eq 'W';
            if ($to_value) {
                push $board_changes{"A$to_value"}->@*, $coord unless $from_value eq $to_value;
            } else {
                push $board_changes{AE}->@*, $coord if $from_value;
            }
        }
    }
    return %board_changes;
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
  result and the path start node. Apply these changes to the path start node.

The story is in an external file because it can combine paths from different
trees.

=cut
