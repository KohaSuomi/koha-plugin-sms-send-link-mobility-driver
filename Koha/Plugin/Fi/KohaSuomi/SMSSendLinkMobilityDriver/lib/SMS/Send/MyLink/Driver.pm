package SMS::Send::MyLink::Driver;
#use Modern::Perl; #Can't use this since SMS::Send uses hash keys starting with _
use SMS::Send::Driver ();
use URI::Escape;
use C4::Context;
use Encode;
use Text::Unaccent;
use Koha::Notice::Messages;
use UUID;
use utf8;
use Mojo::UserAgent;
use Koha::Caches;

use Try::Tiny;

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '1.0';
        @ISA     = 'SMS::Send::Driver';
}


#####################################################################
# Constructor

sub new {
        my $class = shift;
        my $params = {@_};

        if (! defined $params->{_client_id} ) {
            warn "->send_sms(_client_id) must be defined!";
            return;
        }
        if (! defined $params->{_client_secret} ) {
            warn "->send_sms(_client_secret) must be defined!";
            return;
        }

        if (! defined $params->{_baseUrl} ) {
            warn "->send_sms(_baseUrl) must be defined!";
            return;
        }

        if (! defined $params->{_authUrl} ) {
            warn "->send_sms(_authUrl) must be defined!";
            return;
        }

        if (! defined $params->{_senderId} ) {
            warn "->send_sms(_senderId) must be defined!";
            return;
        }

        if (! defined $params->{_cacheKey} ) {
            warn "->send_sms(_cacheKey) must be defined!";
            return;
        }

        # Create the object
        my $self = bless {}, $class;

        $self->{_client_id} = $params->{_client_id};
        $self->{_client_secret} = $params->{_client_secret};
        $self->{_baseUrl} = $params->{_baseUrl};
        $self->{_authUrl} = $params->{_authUrl};
        $self->{_senderId} = $params->{_senderId};
        $self->{_reportUrl} = $params->{_reportUrl};
        $self->{_cacheKey} = $params->{_cacheKey};
        $self->{_callbackURLs} = $params->{_callbackURLs};

        return $self;
}

sub hdiacritic {
    my $char;
    my $oldchar;
    my $string;

    foreach ( split( //, $_[0] ) ) {
        $char    = $_;
        $oldchar = $char;
        unless ( $char =~ /[A-Za-z0-9ÅåÄäÖöÉéÜüÁá]/ ) {
            $char = 'Z'  if $char eq 'Ʒ';
            $char = 'z'  if $char eq 'ʒ';
            $char = 'B'  if $char eq 'ß';
            $char = '\'' if $char eq 'ʻ';
            $char = 'e'  if $char eq '€';
            $char = unac_string( 'utf-8', $char ) if "$oldchar" eq "$char";
        }
        $string .= $char;
    }

    return $string;
}

sub _rest_call {
    my ($url, $headers, $authorization, $params) = @_;
    
    my $ua = Mojo::UserAgent->new;
    my $tx;
    if ($authorization) {
        $tx = $ua->post($url => $headers => form => $params);
    } else {
        $tx = $ua->post($url => $headers => json => $params);
    }

    if ($tx->error) {
        return ($tx->res->json, undef);
    } else {
        return (undef, $tx->res->json);
    }

    
}

sub send_sms {
    my $self    = shift;
    my $params = {@_};
    my $message = $params->{text};
    my $recipientNumber = $params->{to};
    my $url = $self->{_baseUrl};
    my $authUrl = $self->{_authUrl};
    my $senderId = $self->{_senderId};
    $senderId = "$senderId" if $senderId =~ /^\d+$/; #SenderId must be a string
    my $cacheKey = $self->{_cacheKey};
    my $callbackURLs = $self->{_callbackURLs};

    if (! defined $message ) {
        warn "->send_sms(text) must be defined!";
        return;
    }
    if (! defined $recipientNumber ) {
        warn "->send_sms(to) must be defined!";
        return;
    }

    #Prevent injection attack!
    $recipientNumber =~ s/'//g;
    substr($recipientNumber, 0, 1, "+358") unless "+" eq substr($recipientNumber, 0, 1);
    $message =~ s/(")|(\$\()|(`)/\\"/g; #Sanitate " so it won't break the system( iconv'ed curl command )

    my $headers = {'Content-Type' => 'application/x-www-form-urlencoded'};
    my ($headers, $error, $res, $revoke);
    my $cache = Koha::Caches->get_instance();
    my $cachedToken = $cache->get_from_cache($cacheKey);
    my $accessToken = $cachedToken->{access_token} if $cachedToken;
    my $tokenType = $cachedToken->{token_type} if $cachedToken;
    unless ($accessToken) {
        $headers = {'Content-Type' => 'application/x-www-form-urlencoded'};
        ($error, $res) = _rest_call($authUrl, $headers, 1, {grant_type => 'client_credentials', client_id => $self->{_client_id}, client_secret => $self->{_client_secret}});
        if ($error) {
            die "Connection failed with: ". $error->{message};
            return;
        }
        $cache->set_in_cache($cacheKey, $res, { expiry => $res->{expires_in} - 5 });
        $accessToken = $res->{access_token};
        $tokenType = $res->{token_type};
    }

    if ($error) {
        die "Connection failed with: ". $error->{message};
        return;
    }

    $headers = {Authorization => "$tokenType $accessToken", 'Content-Type' => 'application/json'};

    my $reqparams = {
        recipient => $recipientNumber,
        content => {text => hdiacritic($message), options => {'sms.sender' => $senderId, 'sms.encoding' => 'AutoDetect', 'sms.obfuscate' => 'ContentAndRecipient'} },
        priority => 'Normal'
    };

    if ($params->{_message_id}) {
        $reqparams->{referenceId} = "$params->{_message_id}";
    }
    
    if ($callbackURLs) {
        $reqparams->{callback} = {urls => $callbackURLs, mode => 'URL'};
    }

    ($error, $res) = _rest_call($url, $headers, undef, [$reqparams]);
    
    if ($error) {
        die "Connection failed with: ". $error->{message};
        return;
    } elsif ($res->{status} eq "error") {
        die "Connection failed with: ". $res->{error};
        return;
    } else {
        return 1;
    }
}
1;
