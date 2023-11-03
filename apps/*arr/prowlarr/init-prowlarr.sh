#!/bin/sh
if [ -e /config/config.xml ]; then
    echo "Config already exists"
    exit 1
fi
echo "Initializing config"
cp -n /init-prowlarr/config.xml /config/config.xml
