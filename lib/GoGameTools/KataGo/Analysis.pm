package GoGameTools::KataGo::Analysis;
use GoGameTools::features;
use GoGameTools::Log;
use GoGameTools::Class qw(@variations $ownership);

sub parse_from_engine ($self, $line) {
    our $move_re //= qr/pass|[A-T]\d{1,2}/;
    our $num_re  //= qr/-?\d+(?:\.\d+)?(?:e-\d+)?/;

    # 'radius' is in KataGo v1.2, but not v1.3.
    # 'scoreLead' and 'scoreSelfplay' are in KataGo v1.3 but not v1.2
    our $info_re //= qr/^
            info          \s
            move          \s (?<move>$move_re) \s
            visits        \s (?<visits>\d+) \s
            utility       \s (?<utility>$num_re) \s
        (?: radius        \s (?<radius>$num_re) \s )?
            winrate       \s (?<winrate>$num_re) \s
            scoreMean     \s (?<scoreMean>$num_re) \s
            scoreStdev    \s (?<scoreStdev>$num_re) \s
        (?: scoreLead     \s (?<scoreLead>$num_re) \s )?
        (?: scoreSelfplay \s (?<scoreSelfplay>$num_re) \s )?
            prior         \s (?<prior>$num_re) \s
            lcb           \s (?<lcb>$num_re) \s
            utilityLcb    \s (?<utilityLcb>$num_re) \s
            order         \s (?<order>\d+) \s
            pv            \s (?<pv>$move_re (?: \s $move_re)*)
        /x;
    our $ownership_re //= qr/^
            ownership \s (?<values>$num_re (?: \s $num_re)*)
        /x;

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

sub render_for_lizzie ($self) {
    my @parts;
    for my $var ($self->variations->@*) {

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
    push @parts, sprintf 'ownership %s', $self->ownership;

    # Lizzie wants this header, like "0.7.2 54.3 2.0k\n"
    return sprintf "%s %s %s\n%s info ", '0.7.2', $self->get_winrate,
      $self->total_visits_human_readable, join(' ' => @parts);
}

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
1;
