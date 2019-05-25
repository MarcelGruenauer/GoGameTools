requires 'perl', '5.020000';

requires 'List::Util';
requires 'Path::Tiny';
requires 'Digest::SHA';
requires 'Archive::Zip';

on test => sub {
    requires 'Test::More', '0.94';
    requires 'Test::Differences';
};
