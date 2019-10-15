package GoGameTools::Tree::TraversalContext;
use GoGameTools::features;
use GoGameTools::Class qw($tree @segments $should_abort);

# 'segments' are the ancestor node lists that lead up to the current node.
#
# A traversal context holds the nodes that have already been traversed leading
# up to the current node. By carrying this around a node handler can get the
# parent node, all ancestor nodes, sibling nodes and the noth path ("e.g.,
# "1.4.2").
sub get_ancestors_for_node ($self, $node) {
    my @ancestors;
    my @linear_node_list =
      map { _get_nodes_in_segment($_)->@* } $self->segments->@*;
    for (@linear_node_list) {
        push @ancestors, $_;
        return \@ancestors if $_ eq $node;    # compare refaddrs
    }
    return [];                                # empty array if not found
}

sub get_parent_for_node ($self, $node) {
    my @linear_node_list =
      map { _get_nodes_in_segment($_)->@* } $self->segments->@*;
    for (0 .. $#linear_node_list - 1) {
        return $linear_node_list[$_] if $linear_node_list[ $_ + 1 ] eq $node;
    }
    return;                                   # undef if not found
}

sub get_children_for_node ($self, $node) {

    # Find the segment that contains $node. What follows it is either another
    # node or a list of variations. For variations, return a lsit of their
    # first nodes.
    for my $segment ($self->segments->@*) {
        my @segment_nodes = _get_nodes_in_segment($segment)->@*;
        while (my ($index, $candidate) = each @segment_nodes) {
            next unless $node eq $candidate;    # compare refaddrs
            if (defined(my $child = $segment_nodes[ $index + 1 ])) {
                return [$child];
            } else {
                return [ map { $_->[0] } _get_variations_in_segment($segment)->@* ];
            }
        }
    }
    return [];                                  # empty array if not found
}

sub get_index_for_node ($self, $node) {
    my @linear_node_list =
      map { _get_nodes_in_segment($_)->@* } $self->segments->@*;
    while (my ($index, $candidate) = each @linear_node_list) {
        return $index if $node eq $candidate;    # compare refaddrs
    }
    return;                                      # undef if not found
}

sub get_siblings_for_node ($self, $node) {
    for my $segment ($self->segments->@*) {

        # Only a node at the start of a segment can have siblings. Therefore
        # look at each segment's variations. If the first element in such a
        # variation is the node we want, then return the other variations.
        my (@siblings, $found);
        for my $variation (_get_variations_in_segment($segment)->@*) {
            my $first_node_in_var = $variation->[0];

            # There shouldn't be empty segments but I guess it can happen if
            # finalize_segment() adds a variation to the end of a segment and
            # splits it there.
            next unless defined $first_node_in_var;

            # During munging, it can happen that a segment doesn't have nodes,
            # only subvariations. So go down until you actually find a node.
            while (ref $first_node_in_var eq ref []) {
                $first_node_in_var = $first_node_in_var->[0];
            }
            if ($first_node_in_var eq $node) {    # compare refaddrs
                $found++;
            } else {
                push @siblings, $first_node_in_var;
            }
        }
        return [ grep { defined } @siblings ] if $found;

        # If we didn't find the node, @siblings will be reset in the next
        # swgmwnt iteration.
    }
    return [];    # empty array if not found
}

# The traversal callback can use the context object's add_variation() method to
# indicate that it wants to add that variation to the current tree variation.
# It doesn't directly modify the current segment because it might need to
# splice it; see finalize_segment(). Therefore here we only remember what we
# want to do and only in finalize_segment() we actually do it.
sub add_variation ($self, $node, @nodes) {

    # For the last segment, remember which variations we need to add once the
    # segment is finalized. The context object is passed around recursively, so
    # we need to remember for which segment the new variations are meant for.
    #
    # Use unshift() so the latest changes come first - when splicing, we want
    # to do it from the back to the front.
    unshift $self->{ $self->segments->[-1] }{_add_variation}->@*,
      { for_node => $node, variation => \@nodes };
}

# The traversal callback can use this method to insert one or more nodes before
# a node in the current segment. Unlike add_variation(), we don't need to
# remember what to do and later do it - we can do it directly. because when
# travering a tree, we won't see previous nodes again.
sub insert_before ($self, $node, @new_nodes) {
    my $segment = $self->segments->[-1];
    my $index;
    while (($index, my $candidate) = each $segment->@*) {
        last if $candidate eq $node;    # compare refaddrs
    }

    # splice outside the loop to avoid an endless loop
    splice $segment->@*, $index, 0, @new_nodes if defined $index;
}

sub prune_after ($self, $node) {
    $self->should_abort(1);
    $self->{ $self->segments->[-1] }{_prune_after} = $node;
}

sub start_segment ($self, $segment) {
    push $self->segments->@*, $segment;
}

# Actually add the variatons the we remembered in add_variation() for the
# current segment.
#
# The segments are array refs so modifying them will modify the original tree
# as well.
#
# We iterate over the segment to find the node using its refaddr. If the node
# at the following index is an array, i.e., a variation, already, we can just
# push the new variation onto the list of existing variations. But if that next
# node is a GoGameTools::Node object, then we need to splice the node list at
# that point and put the remainder into its own variation. We can then push the
# new variation onto it.
sub finalize_segment ($self) {
    my $segment = $self->segments->[-1];
    for my $spec ($self->{$segment}{_add_variation}->@*) {
        while (my ($index, $node) = each $segment->@*) {
            next unless $node eq $spec->{for_node};    # compare refaddrs
            if (ref $segment->[ $index + 1 ] ne ref []) {

                # Assume the current segment is "A - B - C - D" and we want to
                # insert a variation, "E - F" after "A". Then we need to create
                # "A - [ B - C - D ]", then push the new variation to end up
                # with "A - [ B - C - D ] [ E -F ]". But if we wanted to insert
                # a variation after "D", we don't want to create an empty
                # intermediate variation; instead we just want "A - B - C - D -
                # E - F".
                my @main_variation = splice $segment->@*, $index + 1;
                push $segment->@*, [ \@main_variation ] if @main_variation;
            }
        }
        push $segment->@*, $spec->{variation};
    }
    if (my $prune_after = $self->{$segment}{_prune_after}) {
        while (my ($index, $node) = each $segment->@*) {
            next unless $node eq $prune_after;         # compare refaddrs
            splice $segment->@*, $index + 1;
            $self->should_abort(0);
        }
    }
    delete $self->{$segment}{$_} for qw(_add_variation _prune_after);
    pop $self->segments->@*;
}

sub is_variation_start ($self, $node) {
    return $node eq $self->segments->[-1][0];          # compare refaddrs
}

# A node is a variation end if it is the last element of the segment - that is,
# if there are no more variations after it.
sub is_variation_end ($self, $node) {
    return $node eq $self->segments->[-1][-1];    # compare refaddrs
}

sub _get_nodes_in_segment ($segment) {
    return [ grep { ref eq 'GoGameTools::Node' } $segment->@* ];
}

sub _get_variations_in_segment ($segment) {
    return [ grep { ref eq ref [] } $segment->@* ];
}

sub get_tree_path_for_node ($self, $node) {

    # The segments array accessor contains the segments for the current node.
    # So the node must be in the last segment. Start with the last segments and
    # work your way to the beginning.
    #
    # $segment_index is the segment that we're currently looking at.
    my $segment_index = $self->segments->$#*;
    my @tree_path_parts;
    my @candidate_nodes =
      _get_nodes_in_segment($self->segments->[$segment_index])->@*;
    while (my ($candidate_index, $candidate) = each @candidate_nodes) {
        if ($node eq $candidate) {    # compare refaddrs
            unshift @tree_path_parts, $candidate_index;
            last;
        }
    }

    # While we are not at the beginning already, remember the first node of the
    # current segment, then move one segment up. Find the index for the
    # variation that contains that first node. If it is index 0, it means it's
    # not a real variation, just an artefact of how the tree is stored, so its
    # nodes really belong to the same tree path part; If the variation index is
    # greater than 0, it means we're on a real variation.
    while ($segment_index > 0) {
        my $first_node = $self->segments->[$segment_index][0];
        $segment_index--;
        my @candidate_variations =
          _get_variations_in_segment($self->segments->[$segment_index])->@*;
        my $variation_index;
        while (my ($candidate_index, $candidate) = each @candidate_variations) {
            if ($first_node eq $candidate->[0]) {    # compare refaddrs
                $variation_index = $candidate_index;
                last;
            }
        }
        return unless defined $variation_index;      # undef signals failure
        my $count_nodes_in_variation =
          scalar _get_nodes_in_segment($self->segments->[$segment_index])->@*;
        if ($variation_index == 0) {
            $tree_path_parts[0] += $count_nodes_in_variation;
        } else {
            unshift @tree_path_parts, $count_nodes_in_variation, $variation_index;
        }
    }
    return join '-', @tree_path_parts;
}
1;
