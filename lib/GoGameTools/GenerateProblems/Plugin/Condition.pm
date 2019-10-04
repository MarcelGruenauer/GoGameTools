package GoGameTools::GenerateProblems::Plugin::Condition;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'condition';
}

sub handle_higher_level_directive ($self, %args) {

    # The {{ condition }} directive indicates that there is a condition for
    # playing this move. For example, you might want to teach one move if the
    # user has ko threats and another one if he doesn't.
    #
    # Therefore suppress the circle guide.
    if ($args{node}->directives->{condition}) {
        $args{node}->directives->{user_is_guided} = 1;
    }
}

sub finalize_node ($self, %args) {
    if (my $condition = $args{node}->directives->{condition}) {
        $args{parent_node}->append_comment($condition);

        # If the node contains triangle or label markup, move it to the parent
        # so the condition can refer to "the marked stone" or "the triangled
        # stone". So the assumption is that the triangles aren't intended for
        # this node at all.
        #
        # This is just an assumption, though, and if it turns out to be too
        # naive, we'll have to look for something more specific and resilient.

        for my $property (qw(TR LB)) {
            my @values = $args{node}->get($property)->@*;
            if (@values) {
                $args{parent_node}->add($property => \@values);
                $args{node}->del($property);
            }
        }
    }
}
1;
