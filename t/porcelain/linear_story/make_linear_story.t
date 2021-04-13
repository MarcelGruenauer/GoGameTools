#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Plumbing;
use GoGameTools::Util;
use GoGameTools::Porcelain::MakeLinearStory;
use Test::More;
use Test::Differences;

sub porcelain_ok (%args) {
    subtest $args{name} => sub {
        my $porcelain = GoGameTools::Porcelain::MakeLinearStory->new(
            story_file  => $args{story_file},
            output_file => 'result.sgf'
        );
        my ($collection) = run_pipe($porcelain->run);
        my $expect_sgf = slurp($args{expect_file});
        eq_or_diff $collection->[0]->as_sgf, $expect_sgf, 'linear story SGF';
        return $collection;
    }
}

# Use the story file that has explicit "path" and "node" instructions.
porcelain_ok(
    name        => 'k14-ch02-leaning-01 with "path" and "node"',
    story_file  => 't/porcelain/linear_story/k14-ch02-leaning-01-path-story.json',
    expect_file => 't/porcelain/linear_story/k14-ch02-leaning-01-expect.sgf'
);

# Use the story file that has the "traverse" instruction.
porcelain_ok(
    name       => 'k14-ch02-leaning-01 with "traverse"',
    story_file =>
      't/porcelain/linear_story/k14-ch02-leaning-01-traverse-story.json',
    expect_file => 't/porcelain/linear_story/k14-ch02-leaning-01-expect.sgf'
);
done_testing;
