package GoGameTools::Assemble;
use GoGameTools::features;
use GoGameTools::Tree;
use GoGameTools::Class qw(%children_of %node_with_signature
  $on_adding_node $on_taking_signature $on_sort_child_sigs);
use constant ROOT_SIG => '<root>';

# $self->children_of->{foo} = { bar => 1, baz => 1 } means that the nodes with
# signatures 'bar' and 'baz' are both children of the node with signature 'foo'.
# checksum() combines the signatures of parent and child to make a new
# signature. So two nodes with the same content will still have different
# signatures if they are children of different parents.
sub add ($self, $tree) {
    $tree->traverse(
        sub ($node, $context) {
            my $parent           = $context->get_parent_for_node($node);
            my $parent_signature = $parent ? $parent->{_signature} : ROOT_SIG;

            # When constructing a node's signature, ignore certain root
            # properties. That way multiple problem files with the same
            # position set up on the root node can be assembled without
            # irrelevant properties getting in the way; some editors use
            # default values for PW, PB; some use CA but others don't etc.
            my $node_for_sig = GoGameTools::Node->new;
            $node_for_sig->add($_ => $node->get($_)) for qw(W B AW AB AE);
            my $node_sig = $node_for_sig->as_sgf;
            $node->{_signature} //= "$parent_signature;$node_sig";
            $self->children_of->{$parent_signature}{ $node->{_signature} } = 1;

            # remember which signature belongs to which node
            $self->node_with_signature->{ $node->{_signature} } = $node;
            $self->on_adding_node->($self, $node) if defined $self->on_adding_node;
        }
    );
    return $self;  # for chaining
}

sub _assemble_nodes ($self, $signature) {
    my $children_hash = $self->children_of->{$signature} // {};
    $self->on_taking_signature->($self, $signature)
      if defined $self->on_taking_signature;
    my @sig_node =
      $signature eq ROOT_SIG ? () : ($self->node_with_signature->{$signature});

    # silence 'deep recursion' warnings on game with more than 100 moves
    no warnings 'recursion';
    my @children_signatures = keys $children_hash->%*;
    if (@children_signatures == 1) {
        return (@sig_node, $self->_assemble_nodes($children_signatures[0]));
    } else {
        return (@sig_node,
            map { [ $self->_assemble_nodes($_) ] }
            sort { $self->on_sort_child_sigs->($a, $b, $self) } @children_signatures);
    }
}

sub tree ($self) {

    # If nothing has been added, just return nothing; not even an empty tree.
    return () unless keys $self->node_with_signature->%*;

    # The user can specify how variations in the assembled tree should be
    # sorted. The default order is just a string sort on the signatures.
    # Using this default order we can test it more easily.
    $self->on_sort_child_sigs(sub ($a, $b, $) { $a cmp $b })
      unless defined $self->on_sort_child_sigs;
    #
    my @nodes = $self->_assemble_nodes(ROOT_SIG);

    # If all input trees' first nodes had the same signature, the first node
    # will be that node. If that first node contains a move, we want to prefix
    # a new game info node.
    #
    # And if the input trees' first nodes had different signatures, they end up
    # as variations anyway and need a game info node because a tree cannot
    # start with variations.
    if (   (ref $nodes[0] eq 'GoGameTools::Node' && defined $nodes[0]->move)
        || (ref $nodes[0] eq ref [])) {
        my $game_info_node = GoGameTools::Node->new;

        # Valid SGF trees need GM and FF first; SGFGrove.js also checks this.
        $game_info_node->add(GM => 1);
        $game_info_node->add(FF => 4);
        $game_info_node->add(SZ => 19);
        $game_info_node->add(CA => 'UTF-8');
        $game_info_node->{_signature} = ROOT_SIG;
        unshift @nodes, $game_info_node;
    }
    return GoGameTools::Tree->new(tree => \@nodes);
}
1;

=pod

=head1 NAME

GoGameTools::Assemble - Assemble trees and subtrees that havee equal ancestors

=head1 SYNOPSIS

    my $asm = GoGameTools::Assemble->new;
    $asm->add($tree1);
    $asm->add($tree2);
    say $asm->tree;

=head1 DESCRIPTION

To explain how the algorithm works, assume that the input is this tree. Instead
of actual signatures, we just use letters for the signatures of individual
nodes and concatenate these letters to get the complete signature of a node.

(
    (A
        (B C (D E F) (D E F G))
        (B C I)
        (B J K)
    )
    (A
        (C D)
        (C E L)
    )
    (M)
)

After adding this tree with the C<add()> method, the C<children_of> hash looks
like this, flattened for readbility:

    <root> => A, M
    A      => AB, AC
    AB     => ABC, ABJ
    ABC    => ABCD, ABCI
    ABCD   => ABCDE
    ABCDE  => ABCDEF
    ABCDEF => ABCDEFG
    ABJ    => ABJK
    AC     => ACD, ACE
    ACE    => ACEL

To get the assembled tree, you call the C<tree()> method. It takes a signature
and returns the assembled tree - that is, a list of nodes -, for that
signature. To do so, it looks at the hash value for the given signature.

If there is no hash entry for the given signature, the function returns an
empty array.

Otherwise, the function at least returns the node with the given signature,
unless the signature is '<root>', for which there is no node.

If the hash value indicates that there is only one child signature, the
function additionally returns the result of assemble_nodes() for that child
signature. For example, assemble_nodes(ABCD) returns (D E F G).

If the hash value indicates the there are several children, the function
additionally returns an array reference containing the assembled nodes of
the children.

So for the above input, the function returns the desired tree:

    (A (B (C (D E F G) (J K)) (C (D) (E L))) (M))

You can add several trees, e.g., several complete games. So long as the games
have the exact same game info node, they will be merged properly. You can use
this with Go engines that don't know how to handle variations. For example, as
of October 2016, Leela and CrazyStone will let you take back moves and explore
alternative sequences, but undoing a move and replacing it with a different
move deletes the original move. So what you can do is saving the game before
undoing and replacing a sequence. You will have several game files and can then
use C<gogame-assemble> to assemble them into one tree with variations.
