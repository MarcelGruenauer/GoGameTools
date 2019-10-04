package GoGameTools::GenerateProblems::Viewer;
use GoGameTools::features;
use GoGameTools::Class;

# subclasses can implement one or more of these hooks
sub mark_node_as_correct ($self, $node) { }
sub finalize_problem ($self, $problem) { }

# Where to find the viewer-specific site files. E.g., ::Viewer::WGo will look
# for them in the /wgo subdir.
sub site_subdir ($self) {
    return ref($self) =~ s/GoGameTools::GenerateProblems::Viewer:://r;
}
sub label_for_bad_move ($self)  { }
sub label_for_good_move ($self) { }
1;

=pod

mark_node_as_correct():
- EasyGo: C[RIGHT]
- Glift: GB[1]
- WGo: GB[1]

finalize_problem():
- WGo: set VW[]

label_for_good_move(), label_for_bad_move():
- EasyGo: '!', '?'
- Glift: '!', '?'
- WGo: emoji

The following also depend on the viewer:
- lines
- questions
- tenuki

C<gogame-gen-problems> and C<gogame-site-run>, when given C<--viewer Foo>, use
a C<GoGameTools::GenerateProblems::Viewer::Foo> object as its delegate

=cut
