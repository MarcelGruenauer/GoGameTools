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
    my sub _ok { _scalar_function_ok(\&coord_sgf_to_alphanum, @_) }
    _ok(aa => 'A19');
    _ok(bc => 'B17');
    _ok(hk => 'H9');
    _ok(ii => 'J11');
    _ok(jj => 'K10');
    _ok(ss => 'T1');
};
subtest coord_alphanum_to_sgf => sub {
    my sub _ok { _scalar_function_ok(\&coord_alphanum_to_sgf, @_) }
    _ok('A19' => 'aa');
    _ok('B17' => 'bc');
    _ok('H9' => 'hk');
    _ok('J11' => 'ii');
    _ok('K10' => 'jj');
    _ok('T1' => 'ss');
};
subtest coord_swap_axes => sub {
    my sub _ok { _scalar_function_ok(\&coord_swap_axes, @_) }
    _ok(aa => 'aa');
    _ok(bc => 'cb');
    _ok(sa => 'as');
};
subtest coord_mirror_vertically => sub {
    my sub _ok { _scalar_function_ok(\&coord_mirror_vertically, @_) }
    _ok(aa => 'as');
    _ok(bc => 'bq');
    _ok(hk => 'hi');
    _ok(ii => 'ik');
    _ok(jj => 'jj');
    _ok(sa => 'ss');
};
subtest coord_mirror_horizontally => sub {
    my sub _ok { _scalar_function_ok(\&coord_mirror_horizontally, @_) }
    _ok(aa => 'sa');
    _ok(bc => 'rc');
    _ok(hk => 'lk');
    _ok(ii => 'ki');
    _ok(jj => 'jj');
    _ok(sa => 'aa');
};
# Test helper functions for moving positions around on the board
subtest coord_shift_left => sub {
    my sub _ok { _scalar_function_ok(\&coord_shift_left, @_) }
    _ok(aa => undef);
    _ok(as => undef);
    _ok(ba => 'aa');
    _ok(bs => 'as');
    _ok(sa => 'ra');
    _ok(ss => 'rs');
};
subtest coord_shift_right => sub {
    my sub _ok { _scalar_function_ok(\&coord_shift_right, @_) }
    _ok(aa => 'ba');
    _ok(as => 'bs');
    _ok(ba => 'ca');
    _ok(bs => 'cs');
    _ok(sa => undef);
    _ok(ss => undef);
};
subtest coord_shift_up => sub {
    my sub _ok { _scalar_function_ok(\&coord_shift_up, @_) }
    _ok(aa => undef);
    _ok(as => 'ar');
    _ok(ba => undef);
    _ok(bs => 'br');
    _ok(sa => undef);
    _ok(ss => 'sr');
};
subtest coord_shift_down => sub {
    my sub _ok { _scalar_function_ok(\&coord_shift_down, @_) }
    _ok(aa => 'ab');
    _ok(as => undef);
    _ok(ba => 'bb');
    _ok(bs => undef);
    _ok(sa => 'sb');
    _ok(ss => undef);
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

# Most functions convert one string to another string. This helper method makes
# comparisons easier.
sub _scalar_function_ok ($coderef, $coord, $expect) {
    my $got = $coderef->($coord);
    if (defined $expect) {
        if (defined $got) {
            eq_or_diff $got, $expect, "$coord => $expect";
        } else {
            is $got, $expect, "$coord => undef";
        }
    } else {
        is $got, $expect, "$coord => undef";
    }
}
