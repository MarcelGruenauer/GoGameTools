package GoGameTools::Porcelain::KataGoAnalyze;
use GoGameTools::features;
use GoGameTools::Color;
use GoGameTools::Log;
use Expect;
use GoGameTools::Class qw($path $network $config $visits $moves);

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
            )->init;
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
                        $node->add(LZ => format_analysis_for_lizzie($analysis));
                    }
                }
            );
            $katago->close;
        }
        return $collection;
    }
}

sub format_analysis_for_lizzie ($analysis) {
    my @parts;
    for my $var ($analysis->variations->@*) {

        # scoreMean can be in scientific notation as well, e.g.'-7.29874e-05',
        # so use %.6f.
        my $part = sprintf 'move %s visits %d winrate %d scoreMean %.6f pv %s',
          $var->move, $var->visits, int(10_000 * $var->winrate),
          $var->scoreMean, $var->pv;

        # Lizzie doesn't want the first variation to start with 'info', but the
        # word appears at the end of the whole string.
        $part = "info $part" if @parts;
        push @parts, $part;
    }
    push @parts, sprintf 'ownership %s', $analysis->ownership;

    # Lizzie wants this header, like "0.7.2 54.3 2.0k\n"
    return sprintf "%s %s %s\n%s info ", '0.7.2', $analysis->get_winrate,
      $analysis->total_visits_human_readable, join(' ' => @parts);
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

package GoGameTools::KataGo::Engine;
use GoGameTools::features;
use GoGameTools::Log;
use GoGameTools::Class qw($spawn_command @spawn_params $wanted_visits);

sub init ($self) {
    our $move_re //= qr/pass|[A-T]\d{1,2}/;
    our $num_re  //= qr/-?\d+(?:\.\d+)?(?:e-\d+)?/;
    our $info_re //= qr/^
            info       \s
            move       \s (?<move>$move_re) \s
            visits     \s (?<visits>\d+) \s
            utility    \s (?<utility>$num_re) \s
            radius     \s (?<radius>$num_re) \s
            winrate    \s (?<winrate>$num_re) \s
            scoreMean  \s (?<scoreMean>$num_re) \s
            scoreStdev \s (?<scoreStdev>$num_re) \s
            prior      \s (?<prior>$num_re) \s
            lcb        \s (?<lcb>$num_re) \s
            utilityLcb \s (?<utilityLcb>$num_re) \s
            order      \s (?<order>\d+) \s
            pv         \s (?<pv>$move_re (?: \s $move_re)*)
        /x;
    our $ownership_re //= qr/^
            ownership \s (?<values>$num_re (?: \s $num_re)*)
        /x;
    return $self;
}

sub exp ($self) {
    unless (defined $self->{exp}) {
        my $exp = Expect->new;
        $exp->raw_pty(1);
        $exp->log_stdout(0);

        # $exp->exp_internal(1);
        $self->{exp} = $exp;
    }
    return $self->{exp};
}

sub spawn ($self) {
    info('spawning KataGo');
    $self->exp->spawn($self->spawn_command, $self->spawn_params->@*)
      or die sprintf "Cannot spawn %s $!\n", $self->spawn_command;
    $self->exp->expect(undef, 'KataGo v1.2');
    info('KataGo has responded');
    $self->exp->expect(undef, '-re', 'GTP ready, beginning main protocol loop');
    info('beginning GTP loop');
}

sub send ($self, $command) {
    info("SEND: $command");
    $self->exp->send("$command\n");
}

sub get_analysis ($self) {
    $self->send("kata-analyze 100 ownership true");

    # keep receiving lines until we have reached the desired number of visits
    my $analysis;
    do {
        $analysis = $self->parse_analysis_line($self->get_analysis_line);
    } until $analysis->total_visits >= $self->wanted_visits;
    return $analysis;
}

sub get_analysis_line ($self) {
    $self->exp->clear_accum;    # so it doesn't keep returning the same line

    # match last ownership stats
    $self->exp->expect(undef, '-re', '(?=-?\d\.\d+\n)');
    my $line = $self->exp->after;
}

sub parse_analysis_line ($self, $line) {
    our ($info_re, $ownership_re);

    # Expect could have returned several analysis lines; delete everything up
    # to the start of the last line. Also trim the end, split the line into
    # parts and parse. Create a GoGameTools::KataGo::Analysis object that
    # contains GoGameTools::KataGo::Variation objects and the ownership map.
    $line =~ s/^.*(?=^info\b)//ms;
    $line =~ s/[\s\r\n]$//;
    my $analysis = GoGameTools::KataGo::Analysis->new;
    my @parts    = split /\b(?=info|ownership)\b/, $line;
    for my $part (@parts) {
        if ($part =~ $info_re) {
            push $analysis->variations->@*, GoGameTools::KataGo::Variation->new(%+);
        } elsif ($part =~ $ownership_re) {
            $analysis->ownership($+{values});
        } else {
            die "can't parse analysis part [$part]\n";
        }
    }
    info(sprintf 'RECV: %s visits', $analysis->total_visits_human_readable);
    return $analysis;
}

sub play_move ($self, $color, $coord) {
    $self->send("play $color $coord");
    $self->exp->expect(undef, '-re', '^=');
}

sub send_name ($self) {
    $self->send('name');
    $self->exp->expect(undef, '-re', '= KataGo');
}

sub set_komi ($self, $komi) {
    $self->send("komi $komi");
    $self->exp->expect(undef, '-re', '=');
}

sub close ($self) {
    $self->exp->hard_close;
}

package GoGameTools::KataGo::Analysis;
use GoGameTools::features;
use GoGameTools::Class qw(@variations $ownership);

sub total_visits ($self) {
    my $v = 0;
    $v += $_->visits for $self->variations->@*;
    return $v;
}

# Logic from Lizzie.
#
# Return a shorter, rounded string version of visits. e.g. 345 -> 345, 1265
# -> 1.3k, 44556 -> 45k, 133523 -> 134k, 1234567 -> 1.2m.
sub total_visits_human_readable ($self) {
    my $visits = $self->total_visits;
    if ($visits >= 1_000_000) {
        return sprintf '%.1fm', $visits / 1_000_000;
    } elsif ($visits >= 10_000) {
        return sprintf '%dk', $visits / 1_000;
    } elsif ($visits >= 1_000) {
        return sprintf '%.1fk', $visits / 1_000;
    } else {
        return $visits;
    }
}

sub get_winrate ($self) {
    return sprintf '%.1f', 100 * (1 - $self->variations->[0]->winrate);
}

package GoGameTools::KataGo::Variation;
use GoGameTools::features;
use GoGameTools::Class qw(
  $move $visits $utility $radius $winrate $scoreMean
  $scoreStdev $prior $lcb $utilityLcb $order @pv
);
1;
