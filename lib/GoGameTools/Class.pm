package GoGameTools::Class;
use GoGameTools::features;

sub import ($, @args) {
    my $pkg = caller(0);
    for (@args) {
        if ($_ eq 'new') {
            make_new($pkg);
        } else {
            my $type = substr($_, 0, 1, '');
            if ($type eq '$') { make_scalar($pkg, $_) }
            elsif ($type eq '@') { make_array($pkg, $_) }
            elsif ($type eq '%') { make_hash($pkg, $_) }
            else                 { die "cannot generate accessor for [$type$_]" }
        }
    }
    1;
}

sub make_new ($pkg) {
    no strict 'refs';
    *{"${pkg}::new"} = sub {
        my ($class, %args) = @_;
        my $self = bless {}, $class;
        while (my ($key, $value) = each %args) {

            # $self->$key($value); wouldn't work with arrays or hashes
            $self->{$key} = $value;
        }
        $self;
    };
}

sub make_scalar ($pkg, $field) {
    no strict 'refs';
    *{"${pkg}::$field"} = sub {
        return $_[0]->{$field} if @_ == 1;
        $_[0]->{$field} = $_[1];
    };
}

sub make_array ($pkg, $field) {
    no strict 'refs';
    *{"${pkg}::$field"} = sub ($self) {
        return $self->{$field} //= [];
    };
}

sub make_hash ($pkg, $field) {
    no strict 'refs';
    *{"${pkg}::$field"} = sub ($self) {
        return $self->{$field} //= {};
    };
}
1;
