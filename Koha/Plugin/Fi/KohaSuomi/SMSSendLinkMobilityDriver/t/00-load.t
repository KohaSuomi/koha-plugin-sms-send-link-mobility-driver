#!perl -T
use Modern::Perl;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'SMS::Send::LinkMobility::Driver' ) || print "Bail out!\n";
}

diag( "Testing SMS::Send::LinkMobility::Driver $SMS::Send::LinkMobility::Driver::VERSION, Perl $], $^X" );