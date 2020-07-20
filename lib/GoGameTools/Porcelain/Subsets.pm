package GoGameTools::Porcelain::Subsets;
use GoGameTools::features;
use GoGameTools::Parser::FilterQuery;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(get_problems_for_subset);
}

# Given a subset definition and a problem collection, return the subset of
# problems that correspond to the subset definition.
sub get_problems_for_subset ($subset, $problems) {
    my @remaining = $problems->@*;

    # gradually restrict the resulting list
    if (defined(my $tag = $subset->{with_tag})) {
        @remaining = grep { exists $_->{vars}{tags}{$tag} } @remaining;
    }
    if (defined(my $tag = $subset->{without_tag})) {
        @remaining = grep { !exists $_->{vars}{tags}{$tag} } @remaining;
    }
    if (defined(my $ref = $subset->{with_ref})) {
        @remaining = grep { exists $_->{vars}{refs}{$ref} } @remaining;
    }
    if (defined(my $ref = $subset->{without_ref})) {
        @remaining = grep { !exists $_->{vars}{refs}{$ref} } @remaining;
    }

    # if you have a more complex query you can use 'filter'
    if (defined(my $filter = $subset->{filter})) {
        my $expr = parse_filter_query($filter)
          // die "can't parse filter query $filter\n";
        @remaining =
          grep { eval_query(expr => $expr, vars => $_->{vars}) } @remaining;
    }
    return \@remaining;
}
1;
