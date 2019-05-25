package GoGameTools::GenerateProblems::Plugin::HasAllGoodResponses;
use GoGameTools::features;
use GoGameTools::Node;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'has_all_good_responses';
}

sub handle_higher_level_directive ($self, $node, $context) {
    if ($node->directives->{has_all_good_responses}) {
        my ($good_children_ref, $bad_children_ref) =
          $self->_divide_children_into_good_and_bad($node, $context);
        if ($good_children_ref->@* > 1) {
            $node->directives->{$_} = 1 for qw(deter show_choices);
        }
        if ($bad_children_ref->@* > 0) {
            $node->directives->{rate_choices} = 1;
        }
    }
}
1;
