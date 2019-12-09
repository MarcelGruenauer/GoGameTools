package GoGameTools::Porcelain::KataGoAnalyze;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Log;
use Expect;
use GoGameTools::Class qw($path $network $config $visits $moves);
use GoGameTools::KataGo::Engine;

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

    # convert coordinate like 'dp' => 'D4'
    if ($move =~ /([a-s])([a-s])/) {
        my $x = uc $1;
        $x++ if $x gt 'H';
        my $y = 116 - ord($2);
        $move = "$x$y";
    } else {
        die "can't convert move coordinate '$move'\n";
    }
    $katago->play_move($move_color, $move);
    return $move;             # indicate to caller that a move was played
}
1;
