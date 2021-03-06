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
    my $node_number;
    return (
        pipe_parse_sgf_from_file_list(files => \@files),
        pipe_convert_directives_from_comment(),
        pipe_each(
            sub {
                $_->traverse(
                    sub ($node, $context) {
                        track_board_in_traversal_for_node($node, $context);
                        parent_for_node($node, $context->get_parent_for_node($node));
                        tree_for_node($node, $_);
                        node_for_name(
                            $_->metadata->{filename},
                            $_->metadata->{index},
                            $node->directives->{name}, $node
                        ) if defined $node->directives->{name};
                    }
                );
            }
        ),
        pipe_create_story(story => $story, output_file => $self->output_file),
    );
}

# This pipe segment doesn't actually use the collection, but builds up the
# resulting tree from the story spec.
sub pipe_create_story (%args) {
    return sub ($collection) {
        my @result;
        for my $spec ($args{story}->@*) {
            for my $instruction ($spec->{instructions}->@*) {
                if ($instruction->{type} eq 'path') {
                    my $node_list = handle_path_instruction($spec, $instruction);
                    push @result, $node_list->@*;
                } elsif ($instruction->{type} eq 'node') {
                    my $node_list = handle_node_instruction($spec, $instruction);
                    push @result, $node_list->@*;
                } elsif ($instruction->{type} eq 'traverse') {
                    handle_traverse_instruction($spec, $instruction, \@result);
                } else {
                    die sprintf qq!unknown instruction type "%s"\n!, $instruction->{type};
                }
            }
        }

        # calculate changes between the nodes.
        my $story = sew_nodes(\@result);

        my $result_tree = GoGameTools::Tree->new(tree => $story);

        # Another traversal to clean up the resulting tree.
        #
        # If a node has a move, don't generate AB[] or AW[] for the same
        # coordinate. This can happen if the previous node already had a stone
        # at that coordinate.
        #
        # Dedup property values (see above).
        #
        # Delete game info properties from the other nodes; this can happen if
        # the story uses the game info node further down.

        $result_tree->traverse(
            sub ($node, $context) {
                $node->del(qw(GM FF AP CA DT KM PL SZ));
                for my $property (qw(AB AW)) {
                    my $values = $node->get($property);
                    my %seen;
                    $seen{$_}++ for $values->@*;
                    if (defined(my $move = $node->move)) {
                        delete $seen{$move};
                    }
                    $values->@* = keys %seen;
                }
            }
        );

        # Add new game info properties to the first node.
        $result_tree->get_node(0)->add($_->@*)
          for (
            [ CA => 'UTF-8' ],
            [ SZ => 19 ],
            [ FF => 4 ],
            [ GM => 1 ]
          );
        $result_tree->metadata->{filename} = $args{output_file};
        return [$result_tree];
    };
}

# This instruction specifies a linear path from one node to another node.
sub handle_path_instruction ($spec, $instruction) {
    my $from =
      node_for_name($spec->{filename}, $spec->{index}, $instruction->{from});
    my $to = node_for_name($spec->{filename}, $spec->{index}, $instruction->{to});
    my @node_list;
    my $this_node = $to;
    while (1) {
        unshift @node_list, $this_node;
        last if $this_node eq $from;    # compare refaddr
        if (defined(my $parent = parent_for_node($this_node))) {
            $this_node = $parent;
        } else {
            die sprintf q!file %s index %s: cannot reach node "%s" from node "%s"\n!,
              $spec->{filename}, $spec->{index}, $instruction->{from}, $instruction->{to};
        }
    }
    return \@node_list;
}

# This instruction specifies a single node.
sub handle_node_instruction ($spec, $instruction) {

    # This can be simulated with a "path" instruction that has the same "from"
    # and "to" node.
    $instruction->{from} = $instruction->{to} = delete $instruction->{node};
    return handle_path_instruction($spec, $instruction);
}

# This instruction specifies a depth-first traversal starting from one node.
sub handle_traverse_instruction ($spec, $instruction, $result_list) {
    my $from =
      node_for_name($spec->{filename}, $spec->{index}, $instruction->{from});

    # Find out which tree the node belongs to.
    my $tree = tree_for_node($from);

    # Traverse the tree. When you have found the "from" node, build up the node
    # lists for the story paths.
    my ($did_see_from_node, %did_take_node, @node_list);
    $tree->traverse(
        sub ($node, $context) {

            # Take a node if it is the "from" node or if we have already taken
            # the parent node - that is, we are within the subtree below the
            # "from" node.
            if (($node->directives->{name} // '') eq $instruction->{from}) {
                $did_see_from_node++;
                $did_take_node{$node}++;
                push @node_list, $node;
            } elsif ($did_take_node{ parent_for_node($node) // '' }) {
                $did_take_node{$node}++;
                push @node_list, $node;
            }

            # If the node is at the end of a variation, add the node list to
            # the story and reset the node list.
            if ($context->is_variation_end($node)) {
                push $result_list->@*, @node_list;
                @node_list = ();
            }
        }
    );
}

sub node_for_name ($filename, $index, $name, $new_value = undef) {
    our %_node_for_name;
    if (defined $new_value) {
        $_node_for_name{$filename}[$index]{$name} = $new_value;
    } else {
        use Carp qw(cluck);
        cluck "empty" if $name eq "";
        if (defined(my $node = $_node_for_name{$filename}[$index]{$name})) {
            return $node;
        } else {
            die qq!file $filename index $index: no node with name "$name"\n!;
        }
    }
}

sub parent_for_node ($node, $parent = undef) {
    our %_parent_for_node;

    # the hash keys are refaddrs
    if (defined $parent) {
        $_parent_for_node{$node} = $parent;
    } else {
        return $_parent_for_node{$node};
    }
}

sub tree_for_node ($node, $tree = undef) {
    our %_tree_for_node;

    # the hash keys are refaddrs
    if (defined $tree) {
        $_tree_for_node{$node} = $tree;
    } else {
        return $_tree_for_node{$node};
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
sub get_board_changes ($from_board, $to_board) {
    my %board_changes;
    for my $x ('a' .. 's') {
        for my $y ('a' .. 's') {
            my $coord      = "$x$y";
            my $from_value = $from_board->stone_at_coord($coord);
            $from_value = '' unless $from_value eq 'B' || $from_value eq 'W';
            my $to_value = $to_board->stone_at_coord($coord);
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

sub sew_nodes ($result_list) {
    my $current_board = GoGameTools::Board->new;
    my @story;
    for my $result_node ($result_list->@*) {
        my %board_changes = get_board_changes($current_board, $result_node->{_board});
        # this hash contains AW[], AB[] and AE[]. Apply these to a new node.
        my $story_node = GoGameTools::Node->new;
        while (my ($property, $values) = each %board_changes) {
            $story_node->add($property, $values);
        }
        # copy over certain properties
        for my $prop (qw(C TR SQ LB)) {
            if (defined(my $value = $result_node->get($prop))) {
                $story_node->add($prop, $value);
            }
        }
        # mark the current move with a circle (kludge)
        if (defined(my $move = $result_node->move)) {
            $story_node->add(CR => [ $move ]);
        }
        push @story, $story_node;
        $current_board = $result_node->{_board};
    }
    return \@story;
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
