package SMS::Send::LinkMobility::Driver;
#use Modern::Perl; #Can't use this since SMS::Send uses hash keys starting with _
use SMS::Send::Driver ();
use LWP::Curl;
use URI::Escape;
use C4::Context;
use Encode;
use Text::Unaccent;
use Koha::Notice::Messages;
use UUID;
use utf8;

use Try::Tiny;

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '0.01';
        @ISA     = 'SMS::Send::Driver';
}


#####################################################################
# Constructor

sub new {
        my $class = shift;
        my $params = {@_};

        my $username = $params->{_login} ? $params->{_login} : $params->{_user};
        my $password = $params->{_password} ? $params->{_password} : $params->{_passwd};
        my $baseUrl = $params->{_baseUrl};

        if (! defined $username ) {
            warn "->send_sms(_login) must be defined!";
            return;
        }
        if (! defined $password ) {
            warn "->send_sms(_password) must be defined!";
            return;
        }

        if (! defined $baseUrl ) {
            warn "->send_sms(_baseUrl) must be defined!";
            return;
        }

        #Prevent injection attack
        $self->{_login} =~ s/'//g;
        $self->{_password} =~ s/'//g;

        # Create the object
        my $self = bless {}, $class;

        $self->{_login} = $username;
        $self->{_password} = $password;
        $self->{_baseUrl} = $baseUrl;
        $self->{_requestEncoding} = $params->{_requestEncoding};
        $self->{_unicode} = $params->{_unicode};
        $self->{_reportUrl} = $params->{_reportUrl};
        $self->{_sourceName} = $params->{_sourceName};

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

sub _get_login {
    my ($username, $password, $message_id) = @_;

    if (ref($username) eq "HASH" && ref($password) eq "HASH") {
        my $notice = Koha::Notice::Messages->find($message_id);
        my $library = Koha::Libraries->find({branchemail => $notice->from_address});
        my %usernames = %{$username};
        my %passwords = %{$password};
        foreach $key (keys %usernames) {
            if ($key eq $library->branchcode) {
                $username = $usernames{$key};
                last;
            }
        }
        foreach $key (keys %$passwords) {
            if ($key eq $library->branchcode) {
                $password = $passwords{$key};
                last;
            }
        }
    }

    return $username, $password;
}

sub send_sms {
    my $self    = shift;
    my $params = {@_};
    my $message = $params->{text};
    my $recipientNumber = $params->{to};

    my ($username, $password) = _get_login($self->{_login}, $self->{_password}, $params->{_message_id});

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
    $message =~ s/(")|(\$\()|(`)/\\"/g; #Sanitate " so it won't break the system( iconv'ed curl command )

    my $base_url = $self->{_baseUrl};
    my $parameters = {
        'user'      => $username,
        'password'  => $password,
        'dests'     => $recipientNumber,
    };

    # check if we need to use unicode
    #  -> if unicode => yes, maxlength for 1 sms = 70 chars
    #  -> else maxlenght = 160 chars (140 bytes, GSM 03.38)
    my $gsm0388 = decode("gsm0338",encode("gsm0338", $message));

    # Set the encoding for dealing with Link Mobility server, this is separate from the actual message encoding
    my $requestEncoding='UTF-8';
    if ($self->{_requestEncoding}) {
        $requestEncoding = $self->{_requestEncoding};
    }

    if ($message ne $gsm0388 and $self->{_unicode} eq "yes"){
        $parameters->{'unicode'} = 'yes';
        $parameters->{'text'} = encode($requestEncoding, $message);
        my $notice = Koha::Notice::Messages->find($params->{_message_id});
        $notice->set({ metadata   => 'UTF-16' })->store if defined $notice;
    } else {
        $parameters->{'text'} = encode($requestEncoding, hdiacritic($message));
        $parameters->{'unicode'} = 'no';
    }

    if ($self->{_sourceName}) {
        $parameters->{'source-name'} = $self->{_sourceName};
    }

    my $report_url = $self->{_reportUrl};
    if ($report_url) {
        my $msg_id = $params->{_message_id};
        my ( $uuid, $uuidstring );
        UUID::generate($uuid);
        UUID::unparse( $uuid, $uuidstring );
        my @params = ($uuidstring, $msg_id);
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("INSERT INTO kohasuomi_sms_token (token,message_id) VALUES (?,?);");
        $sth->execute(@params);
        $report_url =~ s/\{token\}|\{messagenumber\}/$uuidstring/g;
        $parameters->{'report'} = $report_url;
    }
    
    my $lwpcurl = LWP::Curl->new();
    my $return;
    try {
        $return = $lwpcurl->post($base_url, $parameters);
    } catch {
        if ($_ =~ /Couldn't resolve host name \(6\)/) {
            die "Connection failed";
        }
        die $_;
    };

    if ($lwpcurl->{retcode} == 6) {
        die "Connection failed";
    }

    my $delivery_note = $return;

    return 1 if ($return =~ m/OK [1-9](\d*)?/);

    # remove everything except the delivery note
    $delivery_note =~ s/^(.*)message\sfailed:\s*//g;

    # pass on the error by throwing an exception - it will be eventually caught
    # in C4::Letters::_send_message_by_sms()
    die $delivery_note;
}
1;
