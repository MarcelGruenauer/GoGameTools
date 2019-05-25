package GoGameTools::GenerateProblems::Viewer::EasyGo;
use GoGameTools::features;
use parent 'GoGameTools::GenerateProblems::Viewer';

sub mark_node_as_correct ($self, $node) {
    $node->append_comment("RIGHT");
}
1;
