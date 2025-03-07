#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use C4::Context;
use File::Spec;
use YAML;
use Test::Mojo;
use Koha::Database;
use C4::Letters;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $t = Test::Mojo->new('Koha::REST::V1');

my $sms_send_config = C4::Context->config('sms_send_config');
my $config_file = File::Spec->catfile($sms_send_config, 'MyLink/Driver.yaml');

unless (-e $config_file) {
    plan skip_all => 'Configuration file not found in: '.$config_file;
} else {
    plan tests => 2;
}

my $config = YAML::LoadFile($config_file);

subtest 'Check configuration file' => sub {
    plan tests => 4;

    ok(defined $config, 'Config file is defined');
    ok(defined $config->{callbackAPIKey}, 'Callback API key is defined');
    ok(defined $config->{callbackURLs}, 'Callback URLs are defined');
    ok(ref $config->{callbackURLs} eq 'ARRAY', 'Callback URLs is an array');
};

subtest 'callback API()' => sub {
    plan tests => 14;

    my $schema = Koha::Database->new->schema;
    $schema->storage->txn_begin;

    my $builder = t::lib::TestBuilder->new;
    my $patron = $builder->build( { source => 'Borrower' } );

    my $my_message = {
        borrowernumber         => $patron->{borrowernumber},
        subject                => 'Test message',
        message                => 'This is a test message',
        message_transport_type => 'sms',
        to_address             => undef,
        from_address           => 'from@example.com',
    };
    $my_message->{letter} = {
        content      => 'This is a test message',
        title        => 'Test message',
        metadata     => 'metadata',
        code         => 'TEST_MESSAGE',
        content_type => 'text/plain',
    };
    my $message_id = C4::Letters::EnqueueLetter($my_message);
    ok(defined $message_id && $message_id > 0, 'Message enqueued');

    my $api_key = $config->{callbackAPIKey};

    ## Send a POST request to the callback API with the API key
    $t->post_ok( "/api/v1/contrib/kohasuomi/notices/callback/linkmobility" => json => test_body({status => {code => 2000}}))
      ->status_is(200);
    ## Send a POST request to the callback API with the wrong API key
    $t->post_ok( "/api/v1/contrib/kohasuomi/notices/callback/linkmobility" => { 'X-KOHA-LINK' => "1234" } => json => test_body({status => {code => 2000}}))
      ->status_is(200);
    ## Send a POST request to the callback API with the correct API key
    $t->post_ok( "/api/v1/contrib/kohasuomi/notices/callback/linkmobility" => { 'X-KOHA-LINK' => $api_key } => json => test_body({status => {code => 2000}}))
      ->status_is(200);

    ## Send a POST request to the callback API with the correct API key and a message that failed
    $t->post_ok( "/api/v1/contrib/kohasuomi/notices/callback/linkmobility" => { 'X-KOHA-LINK' => $api_key } => json => test_body({status => {code => 3000, referenceId => $message_id}}))
      ->status_is(200);

    my $notice = Koha::Notice::Messages->find($message_id);
    ok(defined $notice, 'Notice found');
    is($notice->status, 'failed', 'Notice status is failed');
    is($notice->failure_code, 'string', 'Failure code is string');

    ## Send a POST request to the callback API with the correct API key and a wrong message ID
    $t->post_ok( "/api/v1/contrib/kohasuomi/notices/callback/linkmobility" => { 'X-KOHA-LINK' => $api_key } => json => test_body({status => {code => 3000, referenceId => $message_id + 1}}))
      ->status_is(200);

    $schema->storage->txn_rollback;
};

sub test_body {
    (my $replace_values) = @_;
    
    my $request = {
        eventId => "d6703cc8-9e79-415d-ac03-a4dc7f6ab43c",
        channel => "sms",
        recipient => "string",
        timeStamp => "2019-08-24T14:15:22Z",
        status => {
            requestId => "d385ab22-0f51-4b97-9ecd-b8ff3fd4fcb6",
            referenceId => "string",
            messageId => "8540d774-4863-4d2b-b788-4ecb19412e85",
            type => "string",
            code => 0,
            details => "string",
            segments => 0
        },
        provider => {
            timestamp => "2019-08-24T14:15:22Z",
            code => "string",
            details => "string",
            operator => "string"
        }
    };

    if ($replace_values) {
        for my $key (keys %$replace_values) {
            if (ref $request->{$key} eq 'HASH') {
                for my $subkey (keys %{$replace_values->{$key}}) {
                    $request->{$key}->{$subkey} = $replace_values->{$key}->{$subkey} if exists $request->{$key}->{$subkey};
                }
            } else {
                $request->{$key} = $replace_values->{$key} if exists $request->{$key};
            }
        }
    }

    return [$request]; 
}


done_testing();
