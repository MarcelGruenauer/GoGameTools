package GoGameTools::Porcelain::GenerateProblems;
use GoGameTools::features;
use GoGameTools::Util;
use GoGameTools::Porcelain::GenerateProblems::Runner;
use GoGameTools::Class qw($viewer_delegate $on_warning);

sub run ($self, %args) {
    return (
        sub ($collection) {
            return [
                map {
                    GoGameTools::Porcelain::GenerateProblems::Runner->new(
                        viewer_delegate => $self->viewer_delegate,
                        on_warning      => $self->on_warning,
                        source_tree     => $_
                      )->run->get_generated_trees
                } $collection->@*
            ];
        }
    );
}
1;
