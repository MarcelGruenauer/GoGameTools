#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Board;
use GoGameTools::Color;
use Test::More;
use Test::Differences;

subtest 'place and remove stone' => sub {
    my $board = GoGameTools::Board->new;
    my $tengen = 'jj';
    is($board->stone_at_coord($tengen), EMPTY, 'tengen is empty');
    $board->place_stone_at_coord($tengen, BLACK);
    is($board->stone_at_coord($tengen), BLACK, 'played black stone at tengen');
    $board->remove_stone_at_coord($tengen);
    is($board->stone_at_coord($tengen), EMPTY, 'removed stone at tengen');
};
subtest 'play and capture stones in a corner' => sub {
    my $board = GoGameTools::Board->new;
    is($board->play('aa', BLACK), 1, 'playing a black stone on (1,1) worked');
    is($board->stone_at_coord('aa'), BLACK, 'the stone at (1,1) is black');
    is($board->play('aa', BLACK),
        undef, 'playing a black stone on the occupied (1,1) failed');
    is($board->play('aa', WHITE),
        undef, 'playing a white stone on the occupied (1,1) failed');
    is($board->stone_at_coord('aa'),
        BLACK, '... but the black stone is still there');
    is($board->play('ab', WHITE), 1, 'playing a white stone on (1,2) worked');
    is($board->play('ba', WHITE), 1, 'playing a white stone on (2,1) worked');
    is($board->stone_at_coord('aa'), EMPTY, 'the stone at (1,1) is gone');
};
done_testing;
