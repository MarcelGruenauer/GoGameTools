package GoGameTools::Board;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Class;
use GoGameTools::Util;
use charnames qw(:full);
our %cache;

# Returns the coordinates of the four intersections (three at the side, two in
# the corner) adjacent to the given intersection.
# Cache neighbors; they're always the same for the same coordinates.
sub neighbors ($self, $coord) {
    $cache{neighbors}{$coord} //= do {
        state sub n {
            return ['b'] if $_[0] eq 'a';
            return ['r'] if $_[0] eq 's';
            return [ chr(ord($_[0]) - 1), chr(ord($_[0]) + 1) ];
        }
        my ($x, $y) = split //, $coord;
        [ (map { "$_$y" } n($x)->@*), (map { "$x$_" } n($y)->@*) ];
    };
}

# returns an iterator - an anonymous sub - that, when called, returns the next
# neighbor going around the starting coordinate.
sub get_neighbor_iterator_for_coord ($self, $coord) {
    my @next_neighbors = ($coord);
    my %seen_neighbor = ($coord => 1);
    return sub {
        return unless @next_neighbors;
        my $next = shift @next_neighbors;
        push @next_neighbors,
          grep { !$seen_neighbor{$_}++ } $self->neighbors($next)->@*;
        return $next;
      }
}

sub stone_at_coord ($self, $coord) {
    return $self->{_board}{$coord} // EMPTY;
}

sub place_stone_at_coord ($self, $coord, $color) {
    $self->{_board}{$coord} = $color;
}

sub remove_stone_at_coord ($self, $coord) {
    delete $self->{_board}{$coord};
}

# Plays a stone of the specified color at coord, if that is a legal move
# (disregarding ko), and deletes stones captured by that move. Returns a true
# value if the move has been played, a false value if not.
sub play ($self, $coord, $color) {
    return if $self->stone_at_coord($coord) ne EMPTY;
    my $captures = $self->legal($coord, $color);
    return unless defined $captures;
    $self->remove_stone_at_coord($_) for $captures->@*;
    return 1;
}

# Check if a play by color at coord would be a legal move.
sub legal ($self, $coord, $color) {
    my $other_color = other_color($color);
    my @captured;
    for my $neighbor ($self->neighbors($coord)->@*) {

        # check each neighboring stone of the opposite color whether it is
        # captured
        if ($self->stone_at_coord($neighbor) eq $other_color) {
            push @captured => $self->group_without_liberties($neighbor, $coord);
        }
    }

    # make the list of captured stones unique (could contain duplicates)
    my %seen;
    @captured = grep { !$seen{$_}++ } @captured;

    # If the stone played captured something then it's legal; we place the
    # stone and return the list of captured stones.
    # Place the stone now so that the following call to
    # group_without_liberties() can see the stone.
    $self->place_stone_at_coord($coord, $color);
    return \@captured if @captured;

    # Check for suicide.
    #
    # If the stone played didn't capture anything and it doesn't have any
    # liberties, then it is not legal and we return an undef value.
    if (scalar $self->group_without_liberties($coord)) {
        $self->remove_stone_at_coord($coord);
    }

    # Otherwise the stone played didn't capture anything, but it has
    # liberties, so place the stone and return the empty list.
    return [];
}

# This function checks if the string (= solidly connected) of stones
# containing the stone at coord has a liberty; if exclude is given, it checks
# whether the stone has a liberty besides that at exclude. If no liberties are
# found, a list of all stones in the string is returned.
# The algorithm is a non-recursive implementation of a simple flood-filling:
# starting from the stone at pos, the main while-loop looks at the
# intersections directly adjacent to the stones found so far, for liberties or
# other stones that belong to the string. Then it looks at the neighbors of
# those newly found stones, and so on, until it finds a liberty, or until it
# doesn't find any new stones belonging to the string, which means that there
# are no liberties.
# Once a liberty is found, the function returns immediately.
sub group_without_liberties ($self, $coord, $exclude = undef) {

    # In the end, values(%group) will contain all stones solidly connected to
    # the one at coord, if this string has no liberties. Stored as a hash so
    # we avoid duplicates.
    my %group;

    # In the while loop, we will look at the neighbors of stones in
    # newly_found. Also stored as a hash to avoid duplicates.
    my %newly_found = ($coord => $coord);
    my $found_new = 1;
    while ($found_new) {
        $found_new = 0;
        my %iter_found;    # will contain the stones found in this iteration
        for my $coord (values %newly_found) {
            my $self_stone;
            for my $neighbor ($self->neighbors($coord)->@*) {
                my $neighbor_stone = $self->stone_at_coord($neighbor);
                if ($neighbor_stone ne EMPTY) {

                    # Calculate $self_stone only once, but only if it's
                    # necessary.
                    if (   $neighbor_stone eq ($self_stone //= $self->stone_at_coord($coord))
                        && !exists($group{$neighbor})
                        && !exists($newly_found{$neighbor})) {

                        # found another stone of the same color
                        $iter_found{$neighbor} = $neighbor;
                        $found_new = 1;
                    }
                } else {

                    # This neighbor is empty, i.e. we found a liberty. Return
                    # the empty list if this liberty is not the excluded one,
                    # or if there is no excluded liberty.
                    return () unless defined $exclude;
                    return () if $neighbor ne $exclude;
                }
            }
        }
        %group = (%group, %newly_found);
        %newly_found = %iter_found;
    }

    # No liberties found, return list of all stones connected to the original
    # one.
    return values %group;
}

# The user should make sure there is no AW[] and AB[] on the node already.
sub setup_on_node ($self, $node) {
    my (@aw, @ab);
    while (my ($coord, $stone) = each $self->{_board}->%*) {
        if ($stone eq BLACK) {
            push @ab, $coord;
        } elsif ($stone eq WHITE) {
            push @aw, $coord;
        }
    }
    $node->add(AW => \@aw);
    $node->add(AB => \@ab);
}

sub _data_printer ($self, $properties = {}) {
    my $s = "\n";
    my $hline .= "\N{BOX DRAWINGS LIGHT HORIZONTAL}";
    my $size = 19;
    for my $y (1 .. $size) {
        for my $x (1 .. $size) {
            my $stone = $self->stone_at_coord(chr(96 + $x) . chr(96 + $y));
            if ($stone eq EMPTY) {
                if ($x == 1) {
                    if ($y == 1) {
                        $s .= "\N{BOX DRAWINGS LIGHT DOWN AND RIGHT}$hline";
                    } elsif ($y == $size) {
                        $s .= "\N{BOX DRAWINGS LIGHT UP AND RIGHT}$hline";
                    } else {
                        $s .= "\N{BOX DRAWINGS LIGHT VERTICAL AND RIGHT}$hline";
                    }
                } elsif ($x == $size) {
                    if ($y == 1) {
                        $s .= "\N{BOX DRAWINGS LIGHT DOWN AND LEFT}";
                    } elsif ($y == $size) {
                        $s .= "\N{BOX DRAWINGS LIGHT UP AND LEFT}";
                    } else {
                        $s .= "\N{BOX DRAWINGS LIGHT VERTICAL AND LEFT}";
                    }
                } elsif ($y == 1) {
                    $s .= "\N{BOX DRAWINGS LIGHT DOWN AND HORIZONTAL}$hline";
                } elsif ($y == $size) {
                    $s .= "\N{BOX DRAWINGS LIGHT UP AND HORIZONTAL}$hline"

                      # } elsif ($x ~~ [ 4, 10, 16 ] && $y ~~ [ 4, 10, 16 ]) {
                      #     $s .= "\N{BOX DRAWINGS HEAVY VERTICAL AND HORIZONTAL}$hline"
                } else {
                    $s .= "\N{BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL}$hline";
                }
            } elsif ($stone eq BLACK) {
                $s .= "\N{LARGE CIRCLE} ";
            } elsif ($stone eq WHITE) {
                $s .= "\N{BLACK LARGE CIRCLE} ";
            } else {
                $s .= '? ';
            }
        }
        $s .= "\n";
    }
    return $s;
}

sub play_node ($self, $node) {
    for my $color (BLACK, WHITE) {

        # only expect a single property value; B[ab][cd] doesn't make sense
        if (my $sgf_coord = $node->get($color)) {
            $self->play($sgf_coord, $color);

            # Assume there's only either B[] or W[], and if so, there are no
            # AB[] and AW[].
            return;
        }
    }
    $self->place_stone_at_coord($_, BLACK) for $node->get('AB')->@*;
    $self->place_stone_at_coord($_, WHITE) for $node->get('AW')->@*;
    $self->remove_stone_at_coord($_) for $node->get('AE')->@*;
}

sub clone ($self) {
    my $clone = GoGameTools::Board->new;
    $clone->{_board}->%* = $self->{_board}->%* if defined $self->{_board};
    return $clone;
}
1;

=pod

=head1 NAME

GoGameTools::Board - represents a Go board and the stones currently on it

