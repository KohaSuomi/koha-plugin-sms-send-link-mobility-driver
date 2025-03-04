#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use SMS::Send::MyLink::Driver;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => 'http://localhost:5001/');
my $res = $ua->request($req);

unless ($res->is_success) {
    plan skip_all => 'Test server not running! Start it: plackup -p 5001 t/app.psgi';
    exit;
} else {
    plan tests => 5;
}

# Create an instance of the Driver
my $driver = SMS::Send::MyLink::Driver->new(
    _client_id => 'client_id',
    _client_secret => 'client_secret',
    _baseUrl => 'http://localhost:5001/sms/v1/messages',
    _authUrl => 'http://localhost:5001/auth/token',
);

is($driver, undef, 'Missing required parameters');

# Create an instance of the Driver
$driver = SMS::Send::MyLink::Driver->new(
    _client_id => 'client_id',
    _client_secret => 'client_secret',
    _baseUrl => 'http://localhost:5001/sms/v1/messages',
    _authUrl => 'http://localhost:5001/auth/token',
    _senderId => '12345',
    _cacheKey => 'link_cache_key'
);

# Test if the object is created
ok(defined $driver, 'Driver object created');

my $result = $driver->send_sms(to => undef, text => 'Test message');
is($result, undef, 'send_sms(to) missing');

$result = $driver->send_sms(to => '1234567890', text => undef);
is($result, undef, 'send_sms(text) missing');

$result = $driver->send_sms(to => '1234567890', text => 'Test message');
is($result, 1, 'send_sms method works');

done_testing();