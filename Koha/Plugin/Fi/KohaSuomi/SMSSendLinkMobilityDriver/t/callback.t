#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;
use C4::Context;
use File::Spec;
use YAML;

my $sms_send_config = C4::Context->config('sms_send_config');
my $config_file = File::Spec->catfile($sms_send_config, 'LinkMobility/Driver.yaml');
my $config = YAML::LoadFile($config_file);

ok(defined $config->{callbackAPIKey}, 'Callback API key is defined');
ok(defined $config->{callbackURLs}, 'Callback URLs are defined');
ok(ref $config->{callbackURLs} eq 'ARRAY', 'Callback URLs is an array');
done_testing();
