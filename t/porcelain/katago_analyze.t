#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Porcelain::KataGoAnalyze;
use Test::More;
use Test::Differences;

# includes 'pass', integer scoreMean and scientific notation lcb
my $info =
  'info move pass visits 2 utility -1.06649 radius 2.8 winrate 4.85318e-05 scoreMean -13 scoreStdev 7.30532 prior 0.0041244 lcb -0.995147 utilityLcb -2.8 order 16 pv pass R19 ';
my $katago   = GoGameTools::KataGo::Engine->new->init;
my $analysis = $katago->parse_analysis_line($info);
my $expect   = GoGameTools::KataGo::Analysis->new(
    variations => [
        GoGameTools::KataGo::Variation->new(
            radius     => '2.8',
            lcb        => '-0.995147',
            prior      => '0.0041244',
            winrate    => '4.85318e-05',
            utilityLcb => '-2.8',
            scoreStdev => '7.30532',
            order      => '16',
            scoreMean  => '-13',
            pv         => 'pass R19',
            visits     => '2',
            move       => 'pass',
            utility    => '-1.06649'
        )
    ]
);
eq_or_diff $analysis, $expect, 'parsed info line';
done_testing;
