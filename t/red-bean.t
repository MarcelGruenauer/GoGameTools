#!/usr/bin/env perl
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use Test::More;
use Test::Differences;

# Assume we are dealing with single games, not collections, so ->[0] works.
sub tree_ok ($input, $expect, $name = undef) {
    $name //= $input =~ s/\s+/ /gr;
    my $collection = parse_sgf($input, { strict => 0 });
    if (defined $collection) {
        eq_or_diff($collection->[0]->tree, $expect, $name);
    } else {
        fail("$name: parser error");
    }
}

sub sgf_roundtrip_ok ($input, $expect, $name) {
    $name //= $input;
    my $got = parse_sgf($input)->[0]->as_sgf;
    eq_or_diff($got, $expect, $name);
}

sub en {
    bless {}, 'GoGameTools::Node';
}    # empty node

sub n ($h) {
    bless { properties => { $h->%* } }, 'GoGameTools::Node';
}

# tree_ok('()', 'variation must have at least one node');
# tree_ok('(W[tt])', 'properties are part of a node');
tree_ok('(;)', [ en() ], 'smallest possible variation');
tree_ok(
    '(;;;(;;;;)(;;)(;;;(;;)(;)))',
    [   en(), en(), en(),
        [ en(), en(), en(), en() ],
        [ en(), en() ],
        [ en(), en(), en(), [ en(), en() ], [ en() ] ]
    ],
    'variation of a variation without properties'
);
tree_ok(
    "(;C[Line 1\nLine 2])",
    [ n({ C => "Line 1\nLine 2" }) ],
    'multiline comment'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];LB[aa:1][bb:2][cc:3]W[bb];B[cc])',
    [   n(  {   GM => 1,
                FF => 4,
                SZ => 19
            }
        ),
        n({ B => 'aa' }),
        n(  {   W  => 'bb',
                LB => [ [qw(aa 1)], [qw(bb 2)], [qw(cc 3)] ]
            }
        ),
        n({ B => 'cc' })
    ],
    'multiple property values'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];W[bb];B[cc];W[dd];B[ad];W[bd])',
    [   n(  {   FF => 4,
                GM => 1,
                SZ => 19
            }
        ),
        n({ B => 'aa' }),
        n({ W => 'bb' }),
        n({ B => 'cc' }),
        n({ W => 'dd' }),
        n({ B => 'ad' }),
        n({ W => 'bd' })
    ],
    'no variation'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd];B[ad];W[bd])
            (;B[hh];W[hg]))',
    [   n(  {   FF => 4,
                GM => 1,
                SZ => 19
            }
        ),
        n({ B => 'aa' }),
        n({ W => 'bb' }),
        [ n({ B => 'cc' }), n({ W => 'dd' }), n({ B => 'ad' }), n({ W => 'bd' }) ],
        [ n({ B => 'hh' }), n({ W => 'hg' }) ]
    ],
    'one variation at move 3'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc]N[Var A];W[dd];B[ad];W[bd])
            (;B[hh]N[Var B];W[hg])
            (;B[gg]N[Var C];W[gh];B[hh];W[hg];B[kk]))',
    [   n(  {   SZ => '19',
                FF => 4,
                GM => 1
            }
        ),
        n({ B => 'aa' }),
        n({ W => 'bb' }),
        [   n(  {   N => 'Var A',
                    B => 'cc'
                }
            ),
            n({ W => 'dd' }),
            n({ B => 'ad' }),
            n({ W => 'bd' })
        ],
        [   n(  {   B => 'hh',
                    N => 'Var B'
                }
            ),
            n({ W => 'hg' })
        ],
        [   n(  {   B => 'gg',
                    N => 'Var C'
                }
            ),
            n({ W => 'gh' }),
            n({ B => 'hh' }),
            n({ W => 'hg' }),
            n({ B => 'kk' })
        ]
    ],
    'two variations at move 3'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc];W[dd](;B[ad];W[bd])
                (;B[ee];W[ff]))
            (;B[hh];W[hg]))',
    [   n(  {   GM => 1,
                FF => 4,
                SZ => '19'
            }
        ),
        n({ B => 'aa' }),
        n({ W => 'bb' }),
        [   n({ B => 'cc' }),
            n({ W => 'dd' }),
            [ n({ B => 'ad' }), n({ W => 'bd' }) ],
            [ n({ B => 'ee' }), n({ W => 'ff' }) ]
        ],
        [ n({ B => 'hh' }), n({ W => 'hg' }) ]
    ],
    'two variations at different moves'
);
tree_ok(
    '(;FF[4]GM[1]SZ[19];B[aa];W[bb](;B[cc]N[Var A];W[dd];B[ad];W[bd])
            (;B[hh]N[Var B];W[hg])
            (;B[gg]N[Var C];W[gh];B[hh]  (;W[hg]N[Var A];B[kk])  (;W[kl]N[Var B])))',
    [   n(  {   GM => 1,
                FF => 4,
                SZ => '19'
            }
        ),
        n({ B => 'aa' }),
        n({ W => 'bb' }),
        [   n(  {   B => 'cc',
                    N => 'Var A'
                }
            ),
            n({ W => 'dd' }),
            n({ B => 'ad' }),
            n({ W => 'bd' })
        ],
        [   n(  {   N => 'Var B',
                    B => 'hh'
                }
            ),
            n({ W => 'hg' })
        ],
        [   n(  {   N => 'Var C',
                    B => 'gg'
                }
            ),
            n({ W => 'gh' }),
            n({ B => 'hh' }),
            [   n(  {   N => 'Var A',
                        W => 'hg'
                    }
                ),
                n({ B => 'kk' })
            ],
            [   n(  {   W => 'kl',
                        N => 'Var B'
                    }
                )
            ]
        ]
    ],
    'variation of a variation'
);
tree_ok(
    '(;AB[cd]
        [ef]AB[gh])',
    [ n({ AB => [ 'cd', 'ef', 'gh' ] }) ],
    'same property more than once and newline between values'
);
tree_ok('x(;TR[cd])', [ n({ TR => ['cd'] }) ], 'leading garbage');
subtest escapes => sub {
    tree_ok('(;C[foo [9k\]: bar]TR[cd])',
        [ n({ C => 'foo [9k\]: bar', TR => ['cd'] }) ]);
    tree_ok('(;C[So scary \\:\\\\]B[ll])',
        [ n({ C => 'So scary \:\\\\', B => 'll' }) ]);
    tree_ok('(;C[\];B[aa];W[bb])', [ n({ C => '\\];B[aa' }), n({ W => 'bb' }) ]);
    tree_ok('(;C[\\\\];B[aa];W[bb])',
        [ n({ C => '\\\\' }), n({ B => 'aa' }), n({ W => 'bb' }) ]);
  TODO: {
        local $TODO = 'escaped backslash + escaped closing bracket not working';
        tree_ok('(;C[\\\];B[aa];W[bb])', [ n({ C => '\\];B[aa' }), n({ W => 'bb' }) ]);
    }
    tree_ok('(;C[\\\\];B[aa];W[bb])',
        [ n({ C => '\\\\' }), n({ B => 'aa' }), n({ W => 'bb' }) ]);
};
subtest 'invalid SGF' => sub {
    is parse_sgf('(;AW[cd];B[gh]x;W[gk])'), undef,
      "can't parse invalid characters after properties";
    is parse_sgf('(;AW[cd];B[gh];W[gk])x'), undef,
      "can't parse invalid trailing characters";
};
done_testing;
