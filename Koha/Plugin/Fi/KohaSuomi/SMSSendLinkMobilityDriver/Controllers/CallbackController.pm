package Koha::Plugin::Fi::KohaSuomi::SMSSendLinkMobilityDriver::Controllers::CallbackController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;
use Koha::Notice::Messages;
use C4::Context;
use YAML;
use File::Spec;
use Log::Log4perl;
use Data::Dumper;
use File::Basename;

=head1 API

=cut

=head2 callback example

    This is the callback example found in the Link Mobility API documentation. Despite the documentation the body is an array of objects.

    [{
        "eventId": "d6703cc8-9e79-415d-ac03-a4dc7f6ab43c",
        "channel": "sms",
        "recipient": "string",
        "timeStamp": "2019-08-24T14:15:22Z",
        "status": {
            "requestId": "d385ab22-0f51-4b97-9ecd-b8ff3fd4fcb6",
            "referenceId": "string",
            "messageId": "8540d774-4863-4d2b-b788-4ecb19412e85",
            "type": "string",
            "code": 0,
            "details": "string",
            "segments": 0
        },
        "provider": {
            "timestamp": "2019-08-24T14:15:22Z",
            "code": "string",
            "details": "string",
            "operator": "string"
        }
    }]

=cut

sub delivery {
    my $c = shift->openapi->valid_input or return;

    my $logger = _get_logger();
    my $token = $c->param('token');
    if ($token ne _get_config_token()) {
        $logger->error("Unauthorized callback received with body: " . Dumper($c->req->json));
        return $c->render(status => 200, text => '');
    }

    my $req = $c->req->json;
    foreach my $body (@{$req}) {
        $logger->info("Callback received: " . Dumper($body));
        _handle_callback($body);
    }

    return $c->render(status => 200, text => '');

}

sub _handle_callback {
    my ($body) = @_;

    my $notice = Koha::Notice::Messages->find($body->{status}->{referenceId});
    return unless $notice;

    my $status_code = $body->{status}->{code};
    if (_error($status_code)) {
        $notice->set({
            status        => 'failed',
            failure_code => $body->{status}->{details},
        })->store;
    }
}

sub _error {
    (my $status_code) = @_;

    return 1 if $status_code > 2000;
    return 0;
}

sub _get_config_token {
    my $sms_send_config = C4::Context->config('sms_send_config');
    my $config_file = File::Spec->catfile($sms_send_config, 'MyLink/Driver.yaml');
    my $config = YAML::LoadFile($config_file);
    return $config->{callbackToken};
}

=head1

Logger initialization

log4perl.logger.mylink = INFO, MYLINK
log4perl.appender.MYLINK=Log::Log4perl::Appender::File
log4perl.appender.MYLINK.filename=<path>/mylink.log
log4perl.appender.MYLINK.mode=append
log4perl.appender.MYLINK.create_at_logtime=true
log4perl.appender.MYLINK.layout=PatternLayout
log4perl.appender.MYLINK.layout.ConversionPattern=[%d] [%p] %m%n
log4perl.appender.MYLINK.utf8=1
log4perl.appender.MYLINK.umask=0007
log4perl.appender.MYLINK.owner=www-data
log4perl.appender.MYLINK.group=www-data

=cut

sub _get_logger {
    my $CONFPATH = dirname($ENV{'KOHA_CONF'});
    my $log_conf = $CONFPATH . "/log4perl.conf";
    Log::Log4perl::init($log_conf);
    return Log::Log4perl->get_logger('mylink');
}

1;