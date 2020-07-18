package GoGameTools::Porcelain::SiteMungeSGJ;
use GoGameTools::features;
use GoGameTools::Util;
use Path::Tiny;
use utf8;
use GoGameTools::Class
  qw($delete_private_refs $delete_secret_problems $basedir);

sub run ($self) {
    return (
        sub ($collection) {
            my @new_objects;
          OBJECT: for my $obj ($collection->@*) {

                # If a basedir is given, make the filename relative to that dir. It's
                # less cluttered and more private.
                if (defined $self->basedir) {
                    $obj->{metadata}{filename} =
                      path($obj->{metadata}{filename})->relative($self->basedir) . '';
                }
                my @new_refs;
                my $refs = $obj->{metadata}{refs} //= [];
                for ($refs->@*) {

                    # 1) problems we might want to omit completely
                    next OBJECT if $self->delete_secret_problems && substr($_, 0, 2) eq 's/';

                    # 2) refs we might want to omit
                    next if $self->delete_private_refs && substr($_, 0, 2) eq 'p/';

                    # 3) default: take the ref
                    push @new_refs, $_;

                    # 4) refs we might want to add
                    if (m!^notcher/code/(\d)\d\d/[WSN]{2}$!) {
                        push @new_refs, 'tsumego/real/side/notcher', "notcher/length/$1";
                    }
                }
                $refs->@* = @new_refs;
                push @new_objects, $obj;
            }
            return \@new_objects;
        }
    );
}
1;
