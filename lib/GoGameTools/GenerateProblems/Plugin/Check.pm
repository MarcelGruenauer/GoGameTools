package GoGameTools::GenerateProblems::Plugin::Check;
use GoGameTools::features;
use GoGameTools::Log;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub finalize_problem_2 ($self, %args) {
    $self->check_problem(
        problem  => $args{problem},
        on_error => sub ($message) {
            warning($args{problem}->tree->with_location($message));
        }
    );
}

sub check_problem ($self, %args) {
    my %tags = map { $_ => 1 } $args{problem}->tree->metadata->{tags}->@*;

    # assert that there is at least one tag
    unless (keys %tags) {
        $args{on_error}->('problem has no tags');
    }

    # check conflicting tags
    my @conflicts = (
        [qw(attacking defending)], [qw(offensive_endgame defensive_endgame)],
        [qw(living killing)],      [qw(ddk3 ddk2 ddk1 lowsdk highsdk lowdan highdan)],
    );
    for my $spec (@conflicts) {
        my @occur = grep { $tags{$_} } $spec->@*;
        if (@occur > 1) {
            $args{on_error}
              ->(sprintf 'conflicting tags: %s', join ', ', map { "#$_" } sort @occur);
        }
    }
}
1;
