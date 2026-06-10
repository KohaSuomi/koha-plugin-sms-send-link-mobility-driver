package Koha::Plugin::Fi::KohaSuomi::SMSSendLinkMobilityDriver;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use utf8;
use JSON;
use JSON::Validator::Schema::OpenAPIv2;

## Here we set our plugin version
our $VERSION = "2.0";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'SMS::Send::LinkMobility::Driver',
    author          => 'Johanna Räisä',
    date_authored   => '2021-08-27',
    date_updated    => "2025-03-05",
    minimum_version => '17.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Send SMS messages to LinkMobility interface. (Paikalliskannat, jos LinkMobility käytössä)',
};

sub get_localized_metadata {
    my ($self) = @_;
    my $lang = C4::Languages::getlanguage() || 'en';
    my ($name, $description);

    if ($lang eq 'sv-SE') {
        $name = "SMS::Send::LinkMobility::Driver";
        $description = "Skicka SMS-meddelanden till LinkMobility-gränssnittet. (Lokala databaser, om LinkMobility används)";
    
    } elsif ($lang eq 'fi-FI' ) {
        $name = "SMS::Send::LinkMobility::Driver";
        $description = "Lähetä SMS-viestejä LinkMobility-liittymään. (Paikalliskannat, jos LinkMobility käytössä)";
    } else {
        $name = "SMS::Send::LinkMobility::Driver";
        $description = "Send SMS messages to LinkMobility interface. (Local databases, if LinkMobility is used)";
    }
    return ($name, $description);
}

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    my ($name, $description) = $self->get_localized_metadata();
    $self->{'metadata'}->{'name'} = $name;
    $self->{'metadata'}->{'description'} = $description;

    return $self;
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;

    $dbh->do("CREATE TABLE IF NOT EXISTS `kohasuomi_sms_token` (
        `token` varchar(150) NOT NULL,
        `message_id` int(11) NOT NULL,
        `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY `token` (`token`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    return 1;

}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();
    my $spec_file = $spec_dir . '/openapi.yaml';

    my $schema = JSON::Validator::Schema::OpenAPIv2->new;
    $schema->resolve( $spec_file );

    return $schema->bundle->data;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'kohasuomi';
}

1;
