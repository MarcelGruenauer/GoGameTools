package GoGameTools::GenerateProblems;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Tree;
use GoGameTools::Node;
use GoGameTools::Board;
use GoGameTools::TagHandler;
use GoGameTools::Class
  qw($viewer_delegate $source_tree @problems $on_warning
  $should_comment_game_info $should_comment_metadata);
use GoGameTools::Util;
use GoGameTools::Log;
use GoGameTools::Munge;
use GoGameTools::GenerateProblems::PluginHandler;
use GoGameTools::GenerateProblems::Problem;

sub raise_warning ($self, $message) {
    my $warning_handler = $self->on_warning // sub ($message) { warning $message };
    $warning_handler->($message);
}

# The following code requires that all node markup has been converted. If we
# did this during pipe_convert_directives_from_comment(), then, for example,
# BM[1] wouldn't have been converted to {{ bad_move }} yet.
sub preprocess_directives ($self, $tree) {
    $tree->traverse(
        sub ($node, $context) {

            # First let all plugins handle directives that themselves produce
            # other directives. Only afterwards can we let plugins preprocess all
            # directives. That is, we can't merge handle_higher_level_directive()
            # and preprocess_node().
            call_on_plugins(
                'handle_higher_level_directive',
                node              => $node,
                traversal_context => $context
            );
            call_on_plugins(
                'preprocess_node',
                node              => $node,
                traversal_context => $context
            );
        }
    );
}

sub propagate_metadata ($self, $tree) {

    # After munging the tree, copy tree tags from the parent node. So after
    # this trqversal each node has all the ancestral tree tags. This is useful
    # because when we extract problems from the trees we don't have to search
    # the ancestors for tree tags.
    $tree->traverse(
        sub ($node, $context) {
            if (my $parent = $context->get_parent_for_node($node)) {
                $node->add_tags(grep { $_->has_flag('a') } $parent->tags->@*);
                push $node->refs->@*, $parent->refs->@*;
            }
        },
    );
}

# Traverse the nodes and collect all tags. Expand them and store them in the
# tree metadata. Also collect all refs.and store them in the tree metadata.
sub finalize_metadata ($self, $problem) {
    my (%use_tag_names, %has_ref);
    my $color_to_play = color_to_play($problem->tree);
    $problem->tree->traverse(
        sub ($node, $) {
            $use_tag_names{$_}++
              for map { $_->name }
              grep    { $_->does_apply_to_color($color_to_play) } $node->tags->@*;
            $has_ref{$_}++ for $node->refs->@*;
        },
    );
    if (my $unwanted_tags = $problem->unwanted_tags) {
        delete $use_tag_names{$_} for map { $_->name } $unwanted_tags->@*;
    }
    my %has_tag_name;
    $has_tag_name{$_}++ for map { expand_tag_name($_) } keys %use_tag_names;
    delete $has_tag_name{$_} for get_phony_tags();

    # Resolve incompatible tags.
    #
    # {{ bad_move }} is stronger than {{ correct_for_both }}. This combination
    # could happen if a node A has two children, B and C. B is marked with
    # 'correct_for_both', C is marked with {{ bad_move }}. The
    # {{ correct_for_both }} is propoagated to its parent, so the problem that
    # includes C also sees it.
    delete $has_tag_name{correct_for_both} if $has_tag_name{bad_move};
    $problem->tree->metadata->{tags} = [ sort keys %has_tag_name ];
    $problem->tree->metadata->{refs} = [ sort keys %has_ref ];
}

sub finalize_directives ($self, $problem) {

    # For nodes that are marked with {{ guide }}, add a circle for the played
    # point to the parent node. But only add them for the color that is to play
    # in the problem. Plugins can also add markup so that later programs that
    # prepare a problem for a specific viewer can decide how to present the
    # problem; for example, see the Answer plugin.
    #
    # Also add a question mark for {{ answer }}. Also process
    # the {{ condition }} directive - they can only be done in this final
    # traversal because now we have their parent nodes.
    #
    # Then remove that and other unwanted markup.
    $problem->tree->traverse(
        sub ($node, $context) {

            # We extract trees without variations, so the only leaf node is
            # necessarily supposed to be correct. Also delete {{ correct }}
            # directives from non-leaf nodes. That way we can have nested
            # problems like "A - B [correct] - C - D [correct]."
            if ($context->is_variation_end($node)) {
                $self->viewer_delegate->mark_node_as_correct($node);
            }
            if (defined(my $parent_node = $context->get_parent_for_node($node))) {
                call_on_plugins(
                    'finalize_node',
                    node              => $node,
                    traversal_context => $context,
                    parent_node       => $parent_node
                );
                my $is_color_to_play =
                  ($node->move_color // '') eq color_to_play($context->tree);

                # Don't add CR[] and MA[] to "correct" nodes, that is, nodes at
                # the end of generated problems.
                if (   $is_color_to_play
                    && !$node->directives->{user_is_guided}
                    && !$parent_node->directives->{correct}) {
                    if ($node->directives->{guide}) {
                        $parent_node->add(CR => [ $node->move ]);
                    }
                }

                # Delete PL[] from nodes other than the game info node;
                # Here we already know that this node has a parent, so it's
                # not the game info node. Editors sometimes insert PL[],
                # but since the generated problems have no variations and
                # always alternate black and white moves, this property is
                # not needed and could even confuse SGF viewers.
                $node->del('PL');
            }

            # Delete many SGF properties that are not needed in problems.
            # This needs to be done after the above traversal because
            # otherwise we'd delete the 'deter' markup from a parent node
            # before child nodes can see it.
            #
            # V[] is set by SmartGo when using TW[] or TB[].
            $node->del(
                qw(
                  GN PW WR PB BR DT KM RE EV PC RO V
                  AP RU ST FG AN BT WT BL WL OB OW TB TW
                  HA CP OT SO TM PM VW CH BM TE PG SL IT HO
                  ),
            );
        },
    );
}

# Also add metadata from the original tree.
sub make_new_problem ($self) {
    my $tree = GoGameTools::Tree->new;
    $tree->metadata->%* = $self->source_tree->metadata->%*;
    return GoGameTools::GenerateProblems::Problem->new(tree => $tree);
}

sub run ($self) {
    debug($self->source_tree->with_location('debug:'));
    unless (defined $self->viewer_delegate) {
        fatal('GoGameTools::GenerateProblems needs a viewer delegate');
    }
    $self->preprocess_directives($self->source_tree);
    $self->propagate_metadata($self->source_tree);
    $self->source_tree->traverse(
        sub ($correct_node, $context) {

            # A variation end node is assumed to be correct. The node might
            # also have {{ correct }} set because of
            # pipe_convert_markup_to_directives(); q.v.
            return
              unless $context->is_variation_end($correct_node)
              || $correct_node->directives->{correct};

            # Create an empty problem and unshift nodes as we walk up to
            # this correct node's setup node.
            my $problem = $self->make_new_problem;

            # Assume the correct node contains the correct last move for a
            # problem.
            $problem->correct_color($correct_node->move_color);
            return if $correct_node->directives->{barrier};

            # Leaf nodes that don't have a move are natural barrier nodes,
            # so they won't auto-generate a problem. This is useful for the
            # main line in kifu, where the problems occur in the
            # variations, but obviously not in the main line.
            return unless $problem->correct_color;

            # $problem already contains the source tree's metadata; now also
            # tell it which tree path it originated from. For example, the
            # Check plugin can give more precise error messages using
            # with_location().
            $problem->tree->metadata->{tree_path} =
              $context->get_tree_path_for_node($correct_node);

            # Now we need to work our way backwards from the 'correct' node
            # build up the problem tree until we find the problem's setup
            # node.
            my $this_node = $correct_node;
            while (1) {
                my $cloned_node = $this_node->public_clone;
                call_on_plugins(
                    'handle_cloned_node_for_problem',
                    cloned_node       => $cloned_node,
                    original_node     => $this_node,
                    problem           => $problem,
                    generator         => $self,
                    traversal_context => $context
                );

                # For nodes that have a sibling that is not a bad move - that
                # is, there are multiple good moves to choose from - add a
                # guide directive to the cloned node.
                #
                # But don't do this if the {{ user_is_guided }} directive is in
                # effect. The problem author can either set this manually to
                # suppress the guide, or it is set automatically by other
                # directives. For example, see {{ add_setup }}.
                #
                # Also don't do this if the parent node has {{ assemble }},
                # which means that all non-bad children are correct moves,
                # so we don't want a guide there either.
                if (!$cloned_node->directives->{user_is_guided}
                    && has_non_bad_siblings_of_same_color($this_node, $context)) {
                    $cloned_node->directives->{guide} = 1;
                }

                # We have finished munging the cloned node; add it to the
                # problem tree.
                $problem->tree->unshift_node($cloned_node)
                  unless grep { $_ } call_on_plugins('is_pseudo_node', node => $cloned_node);
                my $did_split_off_problem;
                $self->handle_changing_objectives(
                    node                 => $this_node,
                    traversal_context    => $context,
                    on_changed_objective => sub ($new_objective_tags, $ancestor_tags) {

                        # see what changing objectives does
                        debug(
                            sprintf "%s: [%s] -> [%s]\n",
                            $self->source_tree->metadata->{filename} // 'n\a',
                            join(' ', map { $_->name } $ancestor_tags->@*),
                            join(' ', map { $_->name } $new_objective_tags->@*)
                        );

                        # Split off a new problem for the changed
                        # objective, starting with the node that changes
                        # the objective.
                        my $subproblem = $problem->clone;
                        $self->setup_problem_for_context_node(
                            problem           => $subproblem,
                            context_node      => $this_node,
                            traversal_context => $context,
                        );

                        # Remember to delete the tags for the changed
                        # objective from the original problem.
                        push $problem->unwanted_tags->@*, $new_objective_tags->@*;
                        push $self->problems->@*,         $subproblem;
                        $did_split_off_problem++;
                    }
                );

                # The parent node is a barrier if it doesn't contain a move
                # or if it's a bad move by the player holding the 'correct'
                # color.
                #
                # When we have found a barrier node, we exit the while-loop
                # so we don't unshift any more parent nodes to the new
                # problem tree.
                #
                # did_split_off_problem: avoid duplicate problems. If we
                # just did split off a problem from this position, don't
                # create another problem that would be identical apart form
                # tags.
                my $this_parent = $context->get_parent_for_node($this_node);
                if ($self->parent_is_barrier_node(
                        node      => $this_node,
                        parent    => $this_parent,
                        for_color => $problem->correct_color
                    )
                ) {
                    unless ($did_split_off_problem) {
                        $self->setup_problem_for_context_node(
                            problem           => $problem,
                            context_node      => $this_node,
                            traversal_context => $context,
                        );
                        push $self->problems->@*, $problem;
                    }
                    last;
                }
                $this_node = $this_parent;
            }
        },
    );
    $_->finalize for $self->problems->@*;
    $self->call_plugin_method_for_problems('finalize_problem_1');
    for my $problem ($self->problems->@*) {
        $self->finalize_metadata($problem);
        $self->finalize_directives($problem);
        $self->viewer_delegate->finalize_problem($problem);
    }
    call_on_plugins('finalize_problem_collection', generator => $self);
    $self->call_plugin_method_for_problems('finalize_problem_2');
    return $self;    # for chaining
}

sub call_plugin_method_for_problems ($self, $method_name) {

    # The plugins can push extra problems to $self->problems, so iterate
    # over a separate array to avoid endless loops.
    my @problems = $self->problems->@*;
    for my $problem (@problems) {
        call_on_plugins(
            $method_name,
            problem   => $problem,
            generator => $self,
        );
    }
}

# The problem already contains all the moves. Now we need to set up the
# initial position on the tree's game info node and handle various metadata.
# The context_node argument contains the node where the backwards traversal in
# run() stopped because its parent node was a barrier node.
sub setup_problem_for_context_node ($self, %args) {
    my $problem      = $args{problem};
    my $context_node = $args{context_node};
    my $setup_node;
    if ($context_node->move_color eq $problem->correct_color) {
        $setup_node = $args{traversal_context}->get_parent_for_node($context_node);
        $problem->tree->unshift_node($setup_node->public_clone);

        # No need to copy internal properties to the clone; the setup node
        # won't be a good move, a bad move or the solution.
    } else {

        # Since this node has a different move color than the "correct" color,
        # we'll use the position as of this node for the problem setup. If this
        # node doesn't have a comment but the parent node does, use that
        # comment.
        $setup_node = $context_node;
        if (my $setup_parent =
            $args{traversal_context}->get_parent_for_node($setup_node)) {
            if (!$problem->tree->get_node(0)->has('C') && $setup_parent->has('C')) {
                $problem->tree->get_node(0)->add(C => $setup_parent->get('C'));
            }
        }
    }

    # Get a list of nodes from the start to the setup node, then replay the
    # node sequence on a board; later we'll set it up on the game info node.
    # Play the moves now because we modify nodes later on.
    my $game_info = $problem->tree->get_node(0);
    $game_info->del(qw(AB AW B W));

    # setup the position on the game info node
    my $board = GoGameTools::Board->new;
    $board->play_node($_)
      for $args{traversal_context}->get_ancestors_for_node($setup_node)->@*;
    $board->setup_on_node($game_info);

    # Add number labels for previous moves as far back as possible.
    # Algorithm:
    # 1) get the ancestor nodes
    # 2) remember the current move's color; initially the color which is to
    #    play in the problem.
    # 3) go back from the latest node to the earliest node.
    #   - If the node has AB[], AW[] or AE[], we're done.
    #   - If the node doesn't have a move, skip it.
    #   - If the node has a move of the same color as the current color,
    #     we're done. Like in "B[cd];B[ef]".
    #   - Otherwise the node has a move of the opposite color than the current
    #     one. It is a move that we want to number, so remember it and switch
    #     the current color for the next iteration.
    # 4) Add number labels to the game info node for all remembered moves.
    my @ancestors =
      $args{traversal_context}->get_ancestors_for_node($setup_node)->@*;
    my $color_to_play = color_to_play($problem->tree);
    my @numbered;
    my $current_color = $color_to_play;
    my $num_limit     = 999;
    while (defined(my $previous_node = pop @ancestors)) {
        if (defined(my $this_limit = $previous_node->directives->{num})) {
            $num_limit = $this_limit if $this_limit < $num_limit;
        }
        last if $num_limit <= 0;

        # It doesn't make sense to continue numbering if the node changes the
        # position with AB[], AW[] or AE[].
        #
        # Check the size of the array properties; an empty AB[], AW[] or AE[]
        # shouldn't cause the loop to exit.
        last if $previous_node->get('AB')->@*;
        last if $previous_node->get('AW')->@*;
        last if $previous_node->get('AE')->@*;

        # Empty node, like a barrier node? Skip it.
        my $previous_move_color = $previous_node->move_color;
        next unless defined $previous_move_color;

        # Two sibling nodes with the same color? May represent tenuki. We're done.
        last if $previous_move_color eq $current_color;

        # Remember the move and switch the current color for the next iteration.
        unshift @numbered, $previous_node->move;
        $num_limit--;
        $current_color = $previous_move_color;

        # If a previous move is bad, show that in the final node as well.
        if ($previous_node->directives->{bad_move}) {
            $problem->labels_for_correct_node->{ $previous_node->move } =
              $self->viewer_delegate->label_for_bad_move;
        }
    }

    # Determine which position gets which number. If there is a ko, the same
    # position could be played several times, but we only want to display the
    # latest move number. But note earlier moves at the same location in the
    # comment, like '3 at 7'. Iterate over @numbered in reverse order.
    my (%number_for_location, @overlays);
    for (my $number = @numbered ; $number >= 1 ; $number--) {
        my $location = $numbered[ $number - 1 ];
        if (my $later_number = $number_for_location{$location}) {
            unshift @overlays, sprintf '%d at %d.', $number, $later_number;
        } else {
            $number_for_location{$location} = $number;
            $game_info->add(LB => [ [ $location, $number ] ]);
        }
    }
    if (@overlays) {
        $game_info->append_comment(join "\n", @overlays);
    }

    # Finalize the problem.
    $game_info->add($_->@*)
      for (
        [ PL => $color_to_play ],
        [ CA => 'UTF-8' ],
        [ SZ => 19 ],
        [ FF => 4 ],
        [ GM => 1 ]
      );
    while (my ($position, $label) = each $problem->labels_for_correct_node->%*) {
        $problem->tree->get_node(-1)->add(LB => [ [ $position, $label ] ]);
    }
}

# The parent node is a barrier
# - if it doesn't contain a move or
# - if it has the {{ barrier }} directive or
# - if it has the same move color as the current node or
# - if it's a bad move by the player holding the 'correct' color.
sub parent_is_barrier_node ($self, %args) {
    return 1 unless defined $args{parent};
    return 0
      if grep { $_ } call_on_plugins('is_pseudo_node', node => $args{parent});
    my $parent_move_color = $args{parent}->move_color;
    return 1 unless $parent_move_color;
    return 1 if $args{parent}{directives}{barrier};
    return 1 if ($args{node}->move_color // '') eq $parent_move_color;
    return 1
      if $args{parent}{directives}{bad_move}
      && $parent_move_color eq $args{for_color};
    return 0;
}

# A problem's objective can change in a variation. For example, a #encroaching
# problem can turn into a #killing_with_ko problem. See
# GoGameTools::Manual::Tags and
# t/plumbing/pipe_gen_problems/changing_objectives.sgf
sub handle_changing_objectives ($self, %args) {

    # In a change spec, the ancestor_objective is the problem's original
    # objective and the new_objective is what it might turn into.
    my @change_spec = (
        { ancestor_objective => 'offensive_endgame', new_objective => 'living' },
        { ancestor_objective => 'offensive_endgame', new_objective => 'killing' },
        {   ancestor_objective => 'offensive_endgame',
            new_objective      => 'capturing_race'
        },
        { ancestor_objective => 'living',          new_objective => 'killing' },
        { ancestor_objective => 'killing',         new_objective => 'living' },
        { ancestor_objective => 'killing_with_ko', new_objective => 'killing' },
    );
    my @ancestors =
      $args{traversal_context}->get_ancestors_for_node($args{node})->@*;
    pop @ancestors;    # the ancestors include the caller node itself
    for my $spec (@change_spec) {

        # For each change spec, check whether the node has the new objective.
        # If not, we continue to the next spec.
        my @tags_for_new_objective =
          grep { tag_name_is_or_does($_->name, $spec->{new_objective}) }
          $args{node}->tags->@*;
        next unless @tags_for_new_objective;

        # Now check whether any ancestor node has an incompatible objective. If
        # not, continue to the next spec.
        my @relevant_ancestor_tags;
        for my $ancestor (@ancestors) {
            @relevant_ancestor_tags =
              grep { tag_name_is_or_does($_->name, $spec->{ancestor_objective}) }
              $ancestor->tags->@*;

            # It's enough to find one ancestor with an incompatible
            # objective.
            last if @relevant_ancestor_tags;
        }
        next unless @relevant_ancestor_tags;

        # So the node does change the objective from the ancestor_objective to
        # the new_objective. Call the callback that will split off a new
        # problem and suppress the new objective in the original problem.
        $args{on_changed_objective}
          ->(\@tags_for_new_objective, \@relevant_ancestor_tags);
    }
}

sub get_generated_trees ($self) {
    return map { $_->tree } $self->problems->@*;
}
1;
