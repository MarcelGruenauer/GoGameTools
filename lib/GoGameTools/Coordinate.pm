package GoGameTools::Coordinate;
use GoGameTools::features;
use GoGameTools;
use utf8;

# Concepts:
#
# Coordinates can take different forms:
# - "SGF coordinate": 'aa' to 'ss'
# - "alphanum coordinate": "A1 to T19"
# - "xy coordinate": (1,1) to (19,19)
#
# Functions expect the SGF coordinate, unless noted otherwise.
sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      coord_sgf_to_xy
      coord_sgf_to_alphanum
      coord_swap_axes
      coord_mirror_vertically
      coord_mirror_horizontally
      coord_shift_left
      coord_shift_right
      coord_shift_up
      coord_shift_down
      coord_neighbors
      coord_expand_rectangle);
}

# convert 'a'..'s' to 1..19; 'ab' becomes (1, 2)
sub coord_sgf_to_xy ($coord) {
    return (map { ord($_) - 96 } split //, $coord);
}

# convert a coordinate like 'dp' => 'D4'
sub coord_sgf_to_alphanum ($coord) {
    if ($coord =~ /([a-s])([a-s])/) {
        my $x = uc $1;
        $x++ if $x gt 'H';
        my $y = 116 - ord($2);
        return "$x$y";
    } else {
        die "can't convert coordinate '$coord'\n";
    }
}

sub coord_swap_axes ($coord) {
    $coord =~ s/^(.)(.)/$2$1/r;
}

sub coord_mirror_vertically ($coord) {
    substr($coord, 1, 1) =~ tr/a-s/srqponmlkjihgfedcba/;
    $coord;
}

sub coord_mirror_horizontally ($coord) {
    substr($coord, 0, 1) =~ tr/a-s/srqponmlkjihgfedcba/;
    $coord;
}

# the SGF letter that comes before a given letter
sub _before ($letter) {
    our %cache;
    $cache{before} //= do {
        my %n;
        @n{ 'b' .. 's' } = 'a' .. 'r';
        \%n;
    };
    return $cache{before}{$letter};
}

# the SGF letter that comes after a given letter
sub _after ($letter) {
    our %cache;
    $cache{after} //= do {
        my %n;
        @n{ 'a' .. 'r' } = 'b' .. 's';
        \%n;
    };
    return $cache{after}{$letter};
}

# Helper functions for moving positions around on the board
sub coord_shift_left ($coord) {
    my ($x, $y) = split //, $coord;
    my $new_x = _before($x);
    return unless defined $new_x;
    return "$new_x$y";
}

sub coord_shift_right ($coord) {
    my ($x, $y) = split //, $coord;
    my $new_x = _after($x);
    return unless defined $new_x;
    return "$new_x$y";
}

sub coord_shift_up ($coord) {
    my ($x, $y) = split //, $coord;
    my $new_y = _before($y);
    return unless defined $new_y;
    return "$x$new_y";
}

sub coord_shift_down ($coord) {
    my ($x, $y) = split //, $coord;
    my $new_y = _after($y);
    return unless defined $new_y;
    return "$x$new_y";
}

# Returns the coordinates of the four intersections (three at the side, two in
# the corner) adjacent to the given intersection.
# Cache neighbors; they're always the same for the same coordinates.
sub coord_neighbors ($coord) {
    our %cache;
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

sub coord_expand_rectangle ($value) {
    return $value if index($value, ':') == -1;
    my @result;
    my ($ul_x, $ul_y, undef, $lr_x, $lr_y) = split //, $value;
    for my $x ($ul_x .. $lr_x) {
        push @result, $x . $_ for $ul_y .. $lr_y;
    }
    return @result;
}
1;
