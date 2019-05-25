package GoGameTools::Test;
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use GoGameTools::GenerateProblems::Viewer::Glift;
use Test::Differences;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(gen_problems_ok);
}

sub gen_problems_ok ($testname, $input, $expect) {
    my $collection = parse_sgf($input);
    $collection = pipe_convert_markup_to_directives()->($collection);
    my $problems = pipe_gen_problems(
        viewer_delegate => GoGameTools::GenerateProblems::Viewer::Glift->new)
      ->($collection);

    # add tags to GC[] so comparisons are easier
    for my $problem ($problems->@*) {
        my @tags = $problem->metadata->{tags}->@*;
        $problem->get_node(0)->add(GC => join ' ', @tags) if @tags;
    }

    # Normalize to generated SGF, for comparison. Use newline for the node
    # separator so differences between got and expected are easier to see.
    my $got = join "\n", map { $_->as_sgf("\n") } $problems->@*;
    1 while chomp $got;
    1 while chomp $expect;
    unified_diff();
    eq_or_diff($got, $expect, $testname);
    warn $got unless $got eq $expect;    # for debugging
}
1;
