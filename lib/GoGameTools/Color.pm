package GoGameTools::Color;
use GoGameTools::features;
use GoGameTools::Log;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      BLACK
      WHITE
      EMPTY
      name_for_color_const
      other_color);
}
use constant {
    BLACK => 'B',
    WHITE => 'W',
    EMPTY => 'e',
};

sub name_for_color_const ($color_const) {
    return 'Black' if $color_const eq BLACK;
    return 'White' if $color_const eq WHITE;
    fatal("unknown color constant [$color_const]");
}

sub other_color ($color_const) {
    return WHITE if $color_const eq BLACK;
    return BLACK if $color_const eq WHITE;
    fatal("unknown color constant [$color_const]");
}
1;
