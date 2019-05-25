package GoGameTools::features;
use strict;
use warnings;
use feature ();
use 5.20.2;
use re '/a';
use open qw(:std :utf8);

sub import {
    my $package = (caller)[0];
    warnings->import;
    strict->import;
    feature->import(':5.20');
    feature->import('signatures');
    warnings->unimport('experimental::signatures');
    feature->import('postderef');
    warnings->unimport('experimental::postderef');
    feature->import('lexical_subs');
    warnings->unimport('experimental::lexical_subs');
    warnings->unimport('recursion');    # some SGF trees can be deep
    re->import('/a');
}
1;
