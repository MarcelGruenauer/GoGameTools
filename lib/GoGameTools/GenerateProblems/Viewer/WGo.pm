package GoGameTools::GenerateProblems::Viewer::WGo;
use GoGameTools::features;
use GoGameTools::Coordinate;
use parent 'GoGameTools::GenerateProblems::Viewer';

sub mark_node_as_correct ($self, $node) {
    $node->add(GB => 1);
}

# set viewport (VW[])
sub finalize_problem ($self, $problem) {
    return; # FIXME

    my ($upper_left, $lower_right) = ('jj', 'jj');
    $problem->tree->traverse(
        sub ($node, $) {
            my @coords = map { $node->get($_)->@* } qw(AB AW TR CR MA SQ);
            push @coords, map { $_->[0] } $node->get('LB')->@*;
            if (my $move = $node->move) {
                push @coords, $move;
            }
            for my $coord (@coords) {
                $upper_left  = $coord if $coord lt $upper_left;
                $lower_right = $coord if $coord gt $lower_right;
            }

            # Margins: add two lines to each border. If it gets too close to
            # the edge, enlarge it to the edge.
            #
            # upper left
            my ($x, $y) = coord_sgf_to_xy($upper_left);
            $x -= 2 if $x > 2;
            $x = 1 if $x < 3;
            $y -= 2 if $y > 2;
            $y          = 1 if $y < 3;
            $upper_left = join '', map { chr($_ + 96) } $x, $y;

            # lower right
            ($x, $y) = coord_sgf_to_xy($lower_right);
            $x += 2 if $x < 18;
            $x = 19 if $x > 17;
            $y += 2 if $y < 18;
            $y           = 19 if $y > 17;
            $lower_right = join '', map { chr($_ + 96) } $x, $y;

            # set the VW[] property
        }
    );
    $problem->tree->get_node(0)->add(VW => [ sprintf '%s:%s', $upper_left, $lower_right ]);
}
sub label_for_bad_move ($self)  { return '?' }
sub label_for_good_move ($self) { return '!' }

# We could use emoji but they don't look so good in the WGo viewer
# sub label_for_bad_move ($self)  { return chr(0x2639) }    # frowning face
# sub label_for_good_move ($self) { return chr(0x263A) }    # smiling face
1;
