#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Node;
use Data::Dumper;
use Test::More;
use Test::Differences;
subtest 'has, had' => sub {
    my $node = GoGameTools::Node->new;
    $node->add('GB', 1);
    ok $node->has('GB'), 'node has GB[]';
    ok $node->had('GB'), 'node had GB[]';
    ok !$node->has('GB'), 'node no longer has GB[]';
};
subtest 'expand_rectangles()', sub {
    subtest 'valid', sub {
        my @this_spec = (
            { input => ['ab'],      expect => [qw(ab)] },
            { input => ['cp:ep'],   expect => [qw(cp dp ep)] },
            { input => ['ab:cd'],   expect => [qw(ab ac ad bb bc bd cb cc cd)] },
            { input => [],          expect => [] },
            { input => [qw(ab cd)], expect => [qw(ab cd)] },
            {   input  => [qw(ab:cd ef:gh)],
                expect => [
                    qw(
                      ab ac ad bb bc bd cb cc cd
                      ef eg eh ff fg fh gf gg gh
                      )
                ]
            },
        );
        for my $spec (@this_spec) {
            local $Data::Dumper::Terse = 1;
            my $name = Dumper($spec->{input}) =~ s/\s//gr;
            my $node = GoGameTools::Node->new;
            $node->add(AW => $spec->{input});
            eq_or_diff($node->expand_rectangles($node->get('AW')), $spec->{expect}, $name);
        }
    };
};
subtest 'filter()', sub {

    # Add stones at regular intervals; remove all except those in some
    # rectangle.
    my $node = GoGameTools::Node->new;
    $node->add(
        AW => [
            qw(
              dd dg dj dm dp
              jd jg jj jm jp
              pd pg pj pm pp)
        ]
    );
    $node->add(
        AB => [
            qw(
              gd gg gj gm gp
              md mg mj mm mp)
        ]
    );
    $node->filter([qw(AW AB)], qr/^[m-s][a-h]/);
    is $node->as_sgf, 'AB[md][mg]AW[pd][pg]', 'multiple properties; regex filter';
    $node = GoGameTools::Node->new;
    $node->add(AW => [ map { "$_$_" } 'a' .. 's' ]);
    $node->filter(AW => sub ($v) { $v lt 'er' });
    is $node->as_sgf, 'AW[aa][bb][cc][dd][ee]', 'single property; coderef filter';
};
subtest 'reorient coordinates and comments' => sub {
    my $UL      = "upper left corner\n";
    my $UR      = "upper right corner\n";
    my $LL      = "lower left corner\n";
    my $LR      = "lower right corner\n";
    my $TS      = "upper side\n";
    my $BS      = "lower side\n";
    my $LS      = "left side\n";
    my $RS      = "right side\n";
    my $comment = "$UL $UR $LL $LR $TS $BS $LS $RS";
    #
    subtest swap_axes => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->add(LB => [ [qw(kq hi)] ]);
        $node->append_comment($comment);
        $node->swap_axes;
        eq_or_diff $node->get('AB'), [qw(dp qk)], 'swap_axes for normal coordinates';
        eq_or_diff $node->get('LB'), [ [qw(qk hi)] ],
          'swap_axes for coordinates in labels';
        eq_or_diff $node->get('C') . "\n", "$UL $LL $UR $LR $LS $RS $TS $BS",
          'corners and sides';
    };
    #
    subtest mirror_vertically => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->append_comment($comment);
        $node->mirror_vertically;
        eq_or_diff $node->get('AB'), [qw(pp kc)], 'coordinates';
        eq_or_diff $node->get('C') . "\n", "$LL $LR $UL $UR $BS $TS $LS $RS",
          'corners and sides';
    };
    #
    subtest mirror_horizontally => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->append_comment($comment);
        $node->mirror_horizontally;
        eq_or_diff $node->get('AB'), [qw(dd iq)], 'coordinates';
        eq_or_diff $node->get('C') . "\n", "$UR $UL $LR $LL $TS $BS $RS $LS",
          'corners and sides';
    };
    #
    subtest rotate_cw => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->append_comment($comment);
        $node->rotate_cw;
        eq_or_diff $node->get('AB'), [qw(pp ck)], 'rotate_cw';
        eq_or_diff $node->get('C') . "\n", "$UR $LR $UL $LL $RS $LS $TS $BS",
          'corners and sides';
    };
    #
    subtest rotate_ccw => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->append_comment($comment);
        $node->rotate_ccw;
        eq_or_diff $node->get('AB'), [qw(dd qi)], 'rotate_ccw';
        eq_or_diff $node->get('C') . "\n", "$LL $UL $LR $UR $LS $RS $BS $TS",
          'corners and sides';
    };
    #
    subtest transpose_to_opponent_view => sub {
        my $node = GoGameTools::Node->new;
        $node->add(AB => [qw(pd kq)]);
        $node->append_comment($comment);
        $node->transpose_to_opponent_view;
        eq_or_diff $node->get('AB'), [qw(dp ic)], 'transpose_to_opponent_view';
        eq_or_diff $node->get('C') . "\n", "$LR $LL $UR $UL $BS $TS $RS $LS",
          'corners and sides';
    };
};
done_testing;
