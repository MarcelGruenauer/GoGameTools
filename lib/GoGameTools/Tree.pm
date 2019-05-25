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
      ->($self->tree,
        GoGameTools::Tree::TraversalContext->new(tree => $self));
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

# When you want to print a message but want to report its location in a list of
# trees, use this method to add relevant metadata.
sub with_location ($self, $message) {
    1 while chomp $message;
    return sprintf "%s in %s", $message,
      ($self->metadata->{location} // $self->metadata->{filename}) // '?';
}
1;
