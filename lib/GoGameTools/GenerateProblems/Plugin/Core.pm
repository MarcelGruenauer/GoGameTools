package GoGameTools::GenerateProblems::Plugin::Core;
use GoGameTools::features;
use GoGameTools::Class;

# Directives handled by GoGameTools::GenerateProblems itself; not specific to
# any plugin.
my %is_core_directives = map { $_ => 1 } qw(
  guide correct tags barrier num ref user_is_guided note
);

sub handles_directive ($self, %args) {
    return $is_core_directives{ $args{directive} };
}
1;
