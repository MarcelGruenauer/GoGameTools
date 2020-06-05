package GoGameTools::GenerateProblems::PluginHandler;
use GoGameTools::features;
use GoGameTools::Log;
my @plugin_names = qw(
  Core GoodMove BadMove Answer Status ShowChoices RateChoices Deter
  CorrectForBoth Ladder HasAllGoodResponses Copy Tenuki Assemble
  IsResponse AddSetup Condition Check
);

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(call_on_plugins);
}
my @plugins;
for (@plugin_names) {
    my $class = "GoGameTools::GenerateProblems::Plugin::$_";
    eval "require $class";
    fatal($@) if $@;
    push @plugins, $class->new;
}

# Separate method so we can trace calls. Some plugin methods don't return a
# value but some do, so collect all results and return them as a list; the
# caller can then choose whether to use them.
#
# Endure a small lookup cost to make the debug output less verbose.
sub call_on_plugins ($method, %args) {
    my @plugins_can = grep { $_->can($method) } @plugins;
    if ($ENV{GOGAMETOOLS_DEBUG}) {
        warn sprintf "\n\nplugin call %s() on %s\n", $method, join ', ',
          map { ref($_) =~ s/.*:://r } @plugins_can;
        use DDP; p %args;
    }
    my @results = map { $_->$method(%args) } @plugins_can;
    return @results;
}
1;
