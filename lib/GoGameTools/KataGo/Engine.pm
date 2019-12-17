package GoGameTools::KataGo::Engine;
use GoGameTools::features;
use GoGameTools::Log;
use GoGameTools::Class qw($spawn_command @spawn_params $wanted_visits);
use GoGameTools::KataGo::Analysis;
use GoGameTools::KataGo::Variation;

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
        $analysis = GoGameTools::KataGo::Analysis->new->parse_from_engine(
            $self->get_analysis_line);
    } until $analysis->total_visits >= $self->wanted_visits;
    return $analysis;
}

sub get_analysis_line ($self) {
    $self->exp->clear_accum;    # so it doesn't keep returning the same line

    # match last ownership stats
    $self->exp->expect(undef, '-re', '(?=-?\d\.\d+\n)');
    my $line = $self->exp->after;
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

sub set_free_handicap ($self, @handicap) {
    $self->send("set_free_handicap @handicap");
    $self->exp->expect(undef, '-re', '=');
}

sub close ($self) {
    $self->exp->hard_close;
}
1;
