#!/usr/bin/env perl
use GoGameTools::features;
use Test::More;
use GoGameTools::Config;
use GoGameTools::Parser::SGF;
my $bad_sgf = "(;SZ[19];B[ab])";    # no "GM[1]FF[4]"
eval { parse_sgf(sgf => $bad_sgf); };
ok index($@, 'root node does not have GM[1]') != -1,
  'strict parsing of SGF without GM[1]FF[4]';
my $config = GoGameTools::Config->get_global_config;
$config->set(strict => 0);
eval { parse_sgf(sgf => $bad_sgf); };
is $@, '', 'non-strict parsing of SGF without GM[1]FF[4]';
done_testing;
