package GoGameTools::GenerateProblems::Plugin::HasAllGoodResponses;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Munge;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'has_all_good_responses';
}

sub handle_higher_level_directive ($self, %args) {
    if ($args{node}->directives->{has_all_good_responses}) {
        my ($good_children_ref, $bad_children_ref) =
          divide_children_into_good_and_bad($args{node}, $args{traversal_context});
        if ($good_children_ref->@* > 1) {
            $args{node}->directives->{$_} = 1 for qw(deter show_choices);
        }
        if ($bad_children_ref->@* > 0) {
            $args{node}->directives->{rate_choices} = 1;
        }
    }
}
1;
