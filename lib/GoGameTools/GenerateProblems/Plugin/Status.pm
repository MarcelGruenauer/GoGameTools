package GoGameTools::GenerateProblems::Plugin::Status;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Macros;
use GoGameTools::Class;

sub handles_directive ($self, %args) {
    return $args{directive} eq 'status';
}

sub preprocess_node ($self, %args) {
    return unless $args{node}->directives->{status};

    # Add a child variation with a barrier node that contains the question,
    # followed by the answer node. These nodes are later processed in the
    # run() traversal as though they had been in the tree to begin with.
    my $question_node = GoGameTools::Node->new;
    $question_node->prepend_comment(expand_macros('{% ask_status %}'));
    $question_node->add(MN => -1);
    $question_node->add_tags('status');

    # FIXME The question node needs a move because that is where the question
    # mark will appear, so we use 'jj' == tengen. But it would be better to
    # search for an empty area into which to put the move.
    my $answer_node = GoGameTools::Node->new;
    $answer_node->add(B => 'jj');
    $answer_node->directives->{answer} = $args{node}->directives->{status};
    $args{traversal_context}
      ->add_variation($args{node} => $question_node, $answer_node);
}
1;
