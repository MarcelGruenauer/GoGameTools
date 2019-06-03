package GoGameTools::GenerateProblems::Plugin::RateChoices;
use GoGameTools::features;
use GoGameTools::Node;
use GoGameTools::Color;
use GoGameTools::Munge;
use GoGameTools::Macros;
use GoGameTools::Log;
use GoGameTools::Class qw(new);

sub handles_directive ($self, %args) {
    return $args{directive} eq 'rate_choices';
}

sub preprocess_node ($self, %args) {
    return unless $args{node}->directives->{rate_choices};
    my ($good_children_ref, $bad_children_ref) =
      divide_children_into_good_and_bad($args{node}, $args{traversal_context});
    my @good_children = $good_children_ref->@*;
    my @bad_children  = $bad_children_ref->@*;

    # Make sure that the node has more than one good child.
    unless (@good_children) {
        fatal(
            $args{node}->with_location(
                '{{ rate_choices }} needs at least one good opponent response')
        );
    }
    unless (@bad_children) {
        fatal(
            $args{node}->with_location(
                '{{ rate_choices }} needs at least one bad opponent response')
        );
    }
    my $color_to_play = $good_children[0]->move_color;
    my $color_name    = name_for_color_const($color_to_play);

    # Add a child variation with a barrier node that contains the question,
    # followed by the answer node. These nodes are later processed in the
    # run() traversal as though they had been in the tree to begin with.
    my $question_node = GoGameTools::Node->new;
    $question_node->append_comment(
        expand_macros("{% ask_rate_choices $color_to_play %}"));
    $question_node->add(SQ => [ map { $_->move } @good_children, @bad_children ]);
    $question_node->add(MN => -1);
    $question_node->add_tags('rate_choices');

    # FIXME The question node needs a move because that is where the question
    # mark will appear, so we use 'jj' == tengen. But it would be better to
    # search for an empty area into which to put the move.
    my $answer_node = GoGameTools::Node->new;
    $answer_node->add($color_to_play, 'jj');
    $answer_node->add(CR => [ map { $_->move } @good_children ]);
    $answer_node->add(MA => [ map { $_->move } @bad_children ]);
    my $moves_are_good = @good_children > 1 ? 'moves are good' : 'move is good';
    my $moves_are_bad  = @bad_children > 1  ? 'moves are bad'  : 'move is bad';
    $answer_node->directives->{answer} =
      "The circled $color_name $moves_are_good; the crossed-out $moves_are_bad.";
    $args{traversal_context}
      ->add_variation($args{node} => $question_node, $answer_node);
}
1;
