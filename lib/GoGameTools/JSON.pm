package GoGameTools::JSON;
use GoGameTools::features;
use GoGameTools::Log;

sub import {
    my $caller = caller();
    no strict 'refs';
    *{"${caller}::$_"} = *{$_}{CODE} for qw(json_encode json_decode);
}

# Mostly copied from JSON::MaybeXS.
sub _choose_json_module {
    return 'Cpanel::JSON::XS' if $INC{'Cpanel/JSON/XS.pm'};
    return 'JSON::XS'         if $INC{'JSON/XS.pm'};
    my @err;
    return 'Cpanel::JSON::XS' if eval { require Cpanel::JSON::XS; 1; };
    push @err, "Error loading Cpanel::JSON::XS: $@";
    return 'JSON::XS' if eval { require JSON::XS; 1; };
    push @err, "Error loading JSON::XS: $@";
    return 'JSON::PP' if eval { require JSON::PP; 1 };
    push @err, "Error loading JSON::PP: $@";
    fatal(join "\n", "Couldn't load a JSON module:", @err);
}

sub json_encode ($data, $args = {}) {
    our $JSON_Class //= _choose_json_module();
    $args->{pretty} //= 1;
    my $json_coder =
      $JSON_Class->new->allow_nonref->canonical(0)->pretty($args->{pretty});
    return $json_coder->encode($data);
}

sub json_decode ($json) {
    our $JSON_Class //= _choose_json_module();
    my $json_coder = $JSON_Class->new->allow_nonref->pretty;
    return $json_coder->decode($json);
}
1;

=head1 NAME

GoGameTools::JSON - Use L<Cpanel::JSON::XS> with a fallback to L<JSON::XS> and L<JSON::PP>

=head1 SYNOPSIS

  use GoGameTools::JSON;

  my $data_structure = json_decode($json_input);

  my $json_output = json_encode($data_structure);

=head1 DESCRIPTION

This module first checks to see if either L<Cpanel::JSON::XS> or
L<JSON::XS> is already loaded, in which case it uses that module. Otherwise
it tries to load L<Cpanel::JSON::XS>, then L<JSON::XS>, then L<JSON::PP>
in order, and either uses the first module it finds or throws an error.

It then exports the C<json_encode> and C<json_decode> functions that use the
chosen module.

=cut
