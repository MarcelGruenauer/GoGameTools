package GoGameTools::GenerateProblems::Viewer;
use GoGameTools::features;
use GoGameTools::Class qw(new);

# subclasses can implement one or more of these hooks
sub mark_node_as_correct ($self, $node) { }
sub finalize_tree ($self, $tree) { }
1;

__END__

mark_node_as_correct():
- EasyGo: C[RIGHT]
- Glift: GB[1]
- WGo: TE[1]

finalize_tree():
- WGo: set VW[]

The following also depend on the viewer:
- lines
- questions
- tenuki

The problem generator, when given "--viewer Foo", uses a
GoGameTools::GenerateProblems::Viewer::Foo object as its delegate
