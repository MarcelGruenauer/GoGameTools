package GoGameTools::Plumbing;
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Assemble;
use GoGameTools::GenerateProblems;
use GoGameTools::Util;
use GoGameTools::Color;
use GoGameTools::Log;
use GoGameTools::Munge;
use GoGameTools::Color;
use GoGameTools::JSON;
use File::Spec;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      run_pipe
      pipe_decode_json_from_file_list
      pipe_write
      pipe_decode_json_from_stdin
      pipe_encode_json_to_stdout
      pipe_sgj_to_trees
      pipe_trees_to_sgj
      pipe_reorient
      pipe_assemble
      pipe_convert_markup_to_directives
      pipe_annotate
      pipe_gen_problems
      pipe_each
      pipe_traverse
      pipe_extract_main_line
      pipe_flex_stdin_to_trees
      pipe_cat_map
      abort_pipe
    );
}

sub run_pipe (@pipe_segments) {
    my @result;
    our $abort_pipe = 0;
    for my $pipe (@pipe_segments) {
        @result = $pipe->(@result);
        return if $abort_pipe;
    }
    return @result;
}

sub abort_pipe {
    our $abort_pipe = 1;
}

# given a list of filenames, returns a GoGameTools::Tree collection
sub pipe_decode_json_from_file_list (%args) {
    return sub {
        my @collection;
        for my $file ($args{files}->@*) {
            my $sgf             = slurp($file);
            my $this_collection = parse_sgf($sgf);
            fatal("can't parse $file") unless defined $this_collection;
            while (my ($index, $tree) = each $this_collection->@*) {
                $tree->metadata->{filename} = File::Spec->rel2abs($file);
                $tree->metadata->{index}    = $index;
                push @collection, $tree;
            }
        }
        return \@collection;
    };
}

# Takes an SGJ collection. For each element, writes its SGF to its metadata's
# filename. Makes sure the directories exists.
#
# This pipe doesn't modify the collection; it just has writes it to files as a
# side-effect, then passes it on.
sub pipe_write {
    return sub ($collection) {

        # In the loop, merge sgf for trees with the same filename. Then write
        # the SGF collections.
        my %sgf_collections;
        for my $tree ($collection->@*) {
            push $sgf_collections{ $tree->metadata->{filename} }->@*, $tree->as_sgf;
        }
        while (my ($filename, $sgfs) = each %sgf_collections) {
            spew($filename, join("\n", $sgfs->@*));
        }
        return $collection;    # so it can be chained
    }
}

# Takes JSON on STDIN and returns an SGJ collection
sub pipe_decode_json_from_stdin {
    return sub {
        my $json = do { local $/; <STDIN> };
        return json_decode($json);
    };
}

# Takes an SGJ collection and prints JSON on STDOUT
sub pipe_encode_json_to_stdout {
    return sub ($collection) {
        say json_encode($collection);

        # return the collection so this pipe segment can be used in the middle
        # of a pipe to show the current state of the collection
        return $collection;
    };
}

# Takes an SGJ collection and returns a GoGameTools::Tree collection
sub pipe_sgj_to_trees {
    return sub ($collection) {
        my @result;
        for my $sgj_obj ($collection->@*) {
            my $parsed = parse_sgf($sgj_obj->{sgf});
            fatal("can't parse sgf\n$sgj_obj->{sgf}") unless defined $parsed;
            my $tree = $parsed->[0];
            $tree->metadata->%* = $sgj_obj->{metadata}->%*;
            push @result, $tree;
        }
        return \@result;
    };
}

# Takes a GoGameTools::Tree collection and returns an SGJ collection
sub pipe_trees_to_sgj {
    return sub ($collection) {
        return [
            map {
                +{  metadata  => $_->metadata,
                    game_info => $_->game_info,
                    sgf       => $_->as_sgf,
                };
            } $collection->@*
        ];
    };
}

sub pipe_reorient (%spec) {

    # Full-board problems don't get their colors swapped. A full-board problem is
    # one where the setup (AW, AB) in the game info node has a width and height of
    # 12 or more each. That way, three corner hoshi stones already qualify as a
    # full-board problem.
    state sub is_full_board_setup ($tree) {
        my ($x_min, $x_max, $y_min, $y_max) = (10, 10, 10, 10);
        my @setup_coord = map { $tree->get_node(0)->get($_)->@* } qw(AW AB);
        for my $setup_coord (@setup_coord) {

            # coordinates are "aa" for (1, 1) to "ss" for (19, 19)
            my ($x, $y) = map { ord($_) - 96 } split //, $setup_coord;
            $x_min = $x if $x < $x_min;
            $x_max = $x if $x > $x_max;
            $y_min = $y if $y < $y_min;
            $y_max = $y if $y > $y_max;
        }
        return $x_max - $x_min >= 12 && $y_max - $y_min >= 12;
    }
    $spec{$_} //= 0 for qw(
      swap_axes mirror_vertically mirror_horizontally swap_colors
      transpose_to_opponent_view random
    );
    return sub ($collection) {
        for my $tree ($collection->@*) {
            if ($spec{random}) {

                # gen settings once per tree; same for each node in that tree
                $spec{swap_axes}           = int rand 2;
                $spec{mirror_vertically}   = int rand 2;
                $spec{mirror_horizontally} = int rand 2;
                $spec{swap_colors}         = is_full_board_setup($tree) ? 0 : int rand 2;
            }
            $tree->traverse(
                sub ($node, $) {
                    $node->swap_axes                  if $spec{swap_axes};
                    $node->mirror_vertically          if $spec{mirror_vertically};
                    $node->mirror_horizontally        if $spec{mirror_horizontally};
                    $node->swap_colors                if $spec{swap_colors};
                    $node->transpose_to_opponent_view if $spec{transpose_to_opponent_view};
                }
            );
        }
        return $collection;
    };
}

sub pipe_assemble (%args) {
    return sub ($collection) {
        my $asm = GoGameTools::Assemble->new(%args);
        $asm->add($_) for $collection->@*;

        # Return the tree in an arrayref so it can be piped to other filters
        # that expect a collection.
        return [ $asm->tree ];
    };
}

sub pipe_convert_markup_to_directives {
    pipe_traverse(
        sub ($node, $args) {
            track_board_in_traversal_for_node($node, $args);

            # convert hashtags
            if (my $comment = $node->get('C')) {
                my @tags;
                while ($comment =~ s/\s*#([\w:]+)\s*/ /) { push @tags, $1 }
                if (@tags) {
                    $node->add(C => "{{ tags @tags }}\n$comment");
                }
            }

            # convert markup that should be supppoerd by all SGF editors
            my $move       = $node->move;
            my $move_color = $node->move_color;
            my $other_color;
            $other_color = other_color($move_color) if defined $move_color;
            my @squares = $node->get('SQ')->@*;
            my @circles = $node->get('CR')->@*;
            my @marks   = $node->get('MA')->@*;
            my sub is_color ($coord, $color) {
                $node->{_board}->stone_at_coord($coord) eq $color;
            }

            # CROSSES (MA[])
            #
            # a cross on the node’s move => {{ bad_move }}
            if (defined($move) && grep { $_ eq $move } @marks) {
                $node->append_comment('{{ bad_move }}');
                $node->del('MA');
            }

            # a single cross on an empty intersection => {{ barrier }},
            my @marks_on_empty = grep { is_color($_, EMPTY) } @marks;
            if (1 == @marks_on_empty) {
                $node->append_comment('{{ barrier }}');
                $node->del('MA');
            }

            # SQUARES (SQ[])
            #
            # a square on the node’s move => {{ good_move }}
            if (defined($move) && grep { $_ eq $move } @squares) {
                $node->append_comment('{{ good_move }}');
                $node->del('SQ');
            }

            # a single square on an empty intersection => {{ correct }},
            # but if there is also a square on an opponent stone, it's
            # {{ correct_for_both }} instead.
            my @squares_on_empty = grep { is_color($_, EMPTY) } @squares;
            if (1 == @squares_on_empty) {
                if (1 == grep { is_color($_, $other_color) } @squares) {
                    $node->append_comment('{{ correct_for_both }}');
                } else {
                    $node->append_comment('{{ correct }}');
                }
                $node->del('SQ');
            }

            # two squares on empty intersections => {{ assemble }}
            if (2 == @squares_on_empty) {
                $node->append_comment('{{ assemble }}');
                $node->del('SQ');
            }

            # CIRCLES (CR[])
            #
            # Requirement: {{ has_all_good_responses }} and {{ guide }} can
            # occur in the same node.
            #
            # a circle on the node’s move => {{ guide }}
            if (defined($move) && grep { $_ eq $move } @circles) {
                $node->append_comment('{{ guide }}');
                $node->del('CR');
            }

            # circles on two empty intersections => {{ has_all_good_responses }}
            my @circles_on_empty = grep { is_color($_, EMPTY) } @circles;
            if (1 == @circles_on_empty) {
                warning($node->{_board}->_data_printer);
                fatal(
                    $::tree->with_location(
                        'illegal markup: found a single CR[] on an empty intersection')
                );
            }
            if (2 == @circles_on_empty) {
                $node->append_comment("{{ has_all_good_responses }}");
                $node->del('CR');
            }

            # HO[] acts as a barrier
            if ($node->has('HO')) {
                $node->append_comment('{{ barrier }}');
                $node->del('HO');
            }

            # BM[] also becomes {{ bad_move }}
            if ($node->has('BM')) {
                $node->append_comment('{{ bad_move }}');
                $node->del('BM');
            }

            # TE[] also becomes {{ good_move }}
            if ($node->has('TE')) {
                $node->append_comment('{{ good_move }}');
                $node->del('TE');
            }
        }
    );
}

# Read the annotations file. Each tree in the collection has its filename and
# index in the metadata. For each tree, process all annotations for this tree.
#
# Tree paths:
#
# 'a-b-c' means 'at move "a", choose variation "b", then go to move "c". #
# Because of how the tree is represented in GoGameTools::Tree, getting to the
# final node is rather straightforward. Examples: '1-2-0' becomes
# $tree->[3][0]. '4-1-3-1-5' becomes $tree->[5][4][0]
#
# The base starts at the root of the tree. While the remaining tree path starts
# with '<number>-<number>-', go to that point in the node/variation array,
# which then becomes the new base. In the end, there is only one number in the
# tree path left, and that's the wanted node's array index.
#
# For example, int he above '4-1-3-1-5', we first get '4-1-' and go to
# $tree->[5]. Then we get '3-1-' and go to $tree->[5][4]. Then we get '0' and
# finally reach $tree->[5][4][0].
#
# Both tree paths and array indices are zero-based.
sub pipe_annotate ($annotations_file) {
    my @lines       = split /\n/, slurp($annotations_file);
    my $annotations = parse_annotations(\@lines);
    return sub ($collection) {
        for my $tree ($collection->@*) {
            my ($filename, $index) = $tree->metadata->@{qw(filename index)};
            for my $spec ($annotations->{$filename}{$index}->@*) {
                my ($tree_path, $annotation) = $spec->@*;
                my $node = $tree->get_node_for_tree_path($tree_path);
                unless (defined $node) {

                    # maybe the tree changed since the annotation list was created
                    fatal(
                        $tree->with_location("cannot annotate: no node with tree path $tree_path"));
                }
                my $type = substr($annotation, 0, 1, '');
                if ($type eq '#') {
                    $node->add_tags($annotation);
                } elsif ($type eq '@') {
                    push $node->refs->@*, $annotation;
                } else {
                    die "unknown annotation [$annotation]";
                }
            }
        }
        return $collection;
    };
}

sub pipe_gen_problems (%args) {
    return sub ($collection) {
        return [
            map {
                GoGameTools::GenerateProblems->new(%args, source_tree => $_)
                  ->run->get_generated_trees
            } $collection->@*
        ];
    };
}

sub pipe_each ($on_tree) {
    return sub ($collection) {
        my @result;
        for my $tree ($collection->@*) {
            local $_ = $tree;    # the eval'd code can use $_
            my $new_tree = ref $on_tree eq ref sub { }
              ? $on_tree->($_) : eval($on_tree);
            fatal("eval error: $@") if $@;
            $new_tree = $tree unless ref $new_tree eq ref $tree;
            push @result, $new_tree;
        }
        return \@result;
    };
}

sub pipe_traverse ($on_node) {
    return sub ($collection) {
        for my $tree ($collection->@*) {
            $tree->traverse(
                sub ($node, $args) {
                    local $_ = $node;    # the eval'd code can use $_
                    no warnings 'once';
                    local $::tree = $tree;
                    my $rc = ref $on_node eq ref sub { }
                      ? $on_node->($node, $args) : eval($on_node);
                    fatal("eval error: $@") if $@;
                    return $rc;
                }
            );
        }
        return $collection;
    };
}

sub pipe_extract_main_line {
    my sub extract_main_line ($self) {
        my $result = [];

        sub ($tree) {
            for ($tree->@*) {
                if (ref eq ref []) {
                    return __SUB__->($_);    # return after first variation
                } else {
                    push $result->@*, $_;
                }
            }
          }
          ->($self->tree);
        return GoGameTools::Tree->new(tree => $result, metadata => $self->metadata);
    }
    return sub ($collection) {
        return [ map { extract_main_line($_) } $collection->@* ];
    };
}

# Interpret STDIN either as SGJ or - if decoding JSON doesn't work - as a list
# of filenames from which to read the JSON.
sub pipe_flex_stdin_to_trees {
    return sub {
        chomp(my @stdin = <STDIN>);
        my $result;
        eval {
            my $json = join "\n", @stdin;
            my $sgj  = json_decode($json);
            $result = pipe_sgj_to_trees->($sgj);
        };
        return $result unless $@;
        return pipe_decode_json_from_file_list(files => \@stdin)->();
    };
}

# Convenience wrapper for pipe segments; takes a list of files and parses them,
# then outputs SGJ.
#
# The name indicates that it's like gogame-cat but wiht a map() function.
sub pipe_cat_map (@pipe) {
    return run_pipe(pipe_flex_stdin_to_trees(),
        @pipe, pipe_trees_to_sgj(), pipe_encode_json_to_stdout());
}
1;
