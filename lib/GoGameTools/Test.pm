package GoGameTools::Test;
use GoGameTools::features;
use GoGameTools::Parser::SGF;
use GoGameTools::Plumbing;
use GoGameTools::GenerateProblems::Viewer::WGo;
use Test::Differences;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(gen_problems_ok);
}

sub gen_problems_ok ($testname, $input, $expect) {
    my $collection = parse_sgf($input);
    $collection = pipe_convert_markup_to_directives()->($collection);
    $collection = pipe_convert_directives_from_comment()->($collection);
    my @warnings;
    my $problems = pipe_gen_problems(
        viewer_delegate => GoGameTools::GenerateProblems::Viewer::WGo->new,
        on_warning => sub ($message) { push @warnings, $message })
      ->($collection);
    # @warnings will contains only 'problem has no tags in file ? index ?' messages

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
