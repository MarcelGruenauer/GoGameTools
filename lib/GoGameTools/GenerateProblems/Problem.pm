package GoGameTools::GenerateProblems::Problem;
use GoGameTools::features;
use Storable qw(dclone);
use GoGameTools::Class qw($tree $correct_color $needs_assembly
  $ladder_good_for @unwanted_tags %labels_for_correct_node @finalize_callbacks);

# @finalize_callbacks contains coderefs, which Storable::dclone() can't handle,
# so construct the clone manually.
sub clone ($self) {
    my $class = ref $self;
    return $class->new(
        tree                    => dclone($self->tree),
        unwanted_tags           => dclone($self->unwanted_tags),
        labels_for_correct_node => dclone($self->labels_for_correct_node),
        finalize_callbacks      => $self->finalize_callbacks,
        (map { $_ => $self->$_ } qw(correct_color needs_assembly ladder_good_for)),
    );
}

sub finalize ($self) {
    $_->($self) for $self->finalize_callbacks->@*;
}
1;
