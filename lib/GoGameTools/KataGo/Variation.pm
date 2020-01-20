package GoGameTools::KataGo::Variation;
use GoGameTools::features;
use GoGameTools::Class qw(
  $move $visits $utility $radius $winrate
  $scoreMean $scoreStdev $scoreLead $scoreSelfplay
  $prior $lcb $utilityLcb $order @pv
);
1;

=pod

C<radius> is in KataGo v1.2, but not v1.3.

C<scoreLead> and C<scoreSelfplay> are in KataGo v1.3 but not v1.2

=cut
