#!/usr/bin/env perl
use GoGameTools::features;
use Test::More;
use Test::Differences;
use GoGameTools::TagHandler;
use GoGameTools::Node;
register_tags();
subtest expand_tag_name => sub {
    my @t = (
        [ [qw(making_a_position)], [qw(making_a_position objective opening)] ],
        [   [qw(loose_ladder ddk2)],
            [   qw(loose_ladder squeezing capturing_key_stones defending
                  level ddk2 tactics)
            ]
        ],

        # test redundant tags
        [ [qw(monkey_jump driving)], [qw(monkey_jump driving tactics)] ],
    );
    for my $t (@t) {
        my ($input, $expect) = $t->@*;
        my %seen;
        my @got = sort grep { !$seen{$_}++ } map { expand_tag_name($_) } $input->@*;
        eq_or_diff \@got, [ sort $expect->@* ], join(' ', $input->@*);
    }
};
subtest convert_directives_from_comment => sub {
    subtest no_remaining_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->add(C => '{{ tags counteratari level }}');
        $node->convert_directives_from_comment;
        eq_or_diff [node_tags($node)], [ sort qw(counteratari level) ], 'tags[]';
        is scalar($node->get('C')), undef, 'no remaining comment';
    };
    subtest remaining_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->add(C => "{{ tags counteratari level }}\nThe group is dead.");
        $node->convert_directives_from_comment;
        eq_or_diff [node_tags($node)], [ sort qw(counteratari level) ], 'tags[]';
        is scalar($node->get('C')), 'The group is dead.', 'remaining comment';
    };
    subtest node_without_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->convert_directives_from_comment;
        eq_or_diff [node_tags($node)], [], 'no tags[]';
        ok !$node->has('C'), 'still no comment';
    };
};
done_testing;

sub node_tags ($node) {
    # temp var due to sort()
    my @tags = sort map { $_->as_spec } $node->tags->@*;
    return @tags;
}
