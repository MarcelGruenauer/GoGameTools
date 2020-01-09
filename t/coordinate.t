#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Coordinate;
use Test::More;
use Test::Differences;
subtest coord_sgf_to_xy => sub {
    my sub _ok ($coord, @expect) {
        eq_or_diff [ coord_sgf_to_xy($coord) ], \@expect,
          "$coord is ($expect[0], $expect[1])";
    }
    _ok(aa => 1,  1);
    _ok(bc => 2,  3);
    _ok(ss => 19, 19);
};
subtest coord_sgf_to_alphanum => sub {
    my sub _ok ($coord, $expect) {
        eq_or_diff coord_sgf_to_alphanum($coord), $expect, "$coord => $expect";
    }
    _ok(aa => 'A19');
    _ok(bc => 'B17');
    _ok(hk => 'H9');
    _ok(ii => 'J11');
    _ok(jj => 'K10');
    _ok(ss => 'T1');
};
subtest coord_swap_axes => sub {
    my sub _ok ($coord, $expect) {
        eq_or_diff coord_swap_axes($coord), $expect, "$coord => $expect";
    }
    _ok(aa => 'aa');
    _ok(bc => 'cb');
    _ok(sa => 'as');
};
subtest coord_mirror_vertically => sub {
    my sub _ok ($coord, $expect) {
        eq_or_diff coord_mirror_vertically($coord), $expect, "$coord => $expect";
    }
    _ok(aa => 'as');
    _ok(bc => 'bq');
    _ok(hk => 'hi');
    _ok(ii => 'ik');
    _ok(jj => 'jj');
    _ok(sa => 'ss');
};
subtest coord_mirror_horizontally => sub {
    my sub _ok ($coord, $expect) {
        eq_or_diff coord_mirror_horizontally($coord), $expect, "$coord => $expect";
    }
    _ok(aa => 'sa');
    _ok(bc => 'rc');
    _ok(hk => 'lk');
    _ok(ii => 'ki');
    _ok(jj => 'jj');
    _ok(sa => 'aa');
};
subtest coord_neighbors => sub {
    my sub _ok ($coord, @expect) {
        eq_or_diff coord_neighbors($coord), \@expect, "neighbors of $coord";
    }
    _ok(cd => qw(bd dd cc ce));
    _ok(ao => qw(bo an ap));
    _ok(as => qw(bs ar));
};
subtest coord_expand_rectangle => sub {
    my sub _ok ($rect, @expect) {
        eq_or_diff [ coord_expand_rectangle($rect) ], \@expect,
          "expanded rectangle $rect";
    }
    _ok('bb:bb' => qw(bb));
    _ok('bc:be' => qw(bc bd be));
    _ok('bc:de' => qw(bc bd be cc cd ce dc dd de));
};
done_testing;
