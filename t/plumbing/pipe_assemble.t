#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use Test::More;
use Test::Differences;
my %files;
$files{'common_subtrees-input'} = <<'EODATA';
(;GM[1]FF[4]SZ[19];B[ab];W[cd](;B[ef];W[gh])(;B[ef];W[jk]))
EODATA
$files{'common_subtrees-expect'} = <<'EODATA';
(;GM[1]FF[4]SZ[19];B[ab];W[cd];B[ef](;W[gh])(;W[jk]))
EODATA
$files{'collection-input'} = <<'EODATA';
(;GM[1]FF[4]SZ[19];B[ab];W[cd];B[ef];W[jk])
(;GM[1]FF[4]SZ[19];B[ab];W[cd];B[ef];W[gh])
EODATA
$files{'collection-expect'} = <<'EODATA';
(;GM[1]FF[4]SZ[19];B[ab];W[cd];B[ef](;W[gh])(;W[jk]))
EODATA
assemble_ok($_) for qw(common_subtrees collection);
done_testing;

sub assemble_ok ($prefix) {
    my $got_sgf    = pipe_assemble()->(parse_sgf($files{"$prefix-input"}))->[0]->as_sgf;
    my $expect_sgf = parse_sgf($files{"$prefix-expect"})->[0]->as_sgf;
    eq_or_diff($got_sgf, $expect_sgf, $prefix);
}
