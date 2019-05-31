package GoGameTools::GenerateProblems::Viewer::Glift;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Viewer';

sub mark_node_as_correct ($self, $node) {
    $node->add(GB => 1);
}
sub label_for_bad_move ($self)  { return '?' }
sub label_for_good_move ($self) { return '!' }
1;
