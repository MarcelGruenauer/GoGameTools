package GoGameTools::GenerateProblems::Plugin::Status;
use GoGameTools::features;
use GoGameTools::Node;
use parent 'GoGameTools::GenerateProblems::Plugin';

sub handles_directive ($self, $directive) {
    return $directive eq 'status';
}

sub preprocess_node ($self, $node, $context) {
    return unless $node->directives->{status};

    # Add a child variation with a barrier node that contains the question,
    # followed by the answer node. These nodes are later processed in the
    # run() traversal as though they had been in the tree to begin with.
    my $question_node = GoGameTools::Node->new;
    $question_node->append_comment("What is the status of this group??");
    $question_node->add(MN => -1);
    $question_node->add_tags('status');

    # FIXME The question node needs a move because that is where the question
    # mark will appear, so we use 'jj' == tengen. But it would be better to
    # search for an empty area into which to put the move.
    my $answer_node = GoGameTools::Node->new;
    $answer_node->add(B => 'jj');
    $answer_node->directives->{answer} = $node->directives->{status};
    $context->add_variation($node => $question_node, $answer_node);
}
1;
