#!/bin/bash

kohaplugindir="$(grep -Po '(?<=<pluginsdir>).*?(?=</pluginsdir>)' $KOHA_CONF)"
kohadir="$(grep -Po '(?<=<intranetdir>).*?(?=</intranetdir>)' $KOHA_CONF)"

rm -r $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/SMSSendLinkMobilityDriver
rm $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/SMSSendLinkMobilityDriver.pm

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ln -s "$SCRIPT_DIR/Koha/Plugin/Fi/KohaSuomi/SsnProvider" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/SMSSendLinkMobilityDriver
ln -s "$SCRIPT_DIR/Koha/Plugin/Fi/KohaSuomi/SsnProvider.pm" $kohaplugindir/Koha/Plugin/Fi/KohaSuomi/SMSSendLinkMobilityDriver.pm

perl $kohadir/misc/devel/install_plugins.pl

