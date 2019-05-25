package GoGameTools::Tag;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Class qw(new $name %_flags);
use GoGameTools::Log;
my %is_valid_flag = map { $_ => 1 } qw(a b w);

sub new_from_spec ($class, $spec) {
    unless ($spec =~ /^(\w+)(?::(\w+))?$/o) {
        fatal("invalid tag spec [$spec]");
    }
    my ($name, $flags) = ($1, $2);
    my $self = $class->new(name => $name);
    if (length $flags) {
        $self->set_flag($_) for split //, $flags;
    }
    return $self;
}

sub as_spec ($self) {
    my $spec = $self->name;
    if (my @flags = $self->get_flags) {
        $spec .= ':' . join('', @flags);
    }
    return $spec;
}

sub set_flag ($self, $flag) {
    fatal("invalid flag [$flag]") unless $is_valid_flag{$flag};
    $self->_flags->{$flag} = 1;
}

sub has_flag ($self, $flag) {
    fatal("invalid flag [$flag]") unless $is_valid_flag{$flag};
    exists $self->_flags->{$flag};
}

sub get_flags ($self) {
    return keys $self->_flags->%*;
}

sub does_apply_to_color ($self, $color) {
    if ($self->has_flag('b')) {

        # Tags with the 'b' flag only apply when it's Black to play.
        return $color eq BLACK;
    } elsif ($self->has_flag('w')) {

        # Tags with the 'w' flag only apply when it's White to play.
        return $color eq WHITE;
    } else {

        # Tags without the 'b' or 'w' flags apply to both colors.
        return 1;
    }
}

sub _data_printer ($self, $) {
    return sprintf '#%s:%s', $self->name, join('', keys $self->_flags->%*);
}
1;
