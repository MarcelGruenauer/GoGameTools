package GoGameTools::Tree;
use GoGameTools::features;
use GoGameTools::Tree::TraversalContext;
use GoGameTools::Class qw(new @tree %metadata);

sub get_node ($self, $index) {
    return $self->tree->[$index];
}

sub unshift_node ($self, $node) {
    unshift $self->tree->@*, $node;
}

sub traverse ($self, $on_node) {

    # The context contains the whole tree as well, but the $tree parameter is
    # the current segment
    sub ($tree, $context) {
        $context->start_segment($tree);
        for my $node ($tree->@*) {
            if (ref $node eq ref []) {
                __SUB__->($node, $context);
            } else {
                $on_node->($node, $context);
                last if $context->should_abort;
            }
        }
        $context->finalize_segment;
      }
      ->($self->tree, GoGameTools::Tree::TraversalContext->new(tree => $self));
    return $self;    # for chaining
}

# A read-only copy
sub game_info ($self) {
    return $self->get_node(0)->get_scalar_properties_as_hash;
}

sub as_sgf ($self, $node_separator = '') {
    my $result = '';

    sub ($tree) {
        $result .= "\n(";
        for ($tree->@*) {
            if (ref eq ref []) {
                __SUB__->($_);
            } else {
                $result .= "$node_separator;" . $_->as_sgf;
            }
        }
        $result .= ')';
      }
      ->($self->tree);
    return $result =~ s/(^\s+|\s+$)//gsor;
}

# Tree paths are what Kombilo returns: 'a-b-c' means 'at move "a", choose
# sibling variation "b", then go to move "c".
#
# The tree is stored as [ <node>..., <var-array>... ]. So "a" could already be
# in a variation array. Both tree paths and array indices are zero-based.
#
# Travel down the nodes and when you encounter a varation, make it the new
# base.
sub get_node_for_tree_path ($self, $tree_path) {
    $tree_path .= '-0';
    my $cursor = $self->tree;
    while ($tree_path =~ s/^(\d+)-(\d+)-?//) {
        my ($n, $var_index) = ($1, $2);
        my $i = 0;
        while ($n >= 0) {
            my $candidate = $cursor->[$i];
            my $ref       = ref $candidate;
            if ($n == 0) {

                # If there is still a tree path left, we want to use the
                # $var_index-th variation as the new base for the outer while
                # loop.
                if (length $tree_path) {
                    my $var_candidate = $cursor->[ $i + $var_index ];
                    if (ref $var_candidate eq ref []) {
                        $cursor = $var_candidate;
                        last;
                    } else {

                        # Nothing to continue with for the remaining tree path;
                        # return undef.
                        return;
                    }
                } else {

                    # If we found a variation, return its first node; otherwise
                    # just return the candidate.
                    if ($ref eq ref []) {
                        return $candidate->[0];
                    } else {
                        return $candidate;
                    }
                }
            }

            # If we have a node, skip over it. If we have a variation array,
            # drill down into it. If we stepped outside the array, return
            # undef.
            if ($ref eq 'GoGameTools::Node') {
                $n--;
                $i++;
                next;
            } elsif ($ref eq ref []) {
                $cursor = $candidate;
                $i    = 0;
                next;
            } else {
                return;
            }
        }
    }
    return;
}

# When you want to print a message but want to report its location in a list of
# trees, use this method to add relevant metadata.
sub with_location ($self, $message) {
    1 while chomp $message;
    my ($filename, $index) = $self->metadata->@{qw(filename index)};
    $_ //= '?' for $filename, $index;
    return sprintf "%s in file %s index %s", $message, $filename, $index;
}
1;
