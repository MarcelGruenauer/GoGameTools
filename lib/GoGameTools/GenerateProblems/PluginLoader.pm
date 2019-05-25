package GoGameTools::GenerateProblems::PluginLoader;
use GoGameTools::features;
use GoGameTools::Log;
my @plugin_names = qw(
  Core GoodMove BadMove Answer Status ShowChoices RateChoices Deter
  CorrectForBoth Ladder HasAllGoodResponses Copy Tenuki Assemble Debug
  GameInfo IsResponse AddSetup Condition Check
);
my @plugins;
for (@plugin_names) {
    my $class = "GoGameTools::GenerateProblems::Plugin::$_";
    eval "require $class";
    fatal($@) if $@;
    push @plugins, $class->new;
}
sub plugins { @plugins }
1;
