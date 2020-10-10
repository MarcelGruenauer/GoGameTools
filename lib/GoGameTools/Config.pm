package GoGameTools::Config;
use GoGameTools::features;
use GoGameTools::Class qw(%c);

sub get_global_config ($self) {
    return our $global_config //= $self->new;
}

# convenience methods
sub set ($self, $key, $value) {
    $self->c->{$key} = $value;
}

sub set_from_hash ($self, %args) {
    while (my ($k, $v) = each %args) {
        $self->set($k, $v);
    }
}

sub get ($self, $key, $default = undef) {
    return $self->c->{$key} // $default;
}
1;
