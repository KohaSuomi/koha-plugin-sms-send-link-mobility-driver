#!perl
use Modern::Perl;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name                => 'SMS::Send::MyLink::Driver',
    dist_author                => q{Johanna Räisä <johanna.raisa@koha-suomi.fi>},
    dist_version_from          => 'lib/SMS/Send/MyLink/Driver.pm',
    dist_abstract              => 'A driver for sending SMS messages using MyLink',
    release_status             => 'stable',
    configure_requires => {
        'Module::Build'        => 0,
    },
    build_requires => {
        'Test::More'           => 0,
        'Test::MockModule'     => 0,
    },
    requires => {
        'SMS::Send::Driver'    => 0,
        'Mojo::UserAgent'      => 0,
        'URI::Escape'          => 0,
        'Try::Tiny'            => 0,
        'Encode'               => 0,
        'Unicode::Normalize'   => 0,
    },
    add_to_cleanup     => [ 'SMS-Send-MyLink-Driver-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

1;