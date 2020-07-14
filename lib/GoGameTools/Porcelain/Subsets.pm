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
    my $subset_query =
      join ' and ' =>
      (defined $subset->{with_ref}    ? ('@' . $subset->{with_ref})        : ()),
      (defined $subset->{without_ref} ? ('not @' . $subset->{without_ref}) : ()),
      (defined $subset->{with_tag}    ? ('#' . $subset->{with_tag})        : ()),
      (defined $subset->{without_tag} ? ('not #' . $subset->{without_tag}) : ());
    if (length $subset_query) {
        my $expr = parse_filter_query($subset_query);
        return [ grep { eval_query(expr => $expr, vars => $_->{vars}) } $problems->@* ];
    } else {

        # this subset has no restrictions; used for 'All' quasi-subsets
        return $problems;
    }
}
1;
