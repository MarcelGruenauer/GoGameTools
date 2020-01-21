#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Plumbing;
use GoGameTools::Util;
use GoGameTools::Porcelain::MakeLinearStory;
use Test::More;
use Test::Differences;

sub porcelain_ok (%args) {
    my $porcelain = GoGameTools::Porcelain::MakeLinearStory->new(
        story_file  => $args{story_file},
        output_file => 'result.sgf'
    );
    my ($collection) = run_pipe($porcelain->run);
    my $expect_sgf = slurp($args{expect_file});
    eq_or_diff $collection->[0]->as_sgf, $expect_sgf,
      "$args{name}: linear story SGF";
    return $collection;
}
porcelain_ok(
    name        => 'k14-ch02-leaning-01',
    story_file  => 't/porcelain/linear_story/k14-ch02-leaning-01-story.json',
    expect_file => 't/porcelain/linear_story/k14-ch02-leaning-01-expect.sgf'
);
done_testing;
