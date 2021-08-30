#!perl
use Modern::Perl;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name                => 'SMS::Send::LinkMobility::Driver',
    dist_author                => q{Johanna Räisä <johanna.raisa@koha-suomi.fi>},
    dist_version_from          => 'lib/SMS/Send/LinkMobility/Driver.pm',
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
        'MIME::Base64'         => 0,
        'Mojo::JSON'           => 0,
        'Mojo::URL'            => 0,
        'POSIX'                => 0,
        'Try::Tiny'            => 0,
        'Encode'               => 0,
    },
    add_to_cleanup     => [ 'SMS-Send-LinkMobility-Driver-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

1;
