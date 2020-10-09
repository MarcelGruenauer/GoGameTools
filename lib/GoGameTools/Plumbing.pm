package GoGameTools::Plumbing;
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Assemble;
use GoGameTools::Porcelain::GenerateProblems;
use GoGameTools::Util;
use GoGameTools::Color;
use GoGameTools::Coordinate;
use GoGameTools::Log;
use GoGameTools::Munge;
use GoGameTools::Color;
use GoGameTools::JSON;
use Path::Tiny;
use File::Spec;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      run_pipe
      pipe_parse_sgf_from_file_list
      pipe_write
      pipe_decode_json_from_stdin
      pipe_encode_json_to_stdout
      pipe_sgj_to_trees
      pipe_trees_to_sgj
      pipe_reorient
      pipe_assemble
      pipe_convert_markup_to_directives
      pipe_convert_directives_from_comment
      pipe_gen_problems
      pipe_each
      pipe_traverse
      pipe_extract_main_line
      pipe_flex_stdin_to_trees
      pipe_cat_map
    );
}

sub run_pipe (@pipe_segments) {

    # Recognize an optional final arrayref that is the initial argument passed
    # to the first pipe. So you can call this like:
    #
    #     run_pipe(@segments, [ $init_collection ])
    my @result;
    if (ref $pipe_segments[-1] eq ref []) {
        my $init = pop @pipe_segments;
        @result = $init->@*;
    }
    for my $pipe (@pipe_segments) {
        @result = $pipe->(@result);
    }
    return @result;
}

# Takes a list of filenames that contain SGF collections. Returns a
# GoGameTools::Tree collection
sub pipe_parse_sgf_from_file_list (%args) {
    $args{strict} //= 1;
    $args{utf8} //= 1;
    return sub {
        my @collection;
        for my $file ($args{files}->@*) {
            my $sgf = slurp($file, $args{utf8});
            my $this_collection =
              parse_sgf($sgf, { name => $file, strict => $args{strict} });
            fatal("can't parse $file") unless defined $this_collection;
            while (my ($index, $tree) = each $this_collection->@*) {
                $tree->metadata->{input_filename} = $file;
                $tree->metadata->{filename}       = absolute_path($file);
                $tree->metadata->{index}          = $index;
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
            my ($x, $y) = coord_sgf_to_xy($setup_coord);
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

            # convert hashtags
            if (my $comment = $node->get('C')) {
                my @tags;
                while ($comment =~ s/\s*#([\w:]+)\s*/ /) { push @tags, $1 }
                if (@tags) {
                    $node->add(C => "{{ tags @tags }}\n$comment");
                }
            }

            # a circle on the node’s move => {{ guide }}
            my $move    = $node->move;
            my @circles = $node->get('CR')->@*;
            if (defined($move) && grep { $_ eq $move } @circles) {
                $node->directives->{guide} = 1;
                $node->del('CR');
            }
            my %property_map = (
                HO => 'barrier',
                BM => 'bad_move',
                TE => 'good_move',
                DM => 'correct_for_both',
                GB => 'correct',
                GW => 'correct',
            );
            while (my ($property, $directive) = each %property_map) {
                if ($node->has($property)) {
                    $node->directives->{$directive} = 1;
                    $node->del($property);
                }
            }
        }
    );
}

sub pipe_convert_directives_from_comment {
    pipe_traverse(
        sub ($node, $args) {
            eval { $node->convert_directives_from_comment };
            if ($@) { fatal($::tree->with_location($@)); }
        }
    );
}

sub pipe_gen_problems (%args) {
    return sub ($collection) {
        return [
            map {
                GoGameTools::Porcelain::GenerateProblems::Runner->new(%args, source_tree => $_)
                  ->run->get_generated_trees
            } $collection->@*
        ];
    }
}

sub pipe_each ($on_tree) {
    return sub ($collection) {
        my @result;
        for my $tree ($collection->@*) {

            # shortcuts to variables that are often used in the eval'd code
            local $_ = $tree;
            no warnings 'once';
            local $::g = $tree->get_node(0);
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
                sub ($node, $context) {

                    # helpers that make it easier to write traversal handlers
                    local $_ = $node;
                    no warnings 'once';
                    local $::tree    = $tree;
                    local $::context = $context;
                    my sub is_var_end { $context->is_variation_end($_) }
                    my sub tree_path  { $context->get_tree_path_for_node($_) }

                    # append_C(), add_tag() and add_directive() are very
                    # similar but have different names to distinguish semantics
                    my sub append_C      { $_->append_comment($_[0],         "\n") }
                    my sub add_tag       { $_->append_comment('#' . $_[0],   "\n") }
                    my sub add_directive { $_->append_comment("{{ $_[0] }}", "\n") }
                    my $rc = ref $on_node eq ref sub { }
                      ? $on_node->($node, $context) : eval($on_node);
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
sub pipe_flex_stdin_to_trees (%args) {
    return sub {
        chomp(my @stdin = <STDIN>);
        my $result;
        eval {
            my $json = join "\n", @stdin;
            my $sgj  = json_decode($json);
            $result = pipe_sgj_to_trees->($sgj);
        };
        return $result unless $@;
        return pipe_parse_sgf_from_file_list(files => \@stdin, %args)->();
    };
}

# Convenience wrapper for pipe segments; takes a list of files and parses them,
# then outputs SGJ.
#
# The name indicates that it's like gogame-cat but with a map() function.
sub pipe_cat_map (@pipe) {
    return run_pipe(pipe_flex_stdin_to_trees(),
        @pipe, pipe_trees_to_sgj(), pipe_encode_json_to_stdout());
}
1;
