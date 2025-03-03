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
use UUID;
use SMS::Send::LinkMobility::Driver;

=head1 API

=cut

=head2 callback example

    This is the callback example found in the Link Mobility API documentation

    {
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
    }

=cut

sub delivery {
    my $c = shift->openapi->valid_input or return;

    # Check if the API key is correct
    my $api_key_header = $c->req->headers->header('X-KOHA-LINK');
    my $api_key = _get_api_key();
    if ($api_key && $api_key_header ne $api_key) {
        return $c->render(status => 401, openapi => { error => "Unauthorized" });
    }

    try {
        my $body = $c->req->json;
        my $status_code = $body->{status}->{code};
        if (_error($status_code)) {
            my $notice = Koha::Notice::Messages->find($body->{status}->{referenceId});
            return $c->render( status  => 200,
                               openapi => "" ) unless $notice;
            $notice->set({
                status        => 'failed',
                failure_code => $body->{status}->{details},
            })->store;
        }

        return $c->render(status => 200, openapi => "");
    }
    catch {
        return $c->render( status  => 500,
                           openapi => { error => "Internal server error" } );
    };

}

sub _error {
    (my $status_code) = @_;

    return 0 if $status_code > 2000;
    return 1;
}

sub _get_api_key {
    my $sms_send_config = C4::Context->config('sms_send_config');
    my $config_file = File::Spec->catfile($sms_send_config, 'LinkMobility/Driver.yaml');
    my $config = YAML::LoadFile($config_file);
    return $config->{callbackAPIKey};
}