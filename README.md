# Koha-Suomi SMS::Send::LinkMobility::Driver

This plugin is for SMS::Send::LinkMobility::Driver

# API documentation

The API documentation can be found here https://developers.linkmobility.com/default/documentation/sms

# Downloading

From the release page you can download the latest \*.kpz file

# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

    Change <enable_plugins>0<enable_plugins> to <enable_plugins>1</enable_plugins> in your koha-conf.xml file
    Confirm that the path to <pluginsdir> exists, is correct, and is writable by the web server
    Remember to allow access to plugin directory from Apache

    <Directory <pluginsdir>>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.

# Build

Go to your plugin installation path and build the driver.

    perl Build.PL
    ./Build
    ./Build test
    ./Build install
    ./Build clean

# Configurations

The driver needs yaml configuration to work. Set your config file path to koha_conf.xml and create LinkMobility/Driver.yaml to that path.

```yaml
    client_id: foo
    client_secret: baa
    senderId: foobaa
    baseUrl: https://providerurl.service
    authUrl: https:://providerurl.service/auth/token
    cacheKey: foo_baa_key
    callbackAPIKey: fooooBAAAA
    # these are optional, since the url can be defined on myLink portal
    callbackURLs: 
        - https://foobaa.fi/api/v1/callback
```

Set the LinkMobility::Driver to SMSSendDriver systempreference and enjoy.
