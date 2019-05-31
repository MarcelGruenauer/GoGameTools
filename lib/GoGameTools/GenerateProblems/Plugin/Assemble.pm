package GoGameTools::GenerateProblems::Plugin::Assemble;
use GoGameTools::features;
use GoGameTools::Assemble;
use GoGameTools::GenerateProblems::Problem;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'assemble';
}

sub handle_cloned_node_for_problem ($self, %args) {
    my $parent =
      $args{traversal_context}->get_parent_for_node($args{original_node});
    if ($parent->directives->{assemble}
        && !$args{cloned_node}->directives->{bad_move}) {

        # All problem trees that have the same node path in '_needs_assembly'
        # will later be assembled into one tree.
        #
        # This method is called for each node as
        # GoGameTools::GenerateProblems->run() walks up the parents. So if there
        # are nested {{ assemble }} directives - that is, the descendants of an
        # {{ assemble }} node contain themselves one or more {{ assemble }}
        # nodes - we will see the topmost such node last. That is as it should
        # be, for that topmost such node is the one under which the whole
        # assembled tree will be placed.
        #
        # But it's really not necessary to have nested {{ assemble }} nodes
        # because the whole subtree underneath such a node will be assembled
        # anyway.
        #
        # Use the refaddr of the parent node whose children we want to
        # assemble.
        $args{problem}->needs_assembly('' . $parent);

        # Delete guides from nodes we've collected so far, i.e., descendant
        # nodes. Guides and deterrants would prevent problems from being
        # properly assembled.
        $args{problem}->tree->traverse(sub { delete $_[0]->directives->{guide} });

        # We don't want guides to appear because by definition trees are only
        # assembled if all alternatives are good moves.
        $args{cloned_node}->directives->{user_is_guided} = 1;
    }
}

sub finalize_problem_collection ($self, %args) {
    my (@result, %assembly_for_path);
    for my $problem ($args{generator}->problems->@*) {
        if (defined(my $refaddr = $problem->needs_assembly)) {

            # For each node path to be assembled, also remember the metadata
            # from the first tree for that node path. We need to set the
            # metadata in the assembled tree below. We can't just take the
            # first problem tree because it might come from a different branch
            # that has different tags.
            $assembly_for_path{$refaddr} //= {
                assembler => GoGameTools::Assemble->new,
                metadata  => $problem->tree->metadata
            };
            $assembly_for_path{$refaddr}{assembler}->add($problem->tree);
        } else {

            # no assembly required; use the tree as-is
            push @result, $problem->tree;
        }
    }

    # Add the assembled trees and set an artifical node path for each one.
    while (my ($refaddr, $assembly) = each %assembly_for_path) {
        my $tree = $assembly->{assembler}->tree;

        # Copy over the metadata we remembered from the first tree in this
        # assembly. None of the assembled problems' node paths applies, so set
        # an artifical node path. Also add a tag so the user can filter by
        # problems that have multiple solutions.
        $tree->metadata->%* = $assembly->{metadata}->%*;
        push @result, $tree;
    }
    $args{generator}->problems->@* =
      map { GoGameTools::GenerateProblems::Problem->new(tree => $_) } @result;
}
1;
