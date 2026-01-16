#!/bin/sh
set -e

FS_PREFIX="/opt/freeswitch"
FS_CONF_SRC="${FS_PREFIX}/default_freeswitch_conf"   
FS_CONF_DST="${FS_PREFIX}/etc/freeswitch" 

mkdir -p "${FS_PREFIX}/var/run/freeswitch" \
         "${FS_PREFIX}/log" \
         "${FS_PREFIX}/recordings" \
         "${FS_PREFIX}/scripts"


if [ ! -f "${FS_CONF_DST}/freeswitch.xml" ]; then
    echo "=> Initializing FreeSWITCH config from default..."
    cp -r "${FS_CONF_SRC}"/* "${FS_CONF_DST}/"
fi


chown -R freeswitch:freeswitch "${FS_PREFIX}"

exec gosu freeswitch:freeswitch \
    "${FS_PREFIX}/bin/freeswitch" -nonat -c
