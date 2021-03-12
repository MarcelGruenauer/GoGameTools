requires 'perl', '5.020000';

requires 'App::ForkProve';
requires 'lib::require::all';
requires 'Data::Printer';
requires 'Path::Tiny';
requires 'Digest::SHA';
requires 'Archive::Zip';
requires 'Imager';
requires 'Expect';

on test => sub {
    requires 'Test::More', '0.94';
    requires 'Test::Differences';
};
