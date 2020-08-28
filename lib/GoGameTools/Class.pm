package GoGameTools::Class;
use GoGameTools::features;

sub import ($, @args) {
    my $pkg = caller(0);
    no strict 'refs';
    *{"${pkg}::new"} = sub {
        my $class = shift;
        bless {@_}, $class;
    };
    for my $field (@args) {
        my $type = substr($field, 0, 1, '');
        if ($type eq '$') {
            *{"${pkg}::$field"} = sub {
                return $_[0]->{$field} if @_ == 1;
                $_[0]->{$field} = $_[1];
            };
        } elsif ($type eq '@') {
            *{"${pkg}::$field"} = sub ($self) {
                $self->{$field} //= [];
            };
        } elsif ($type eq '%') {
            *{"${pkg}::$field"} = sub ($self) {
                $self->{$field} //= {};
            };
        } else {
            die "invalid accessor spec [${pkg}::${type}${field}]";
        }
    }
}
1;
