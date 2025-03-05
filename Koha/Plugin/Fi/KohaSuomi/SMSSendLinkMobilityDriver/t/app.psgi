# Description: A simple PSGI application that handles GET and POST requests
# To start: plackup -p 5001 t/app.psgi
use strict;
use warnings;
use Plack::Request;
use JSON;

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);

    if ($req->path eq '/' && $req->method eq 'GET') {
        my $params = $req->parameters;
        my $response = {
            status  => 'success',
        };
        return [
            200,
            ['Content-Type' => 'application/json'],
            [encode_json($response)],
        ];
    }

    if ($req->path eq '/auth/token' && $req->method eq 'POST') {
        my $params = $req->parameters;
        if ($params->{grant_type} ne 'client_credentials') {
            return [
                400,
                ['Content-Type' => 'text/plain'],
                ['Bad Request'],
            ];
        }
        if ($params->{client_id} ne 'client_id' || $params->{client_secret} ne 'client_secret') {
            return [
                401,
                ['Content-Type' => 'text/plain'],
                ['Unauthorized'],
            ];
        }
        my $response = {
            access_token => '1234567890',
            expires_in => 3600,
            token_type => 'Bearer',
        };
        return [
            200,
            ['Content-Type' => 'application/json'],
            [encode_json($response)],
        ];
    }

    if ($req->path eq '/sms/v1/messages' && $req->method eq 'POST') {
        if (!_check_bearer_token($req)) {
            return [
                401,
                ['Content-Type' => 'text/plain'],
                ['Unauthorized'],
            ];
        }
        if (!$req->content) {
            return [
                400,
                ['Content-Type' => 'text/plain'],
                ['Bad Request'],
            ];
        }
        my $body = decode_json($req->content);
        if (!_validate_body($body)) {
            return [
                400,
                ['Content-Type' => 'text/plain'],
                ['Bad Request'],
            ];
        }
        my $response = {
            requestId => 'd385ab22-0f51-4b97-9ecd-b8ff3fd4fcb6',
            messages => [
                {
                    messageId => '8540d774-4863-4d2b-b788-4ecb19412e85',
                    referenceId => $body->{referenceId},
                    recipient => $body->{recipient},
                },
            ],
        };
        return [
            200,
            ['Content-Type' => 'application/json'],
            [encode_json($response)],
        ];
    }

    return [
        404,
        ['Content-Type' => 'text/plain'],
        ['Not Found'],
    ];
};

sub _check_bearer_token {
    my ($req) = @_;
    my $headers = $req->headers;
    my $auth = $headers->header('Authorization');
    if ($auth) {
        my ($type, $token) = split(' ', $auth);
        return 1 if $type eq 'Bearer' && $token eq '1234567890';
    }
    return 0;
}

sub _validate_body {
    (my $req) = @_;

    return 0 unless ref($req) eq 'ARRAY' && @$req;  # Validate body is a non-empty array
    my $body = $req->[0]; # Get the first element of the array
    return 0 unless $body->{recipient} || $body->{content};  # Validate required fields
    return 0 if $body->{recipient} !~ /^\+358\d{9,10}$/;  # Validate recipient in MSISDN format
    return 0 if !$body->{content}->{text}; # Validate content text
    return 0 if !$body->{content}->{options}; # Validate content options
    return 0 if !$body->{content}->{options}->{'sms.sender'}; # Validate sender
    return 1;

}

return $app;