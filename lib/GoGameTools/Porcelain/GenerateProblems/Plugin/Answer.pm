package GoGameTools::Porcelain::GenerateProblems::Plugin::Answer;
use GoGameTools::features;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'answer';
}

# The {{ answer }} directive splits this node into the answering move itself
# and the answer response node.
sub handle_cloned_node_for_problem ($self, %args) {
    if ($args{cloned_node}->directives->{answer}) {
        $args{problem}->tree->unshift_node(
            $self->_get_answer_response_node_from_node($args{cloned_node}));

        # Delete superfluous markup from the correct node.
        $args{cloned_node}->del(qw(C LB TR SQ));
    }
}

# {{ answer }} will produce a guide to where the user should play to see the
# answer. It will also set MN[-1] so that, when the problem is later prepared
# for a specific viewer such as WGo, you can decide how to present a question.
# For example, suppose you want add "Black/White to play" comments to the setup
# node of every problem, then you would want to skip that comment for
# questions.
sub finalize_node ($self, %args) {
    if ($args{node}->directives->{answer}) {
        $args{parent_node}->add(CR => [ $args{node}->move ])->add(MN => -1);
    }
}

# Get a clone without the parent connection; we will set up the answer response
# on this new node.
#
# Replace its move with AE[] that will erase the answering move. That way, when
# the user clicks on the question mark, the final answer response node will
# look clean. Also use the 'answer' directive's content as the comment.
sub _get_answer_response_node_from_node ($self, $node) {
    for ($node->public_clone) {
        $_->add(AE => [ $_->move ]);
        $_->add(C  => $node->directives->{answer});
        $_->del(qw(B W));
        delete $_->directives->{answer};
        $_->add_tags('question');
        return $_;
    }
}
1;
