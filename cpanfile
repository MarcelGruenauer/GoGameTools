requires 'perl', '5.020000';

requires 'Path::Tiny';
requires 'Archive::Zip';
requires 'Imager';
requires 'Expect';

on test => sub {
    requires 'Test::More', '0.94';
    requires 'Test::Differences';
    requires 'App::ForkProve';
    requires 'lib::require::all';
    requires 'Data::Printer';   # actually only for debugging
};
