package GoGameTools::Porcelain::KataGoAnalyze;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Coordinate;
use GoGameTools::KataGo::Engine;
use GoGameTools::Log;
use GoGameTools::Class qw($path $network $config $visits $moves);
use Expect;

sub run ($self) {
    return $self->pipe_analyze;
}

sub pipe_analyze ($self) {
    return sub ($collection) {
        for my $tree ($collection->@*) {
            my @params = ('gtp', '-model', $self->network, '-config', $self->config);
            my $katago = GoGameTools::KataGo::Engine->new(
                spawn_command => $self->path,
                spawn_params  => \@params,
                wanted_visits => $self->visits,
            );
            $katago->spawn;
            my $move_number = 0;

            # special case for AB[] in the root node, which are handicap stones
            my @handicap = map { coord_sgf_to_alphanum($_) } $tree->get_node(0)->get('AB')->@*;
            $katago->set_free_handicap(@handicap) if @handicap;
            $tree->traverse(
                sub ($node, $context) {
                    if ($node->has('KM')) {
                        my $komi = $node->get('KM');
                        $katago->set_komi($komi);
                    }

                    # FIXME Add the setup stones, if any.
                    my $did_play = play_move($node, $katago);
                    if ($did_play) {

                        # Maybe the user wants us to stop analyzing after a
                        # certain move number.
                        $move_number++;
                        return if defined $self->moves && $move_number > $self->moves;
                        info("move number $move_number");
                        my $analysis = $katago->get_analysis;
                        $node->add(LZ => $analysis->render_for_lizzie);
                    }
                }
            );
            $katago->close;
        }
        return $collection;
    }
}

sub play_move ($node, $katago) {
    my $move_color = $node->move_color;
    return unless defined $move_color;
    my $move = $node->move;
    return if $move eq '';    # ignore passing
    $katago->play_move($move_color, coord_sgf_to_alphanum($move));
    return $move;             # indicate to caller that a move was played
}
1;
