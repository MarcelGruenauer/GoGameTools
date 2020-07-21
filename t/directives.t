#!/usr/bin/env perl
use GoGameTools::features;
use Test::More;
use Test::Differences;
use GoGameTools::Node;
use GoGameTools::TagHandler;
register_tags();
my $node = GoGameTools::Node->new;
subtest extract_directives => sub {
    my @t = (
        [ 'copy', '{{ copy }}', { copy => 1 }, [], [], '' ],
        [   'remainder 1',
            "before {{ copy }} \nafter \n ",
            { copy => 1 },
            [], [], "before  \nafter"
        ],
        [   'remainder 2', "before\n{{ copy }}\nafter ",
            { copy => 1 }, [],
            [], "before\n\nafter"
        ],
        [ 'remainder 3', "{{ copy }}\nrem ", { copy => 1 }, [], [], "rem" ],
        [ 'remainder 4', "rem\n{{ copy }} ", { copy => 1 }, [], [], "rem" ],
        [   'answer with one-line content',
            '{{ answer Black has 14 points. }}',
            { answer => 'Black has 14 points.' },
            [], [], ''
        ],
        [   'condition with multi-line content',
            "{{ condition foo\n\nBar }}",
            { condition => "foo\n\nBar" },
            [], [], ''
        ],
        [   'copy with leading and trailing whitespce around the directive',
            " \n  \n {{ copy }}  \n \n ",
            { copy => 1 },
            [], [], ''
        ],
        [   'condition with extra whitespce inside the directive',
            "{{ condition  \n  \n foo\n\nBar  \n \n  }}",
            { condition => "foo\n\nBar" },
            [], [], ''
        ],
        [   'multiple directives',
            "{{ answer foo }}\n{{ copy }}",
            { answer => 'foo', copy => 1 },
            [], [], ''
        ],
        [   'multiple note directives',
            "{{ note foo }}\n{{ note bar }}",
            { note => 'bar' },
            [], [], ''
        ],
        [   'tags', "{{ tags attacking defending }}",
            {}, [qw(attacking defending)],
            [], ''
        ],
        [   'refs', "{{ ref foo/bar/3 }}{{ ref baz/4/5 }}",
            {}, [], [qw(foo/bar/3 baz/4/5)], ''
        ],
    );
    for my $t (@t) {
        my ($test_name, $input, $directives, $tags, $refs, $remainder) = $t->@*;
        my %expect = (
            directives => $directives,
            tags       => $tags,
            refs       => $refs,
            remainder  => $remainder
        );
        my $result = $node->extract_directives($input);
        eq_or_diff $result, \%expect, $test_name;
    }
};
subtest 'exceptions from extract_directives' => sub {
    eval { $node->extract_directives("{{ copy }}\n{{ copy }}") };
    like $@,
      qr/directive \{\{ copy }} defined more than once in the same node/,
      'directive occurs twice';
    eval { $node->extract_directives("{{ foo }}") };
    like $@, qr/invalid directive \{\{ foo }}/, 'invalid directive';
};
subtest convert_directives_from_comment => sub {
    subtest no_remaining_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->add(C => '{{ answer Foo }}');
        $node->convert_directives_from_comment;
        eq_or_diff $node->directives->{answer}, 'Foo', 'answer Foo';
        is scalar($node->get('C')), undef, 'no remaining comment';
    };
    subtest remaining_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->add(C => '{{ answer Foo }} Bar');
        $node->convert_directives_from_comment;
        eq_or_diff $node->directives->{answer}, 'Foo', 'answer Foo';
        is scalar($node->get('C')), 'Bar', 'remaining comment';
    };
    subtest node_without_comment => sub {
        my $node = GoGameTools::Node->new;
        $node->convert_directives_from_comment;
        ok !$node->has('C'), 'still no comment';
    };
};
done_testing;
