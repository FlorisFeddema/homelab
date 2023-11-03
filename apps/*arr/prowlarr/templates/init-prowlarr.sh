#!/bin/sh
echo "### Initializing config ###"
if [ ! -f /prowlarr-config/config.xml ]; then
    cp -n /init-prowlarr/config.xml /config/config.xml
    echo "### No configuration found, intialized with default settings ###"
fi
