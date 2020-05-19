package GoGameTools::Porcelain::MakeOpeningTree;
use GoGameTools::features;
use GoGameTools::Plumbing;
use GoGameTools::Color;
use GoGameTools::Munge;
use GoGameTools::Log;
use GoGameTools::Class qw($moves $prune $filename $should_reorient
  $should_add_game_info $should_add_stats $title $date $AN $SO
  %data_for_signature $assembler);

# The user can use the following constructor arguments:
# - $moves
# - $prune
# - $filename
# - $should_reorient
# - $should_add_game_info
# - $should_add_stats
# - $title
# - $AN (annotator)
# - $SO (source)
sub run ($self) {
    return (
        # filter out unwanted games
        sub ($collection) {
            my @out;
            for my $tree ($collection->@*) {
                my @reject;
                $tree->traverse(
                    sub ($node, $context) {
                        my $i = $context->get_index_for_node($node);
                        $context->prune_after($node) if $i >= $self->moves;
                        if ($i == 1) {
                            my $move = $node->move;
                            if (defined $move) {
                                if ($node->move_color ne BLACK) {
                                    push @reject, 'node 1 has no black move';
                                } elsif ($move eq '') {
                                    push @reject, 'node 1 has a pass';
                                }
                            } else {
                                push @reject, 'node 1 has no move';
                            }
                        }
                        $node->{_move_number} = $i;
                    }
                );
                if (@reject) {
                    info(sprintf 'reject %s: %s', $tree->{metadata}{filename}, join('; ', @reject));
                } else {
                    push @out, $tree;
                }
            }
            if (@out) {
                info(sprintf 'taking %s', games_pluralized(scalar(@out)));
            } else {
                info('no games meet the criteria');
            }
            return \@out;
        },
        pipe_each(
            sub {
                # We want to annotate the final node of each game in the output
                # tree with the game information, e.g. when it was played and who
                # played it. So before splicing away the original game information
                # node, compute this string and store it in each node.
                my $game_info_node = $_->get_node(0);
                my %info = map { $_ => $game_info_node->get($_) // '' } qw(DT PW WR PB BR);
                $info{$_} = " ($info{$_})" for grep { length($info{$_}) } qw(WR BR);

                # try to extract a date or part of a date; otherwise just leave it
                if ($info{DT} =~ /(
                (\b\d{4}-[01]\d-[0123]\d\b) |
                (\b\d{4}-[01]\d\b) |
                (\b\d{4}\b) )/x
                ) {
                    $info{DT} = $1;
                }
                my $game_info = sprintf '%s %s%s - %s%s', @info{qw(DT PW WR PB BR)};

                # Remove the original game info node; assembling will create a
                # new tree with a new game info node.
                shift $_->tree->@*;
                $_->traverse(
                    sub ($node, $context) {
                        $node->{_game_info} = $game_info;
                    }
                );
                normalize_tree_orientation($_) if $self->should_reorient;
            }
        ),
        pipe_assemble(
            on_adding_node => sub ($assembler, $node) {
                $self->assembler($assembler);

                # There can be several nodes with the same signature, so remember
                # the game info for all of them, in case that this node ends up as a
                # leaf node; see the traversal below.
                $self->data_for_signature->{ $node->{_signature} }{game_info} //= [];
                push $self->data_for_signature->{ $node->{_signature} }{game_info}->@*,
                  $node->{_game_info};

                # FIXME make this a parameter. When combining games with
                # comments, the first few moves are usually waffle, not
                # actually useful comments.
                if ($node->{_move_number} > 3) {
                    if (defined(my $comment = $node->get('C'))) {
                        push $self->data_for_signature->{ $node->{_signature} }{comments}->@*, $comment
                          if length $comment;
                    }
                }

                # Count the number of times we've seen a move for a whole-board
                # position. Needed for pruning and adding state to nodes that
                # have variations as children.
                $self->data_for_signature->{ $node->{_signature} }{count}++;
            },
            on_taking_signature => sub ($assembler, $signature) {

                # For each child move, get the move and how often we've seen it.
                my $node          = $assembler->node_with_signature->{$signature};
                my $children_hash = $assembler->children_of->{$signature} // {};
                my @stats;
                for my $child_sig (keys $children_hash->%*) {
                    my $child_node = $assembler->node_with_signature->{$child_sig};
                    if (defined(my $child_move = $child_node->move)) {
                        push @stats,
                          { move  => $child_move,
                            sig   => $child_sig,
                            count => $self->data_for_signature->{$child_sig}{count}
                          };
                    }
                }

                # Here we can disconnect children with that occur too infrequently,
                # like below 0.02%. The on_taking_signature() handler is called
                # from GoGameTools::Assemble->_assemble_nodes. So if we delete
                # child moves from $assembler->children_of->{$signature} they will
                # not be assembled.
                if (defined(my $threshold = $self->prune)) {
                    my $total_count;
                    $total_count += $_->{count} for @stats;
                    $self->data_for_signature->{$signature}{count_pruned} = 0;
                    my $count_pruned = 0;
                    for my $stat (@stats) {
                        next if (100 * $stat->{count} / $total_count) >= $threshold;
                        delete $assembler->children_of->{$signature}{ $stat->{sig} };
                        $self->data_for_signature->{$signature}{count_pruned} += $stat->{count};
                        info(
                            sprintf 'pruned %s: %s -> %s',
                            games_pluralized($stat->{count}),
                            $signature, $stat->{move}
                        );
                    }
                }
                if ($signature ne $assembler->ROOT_SIG) {
                    $node->del('C');
                    if (defined(my $comments = $self->data_for_signature->{$signature}{comments})) {
                        $node->add(C => join "\n\n------\n\n", $comments->@*);
                    }
                }
            },
            on_sort_child_sigs => sub ($a, $b, $) {

                # We want to sort variations by their count. So if a variation
                # parent gets labels A, B, etc., the variations are sorted in that
                # order. $a and $b are signatures that will have the same parent,
                # i.e., they denote alternative moves. We can use the number of
                # game names stored for each signature as the count.
                #
                # If the count is equal, sort on the signatures themselves;
                # this is to ensure idempotency which is useful for tests.
                my ($na, $nb) =
                  map { $self->data_for_signature->{$_}{game_info}->$#* } ($a, $b);
                return ($nb <=> $na) || ($a cmp $b);
            },
        ),
        pipe_each(
            sub {
                $_->metadata->{filename} = $self->filename;
                my $game_info_node = $_->get_node(0);
                if (defined $self->title) {
                    $game_info_node->append_comment($self->title, "\n\n");
                }
                my @comments;

                # DT
                if (defined $self->date) {
                    push @comments, sprintf 'Date: %s', $self->date;
                    $game_info_node->add(DT => $self->date);
                }

                # AN
                if (defined $self->AN) {
                    $game_info_node->add(AN => $self->AN);
                    push @comments, sprintf 'Creator: %s', $self->AN;
                }

                # SO
                if (defined $self->SO) {
                    $game_info_node->add(SO => $self->SO);
                    push @comments, sprintf 'Website: %s', $self->SO;
                }
                $game_info_node->append_comment(join("\n" => @comments), "\n\n") if @comments;
            }
        ),
        pipe_traverse(
            sub ($node, $context) {

                # Annotated parent nodes of variations with statistics about how
                # often a move in a whole-board situation was seen while assembling
                # trees.
                #
                # Example stats:
                #
                #   { { move => 'pp', count => 3 },
                #     { move => 'dp', count => 2 } }
                #
                # Output:
                #
                #   Total: 5 games
                #   A: 3 games (60.00%)
                #   B: 2 games (40.00%)
                if ($self->should_add_stats) {
                    my $children_hash = $self->assembler->children_of->{ $node->{_signature} }
                      // {};
                    my @stats;
                    for my $child_sig (keys $children_hash->%*) {
                        my $child_node = $self->assembler->node_with_signature->{$child_sig};
                        if (defined(my $child_move = $child_node->move)) {
                            push @stats,
                              { move  => $child_move,
                                count => $self->data_for_signature->{$child_sig}{count}
                              };
                        }
                    }
                    if (@stats > 1) {
                        my $count_pruned =
                          $self->data_for_signature->{ $node->{_signature} }{count_pruned} // 0;
                        my $total_count = $count_pruned;
                        $total_count += $_->{count} for @stats;
                        my @comment_parts = 'Total: ' . games_pluralized($total_count);
                        my $label         = 'A';
                        for my $stat (sort { $b->{count} <=> $a->{count} } @stats) {
                            $node->add(LB => [ [ $stat->{move}, $label ] ]);
                            push @comment_parts,
                              sprintf '%s: %s (%.2f%%)',
                              $label,
                              games_pluralized($stat->{count}),
                              100 * $stat->{count} / $total_count;
                            $label++;
                        }
                        if ($count_pruned > 0) {
                            push @comment_parts, sprintf '%s < %s%% pruned',
                              games_pluralized($count_pruned), $self->prune;
                        }
                        $node->append_comment(join "\n", @comment_parts);
                    }
                }

                # For leaf nodes, show which games this position occurs in. With
                # sufficiently long game slices there will be only one game with
                # that position, but for shorter slices there may be several.
                #
                # If there are several games for the leaf node's position, add
                # HO[1] as a visual distinction. SGF editors like SmartGo and
                # Sabaki highlight such nodes in the tree view.
                if ($context->is_variation_end($node)) {
                    my @parts =
                      sort $self->data_for_signature->{ $node->{_signature} }{game_info}->@*;
                    $node->append_comment(join "\n", @parts) if $self->should_add_game_info;
                    $node->add(HO => 1) if @parts > 1;
                }
            }
        )
    );
}

sub normalize_tree_orientation ($tree) {
    normalize_tree_orientation_for_first_move($tree);

    # Now the first move is in the upper right quadrant.
    #
    # But while moves are on the diagonal that goes from the upper right to the
    # lower left we can go to the next move until we find a move that is not on
    # that diagonal. Then we can mirror the game along that diagonal to make
    # sure that move is below it, i.e., in the lower right part of the board.
    #
    # For example, if the first move is 4-4, then the second move could be in
    # the upper left corner or the lower right corner, but it's the same
    # whole-board position.
    my $i = 0;
    my $pos;
    $i++ while ($pos = pos_rel_to_UR_LL_diagonal($tree->get_node($i)->move)) == 0;

    # So now we know that the $i-th move (starting from 0) is the first move
    # not on the diagonal. If $i is 0, we are done. For larger $i, we can check
    # $pos to see whether we need to mirror the tree along the diagonal If $pos
    # is -1, the move is in the lower right triangle and we are done. If $pos
    # is 1, we need to mirror.
    if ($i > 0 && $pos == 1) {
        $tree->traverse(
            sub ($node, $) {
                $node->rotate_cw;
                $node->mirror_vertically;
            }
        );
    }
}

# Reorient a tree so that the first move is in the upper right quadrant;
# specifically in the "polite" triangle to the right of the diagonal.
sub normalize_tree_orientation_for_first_move ($tree) {

    # FIXME can these operations be combined beforehand to save traversals?
    # we only look at the first move to determine how to reorient the tree
    my ($x, $y) = split //, $tree->get_node(0)->move;
    unless (defined $x && defined $y) {
        use DDP;
        warn "Node 0 move problem";
        p $tree;
    }

    # make sure the first move is in the upper right quadrant
    if ($x =~ /[a-i]/) {

        # mirror the tree horizontally
        $tree->traverse(
            sub ($node, $) {
                $node->mirror_horizontally;
            }
        );
    }
    if ($y =~ /[k-s]/) {

        # mirror the tree vertically
        $tree->traverse(
            sub ($node, $) {
                $node->mirror_vertically;
            }
        );
    }

    # The coordinate might have changed; update the parts.
    ($x, $y) = split //, $tree->get_node(0)->move;

    # Now make sure the first move is in the right-half triangle of that
    # quadrant, i.e., the "polite" triangle.
    if (ord("s") - ord($x) > ord($y) - ord("a")) {

        # mirror the tree along the upper-right-to-lower-left diagonal
        $tree->traverse(
            sub ($node, $) {
                $node->rotate_cw;
                $node->mirror_vertically;
            }
        );
    }
}

sub games_pluralized ($n) {
    return sprintf "%s game%s", $n, ($n > 1 ? 's' : '');
}
1;
