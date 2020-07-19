package GoGameTools::Parser::SGF;
use GoGameTools::features;
use GoGameTools::Tree;
use GoGameTools::Node;
use GoGameTools::Coordinate;
use GoGameTools::Log;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(parse_sgf);
}
our $FROM_SGF = qr{
    (?(DEFINE)
        (?<COLLECTION>
            (?{ [$^R, []] })
            \p{Whitespace}*
            (?:
                (?:
                    \p{Whitespace}* (?&NODELIST)
                )
                (?{ [$^R->[0][0], [$^R->[0][1]->@*, GoGameTools::Tree->new(tree => $^R->[1])]] })
            )+ (*PRUNE)
            \p{Whitespace}*
        )

        (?<NODELIST>
            (?{ [$^R, []] })
            \p{Whitespace}* \(
            (?:
                (?:
                    \p{Whitespace}* ; (?&NODE) | (?&NODELIST)
                )
                (?{ [$^R->[0][0], [$^R->[0][1]->@*, $^R->[1]]] })
            )* (*PRUNE)
            \) \p{Whitespace}*
        )

        # A node is a list of properties
        (?<NODE>
            (?{ [$^R, GoGameTools::Node->new ] })
            (?:
                \p{Whitespace}*

                (
                    # single value with point
                    (?<name1> B | W)
                    \p{Whitespace}*
                    \[ ((?: [a-s]{2} | tt )?) \]
                    (?{ $^R->[1]{properties}{ $+{name1} } = $^N; $^R })
                |
                    # list of composites values, each having a point or a rectangle
                    (?<name2> AB | AW | AE | TB | TW | TR | SQ | MA | CR | SL | DD | VW)
                    (?:
                        \p{Whitespace}*
                        \[ ([a-s]{2} (?: : [a-s]{2} )? ) \]
                        (?{ push $^R->[1]{properties}{ $+{name2} }->@* => coord_expand_rectangle($^N); $^R })
                    )+
                |
                    # list of composites values, each having two points
                    (?<name3> LN | AR)
                    (?:
                        \p{Whitespace}*
                        \[ (?<value3a> [a-s]{2}) : (?<value3b> [a-s]{2}) \]
                        (?{ push $^R->[1]{properties}{ $+{name3} }->@* => [ $+{value3a}, $+{value3b} ]; $^R })
                    )+
                |
                    # list of composites values, each having a point and a text
                    LB
                    (?:
                        \p{Whitespace}*
                        \[ (?<value4a> [a-s]{2}) : (?<value4b> .*?) \]
                        (?{ push $^R->[1]{properties}{LB}->@* => [ $+{value4a}, $+{value4b} ]; $^R })
                    )+
                |
                    # single value text that can contain escaped characters
                    (?<name5> C | GC | FF | GM | SZ | N | AP | HA | ST | PW | PB |
                        WR | BR | DT | EV | RO | PC | KM | TM | RU | RE | OT | CA |
                        WL | BL | OW | OB | KO | MN | PL | DM | GW | GB | HO |
                        UC | V | BM | DO | IT | TE | FG | PM | HA | GN | AN)
                    \p{Whitespace}*
                    \[ ( (?:\\. | [^\\])*? ) \]
                    (?{ $^R->[1]{properties}{ $+{name5} } = $^N; $^R })
                |
                    # Treat all other properties as multi-valued text that can
                    # contain escaped characters
                    (?<name6> \w+)
                    (?:
                        \p{Whitespace}*
                        \[ ( (?:\\. | .)*? ) \]
                        (?{ push $^R->[1]{properties}{ $+{name6} }->@* => $^N; $^R })
                    )+
                )

            )* (*PRUNE)
            \p{Whitespace}*
            # (?{ use DDP; p $^R->[1]; $^R })    # debug: show matched node
        )
    )

    (?&COLLECTION) \Z
}sox;

sub parse_sgf ($sgf, $options = {}) {
    my %options = (name => 'SGF string', strict => 1, %$options);
    local $^R;
    if ($sgf =~ m{$FROM_SGF}) {
        my $collection = $^R->[1];
        if ($options{strict}) {
            while (my ($index, $tree) = each $collection->@*) {
                my $root = $tree->get_node(0);
                my $GM   = $root->get('GM');
                my $FF   = $root->get('FF');
                unless (defined($GM) && $GM eq '1') {
                    fatal(sprintf "%s index %s: %s",
                        $options{name}, $index, 'root node does not have GM[1]');
                }
                unless (defined($FF) && $FF eq '4') {
                    fatal(sprintf "%s index %s: %s",
                        $options{name}, $index, 'root node does not have FF[4]');
                }
            }
        }
        return $collection;
    }
    return;    # undef if it didn't match
}
1;

=pod

=head1 NAME

GoGameTools::Parser::SGF - Tools for the board game

=head1 SYNOPSIS

    use open qw(:std :utf8);
    use GoGameTools::Parser::SGF;

    my $input = do { local $/; <> };
    my $trees = parse_sgf($input);

=head1 DESCRIPTION

This is a parser for SGF files used to represent games of GoGameTools, also known as
Go, Igo and Weiqi. There are several SGF parsers, but the special feature of
this one is that it uses a grammar contained in a single regular expression. It
also has no non-core dependencies. The technique for building up the result was
inspired by Randal Schwartz' JSON parser, described in L<Mastering
Perl|http://chimera.labs.oreilly.com/books/1234000001527/ch02.html>.

At the moment, this is a proof-of-concept; the parser just creates a simple
nested data structure.

