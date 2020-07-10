package GoGameTools::Parser::FilterQuery;
use GoGameTools::features;
use GoGameTools::Log;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(
      parse_filter_query
      eval_query
      query_vars_from_sgj);
}
sub add_token ($token) { [ $^R->@*, $token ] }
our $FROM_QUERY = qr{
    (?(DEFINE)
        (?<EXPRESSION>
            (?&TERM)
            (?:
                \s+ or
                (?{ add_token('||') })
                \s+ (?&TERM)
            )* (*PRUNE)
            \s*
        )

        (?<TERM>
            (?&FACTOR)
            (?:
                \s+ and
                (?{ add_token('&&') })
                \s+ (?&FACTOR)
            )* (*PRUNE)
        )

        (?<FACTOR>
            \s*
            (?:
                \#(?<tag> [\w-]+)
                (?{ add_token(qq# \$_[0]->{tags}{'$+{tag}'} #) })
            |
                not \s+ \#(?<tag> [\w-]+)
                (?{ add_token(qq# !\$_[0]->{tags}{'$+{tag}'} #) })
            |
                @(?<ref> [\w\/-]+)
                (?{ add_token(qq# \$_[0]->{refs}{'$+{ref}'} #) })
            |
                not \s+ @(?<ref> [\w\/-]+)
                (?{ add_token(qq# !\$_[0]->{refs}{'$+{ref}'} #) })
            |
                not
                (?{ add_token('!') })
                \s+
                (?&FACTOR)
            |
                \( \s*
                (?{ add_token('(') })
                (?&EXPRESSION)
                \s* \)
                (?{ add_token(')') })
            |
                (?<var> PB|PW|DT|PC|RE) \s* (?<op> = | != | < | <= | > | >= | like) \s* (?<value> '.*?')
                (?{ add_token(qq# condition(\$_[0]->{game_info}, '$+{var}', '$+{op}', $+{value}) #) })
            ) (*PRUNE)
        )

    )

    \A (?&EXPRESSION) \Z (?{ $_ = join(' ', $^R->@*) })
}ox;

sub parse_filter_query {
    local $_  = shift;
    local $^R = [];
    if (eval { m{$FROM_QUERY} }) {

        # Returning an evaluated anonymous subroutine means that we don't have
        # to re-eval the code for each single query. We can just call the
        # cached coderef. When doing this close to a million times this is
        # much, much faster.
        return eval "sub { $_ }";
    } else {
        fatal($@) if $@;
        return;    # undef if it didn't match
    }
}

sub eval_query (%args) {
    my $result = $args{expr}->($args{vars});

    # force a boolean value; coerce undef value and empty string
    $result //= 0;
    $result ||= 0;
    return $result;
}

sub query_vars_from_sgj ($sgj) {
    my %result;

    # A tree's metadata has tags and refs as array references; convert them to
    # lookup hashes. Also generate all stems for all refs so lookup is easier.
    # E.g., foo/bar/baz => foo, foo/bar, foo/bar/baz
    $result{tags}{$_} = 1 for $sgj->{metadata}{tags}->@*;
    for my $ref ($sgj->{metadata}{refs}->@*) {
        my $r = '';
        for my $part (split m!/!, $ref) {
            $r .= '/' if length $r;
            $r .= $part;
            $result{refs}{$r} = 1;
        }
    }

    # Add the game info so condition() calls can evaluate it. For example:
    #
    # "PW = 'foobar'" will check whether $sgj->{game_info}{PW} is 'foobar'
    $result{game_info} = $sgj->{game_info};
    return \%result;
}

# Helper function to evaluate conditions added by the grammar. It gets the
# whole game info hashref and the hash key so it can determine the value type.
# For example, "PB" is a string, while "DT" will be compared as a date.
#
# For 'DT', string comparison works assuming it's in the YYYY-MM-DD format.
my %type = (
    PB => 'string',
    PW => 'string',
    DT => 'string',
    PC => 'string',
    RE => 'string',
);

sub condition ($game_info, $key, $op, $value) {
    my $got = $game_info->{$key};
    return unless defined $got;    # condition evals to 'false'
    my $type = $type{$key} // die "$key: unknown type\n";
    if ($type eq 'string') {
        return eval_string_op($got, $op, $value);
    }
}

sub eval_string_op ($got, $op, $value) {
    if ($op eq '=') {
        return $got eq $value;
    } elsif ($op eq '!=') {
        return $got ne $value;
    } elsif ($op eq '>') {
        return $got gt $value;
    } elsif ($op eq '>=') {
        return $got ge $value;
    } elsif ($op eq '<') {
        return $got lt $value;
    } elsif ($op eq '<=') {
        return $got le $value;
    } elsif ($op eq 'like') {

        # 'like' sounds like the SQL 'LIKE', but so far here it is only a
        # substring search
        return index($got, $value) != -1;
    }
}
1;
