package GoGameTools::Node;
use GoGameTools::features;
use GoGameTools::Board;
use GoGameTools::Tag;
use GoGameTools::TagHandler;
use GoGameTools::Log;
use GoGameTools::Class qw(%directives @tags @refs);

sub new {
    my $class = shift;
    bless { properties => {}, directives => {}, tags => [], refs => [] }, $class;
}

sub add_tags {
    my $self = shift;
    push $self->tags->@*,
      map { ref() eq 'GoGameTools::Tag' ? $_ : GoGameTools::Tag->new_from_spec($_) }
      @_;
}

# SECTION: property manipulation methods
our %has_array_value =
  map { $_ => 1 } qw(AB AW AE TB TW TR SQ MA CR SL LB LN AR DD VW);

sub add ($self, $property_name, $property_value) {
    if ($has_array_value{$property_name}) {
        push $self->{properties}{$property_name}->@*, $property_value->@*;
    } else {
        $self->{properties}{$property_name} = $property_value;
    }
    return $self;    # for chaining and for the parser grammar's use of $^R
}

sub del {
    my $self = shift;
    delete $self->{properties}->@{@_};
}

# args: ($self, $property_name)
sub get {
    if ($has_array_value{ $_[1] }) {
        return $_[0]->{properties}{ $_[1] } //= [];
    } else {
        return $_[0]->{properties}{ $_[1] };
    }
}

# args: ($self, $property_name)
sub has {
    return exists $_[0]->{properties}{ $_[1] };
}

# If the node has a given property, remove it and return a true value. Useful
# if you want to change one property to another, if it exists, like
#
# $_->add(BM => 1) if $_->had("TR")
sub had ($self, $property_name) {
    return unless $self->has($property_name);
    $self->del($property_name);
    return 1;
}

sub append_comment ($self, $new_comment) {
    $self->_join_comments($self->get('C'), $new_comment);
}

sub prepend_comment ($self, $new_comment) {
    $self->_join_comments($new_comment, $self->get('C'));
}

sub _join_comments ($self, @parts) {
    $self->add(C => join "\n\n", map { chomp; $_ } grep { defined } @parts);
}

sub expand_rectangles ($self, $values) {
    my @result;
    for my $v ($values->@*) {
        if (index($v, ':') == -1) {
            push @result, $v;
        } else {
            my ($ul_x, $ul_y, undef, $lr_x, $lr_y) = split //, $v;
            for my $x ($ul_x .. $lr_x) {
                push @result, $x . $_ for $ul_y .. $lr_y;
            }
        }
    }
    return \@result;
}

# SECTION: move-related methods
sub move {
    my $move = $_[0]->{properties}{B} // $_[0]->{properties}{W};
    return $move unless defined $move;
    # normalize 'tt' to a pass
    return $move eq 'tt' ? '' : $move;
}

sub move_color {
    return 'B' if exists $_[0]->{properties}{B};
    return 'W' if exists $_[0]->{properties}{W};
    return;
}

sub _reorient ($self, $code) {

    # scalar properties
    for my $property (qw(W B)) {
        next unless $self->has($property);
        $self->add($property, $code->($self->get($property)));
    }

    # array properties with scalar string values
    for my $property (qw(AW AB TR SQ MA CR TW TB SL)) {
        next unless $self->has($property);
        my @values = $self->get($property)->@*;
        $self->del($property);
        $self->add($property, [ map { $code->($_) } @values ]);
    }

    # array properties with composite values
    # LB has [ point, string ]
    # LN, AR have [ point, point ]
    if ($self->has('LB')) {
        my @values = $self->get('LB')->@*;
        $self->del('LB');
        $self->add('LB', [ map { [ $code->($_->[0]), $_->[1] ] } @values ]);
    }
    for my $property (qw(LN AR)) {
        next unless $self->has($property);
        my @values = $self->get($property)->@*;
        $self->del($property);
        $self->add($property,
            [ map { [ $code->($_->[0]), $code->($_->[1]) ] } @values ]);
    }
}

sub _swap_comment ($self, %replace) {
    return unless defined $self->{properties}{C};
    my @from = keys %replace;
    local $" = '|';
    $self->{properties}{C} =~ s/(@from)/$replace{$1}/ge;
}

sub swap_axes ($self) {

    # swap the two characers for x and y axes
    $self->_reorient(sub { $_[0] =~ s/^(.)(.)/$2$1/r });
    $self->_swap_comment(
        'upper right corner' => 'lower left corner',
        'lower left corner'  => 'upper right corner',
        'left side'          => 'upper side',
        'right side'         => 'lower side',
        'upper side'         => 'left side',
        'lower side'         => 'right side',
    );
}

sub mirror_vertically ($self) {
    $self->_reorient(
        sub ($s) { substr($s, 1, 1) =~ tr/a-s/srqponmlkjihgfedcba/; $s });
    $self->_swap_comment(
        'upper left corner'  => 'lower left corner',
        'upper right corner' => 'lower right corner',
        'lower left corner'  => 'upper left corner',
        'lower right corner' => 'upper right corner',
        'upper side'         => 'lower side',
        'lower side'         => 'upper side',
    );
}

sub mirror_horizontally ($self) {
    $self->_reorient(
        sub ($s) { substr($s, 0, 1) =~ tr/a-s/srqponmlkjihgfedcba/; $s });
    $self->_swap_comment(
        'upper left corner'  => 'upper right corner',
        'upper right corner' => 'upper left corner',
        'lower left corner'  => 'lower right corner',
        'lower right corner' => 'lower left corner',
        'left side'          => 'right side',
        'right side'         => 'left side',
    );
}

sub rotate_cw ($self) {
    $self->mirror_vertically;
    $self->swap_axes;
}

sub rotate_ccw ($self) {
    $self->mirror_horizontally;
    $self->swap_axes;
}

sub transpose_to_opponent_view ($self) {
    $self->rotate_cw;
    $self->rotate_cw;
}

sub swap_colors ($self) {
    my $p = $self->{properties};
    my sub swap ($l, $r) {
        ($p->{$l}, $p->{$r}) = ($p->{$r}, $p->{$l});
    }
    swap(qw(B W));
    swap(qw(AB AW));
    swap(qw(WT BT));
    swap(qw(GB GW));
    swap(qw(OB OW));
    swap(qw(BL WL));
    swap(qw(TB TW));

    if (defined $p->{PL}) {
        $p->{PL} =~ tr/BW/WB/;
    }
    $self->_swap_comment(
        'black' => 'white',
        'white' => 'black',
        'Black' => 'White',
        'White' => 'Black',
    );
}

# Create a clone of a node that has some keys removed because when
# adding it to a different tree, these values won't be the same anyway.
# It's called a 'public clone' because all the internal properties, starting
# with an underscore, are not copied. If the caller needs any of those, he has
# to copy them manually. That's because these internal properties vary by
# usage.
sub public_clone ($self) {
    my $clone = GoGameTools::Node->new;
    my %cloned_properties;
    while (my ($k, $v) = each $self->{properties}->%*) {
        $cloned_properties{$k} = $has_array_value{$k} ? [ $v->@* ] : $v;
    }
    $clone->{properties}   = \%cloned_properties;
    $clone->directives->%* = $self->directives->%*;
    $clone->tags->@*       = $self->tags->@*;
    $clone->refs->@*       = $self->refs->@*;
    return $clone;
}

# SECTION: output methods
sub as_sgf ($self) {
    my $result     = '';
    my %properties = $self->{properties}->%*;
    local $" = '][';

    # impose order on properties and values so it's easy to compare trees
    for my $k (sort keys %properties) {
        my $value = $properties{$k};
        next unless defined $value;

        # handle properties with scalar values as well as array values
        my @p;
        if (ref $value eq ref []) {

            # Also join composite values. E.g., for LB: [ 'ab', '!' ] ==> LB[ab:!]
            @p = sort map { ref() eq 'ARRAY' ? join(':', @$_) : $_ } $properties{$k}->@*;

            # Don't output empty values; Glift chokes on them.
            next if @p == 0;
        } else {
            @p = $value;
        }

        # SGFGrove.js wants FF[] and GM[] first to be able to determine
        # available properties so prepend those and append others.
        if ($k eq 'FF' || $k eq 'GM') {
            $result = "$k\[@p\]" . $result;
        } else {
            $result .= "$k\[@p\]";
        }
    }
    return $result;
}

# SECTION: problem-specific methods
#
# A node is a barrier for color C if it meets at least one condition:
#
# 1. it does not have B[] or W[], so it's an empty node or contains AW[] or AB[]
#
# 2. it has a move of color C and is marked as a "bad move"
#
# Note that condition 1 means that the root node is automatically considered a
# barrier node as well.
sub extract_directives ($self, $input) {
    my (%directives, %is_valid_directive);
    require GoGameTools::GenerateProblems::PluginLoader;
    my sub is_valid_directive ($directive) {
        return $is_valid_directive{$directive} //=
          grep { $_->handles_directive($directive) }
          GoGameTools::GenerateProblems::PluginLoader->plugins;
    }
    my (@tags, @refs);
    while (
        $input =~ s/
        \{\{ \s*
        (?<Directive> [\w_]+)
        \s+
        (?<Content> .*?)
        \s* }}
        //sox
    ) {
        my ($directive, $content) = ($+{Directive}, $+{Content});
        unless (is_valid_directive($directive)) {
            fatal("invalid directive {{ $directive }}");
        }
        if (exists $directives{$directive}) {
            fatal("directive {{ $directive }} defined more than once in the same node");
        }
        if ($directive eq 'tags') {
            @tags = split /\s+/, $content;
            validate_tag($_) for @tags;
        } elsif ($directive eq 'ref') {

            # this directive can occur several times; each contains one ref
            push @refs, $content;
        } else {
            $content = 1 unless length $content;
            $directives{$directive} = $content;
        }
    }
    $input =~ s/^\s+|\s+$//gs;    # trim
    return +{
        directives => \%directives,
        tags       => \@tags,
        refs       => \@refs,
        remainder  => $input
    };
}

# convert directives like '{{ answer ... }}' in comments to properties
sub convert_directives_from_comment ($self) {
    my $comment = $self->get('C');
    return unless defined $comment;
    my $extracted = $self->extract_directives($comment);
    $self->tags->@* = ();
    $self->add_tags($extracted->{tags}->@*);
    $self->refs->@*       = $extracted->{refs}->@*;
    $self->directives->%* = $extracted->{directives}->%*;
    if (length $extracted->{remainder}) {
        $self->add(C => $extracted->{remainder});
    } else {
        $self->del('C');
    }
}

sub get_scalar_properties_as_hash ($self) {
    my %prop;
    while (my ($k, $v) = each $self->{properties}->%*) {
        next if $has_array_value{$k};
        next unless defined $v;
        $prop{$k} = $v;
    }
    return \%prop;
}

# When you want to print a message but want to report its location in a list of
# trees, use this method to add relevant metadata.
sub with_location ($self, $message) {
    1 while chomp $message;
    $message .= "\n    " . $self->as_sgf;
    return $message;
}
1;
