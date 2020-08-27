package GoGameTools::Tree;
use GoGameTools::features;
use GoGameTools::Tree::TraversalContext;
use GoGameTools::Class qw(@tree %metadata);

sub get_node ($self, $index) {
    return $self->tree->[$index];
}

sub push_node ($self, $node) {
    push $self->tree->@*, $node;
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
                $i      = 0;
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
    my $result = sprintf "%s in file %s index %s", $message, $filename, $index;
    if (defined(my $tree_path = $self->metadata->{tree_path})) {
        $result .= " tree path $tree_path";
    }
    return $result;
}

sub gen_metadata_filename ($self, $eval) {
    $eval //= 'qq!$v{year}.$v{month}.$v{day}-$v{PW}-$v{PB}.sgf!';
    my %v = (
        filename => 'problem',
        index    => 0,
        PB       => 'black',
        PW       => 'white',
        $self->metadata->%*,
        $self->game_info->%*,
    );
    s/\s+/_/go for values %v;
    if (defined $v{DT}) {
        if ($v{DT} =~ /^\d{4}$/o) {
            $v{DT} .= '.00.00';
        }
        if ($v{DT} =~ m{(\d{4})[-./](\d?\d)[-./](\d?\d)}o) {
            $v{year}  = $1;
            $v{month} = sprintf '%02d', $2;
            $v{day}   = sprintf '%02d', $3;
        }
    } else {
        $v{DT}    = '0000.00.00';
        $v{year}  = '0000';
        $v{month} = $v{day} = '00';
    }
    $v{basepath} = $v{filename} =~ s/\.sgf$//r;
    my $new_filename = ref $eval eq ref sub { }
      ? $eval->(%v) : eval($eval);
    fatal($@) if $@;
    $new_filename =~ s/^~/$ENV{HOME}/ge;
    $new_filename =~ tr!A-Za-z0-9_./-!!cd;

    # generate a random suffix
    my @chars = ('0' .. '9', 'A' .. 'Z', 'a' .. 'z');
    my $len   = 8;
    my $suffix;
    while ($len--) { $suffix .= $chars[ rand @chars ] }
    $new_filename =~ s/(?=\.sgf$)/-$suffix/;
    return $self->metadata->{filename} = $new_filename;
}
1;
