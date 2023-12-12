#!/bin/bash

# If FRR is not installed then install and configure it
if ! command -v /usr/lib/frr/frrinit.sh &> /dev/null; then
    echo "FRR could not be found"
    # Handle instances of release change
    rm /etc/apt/sources.list.d/frr.list
    curl -s https://deb.frrouting.org/frr/keys.asc | apt-key add -
    echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable | tee -a /etc/apt/sources.list.d/frr.list

    # Install FRRouting
    apt-get update && apt-get -y install --reinstall frr frr-pythontools
    if [ $? -eq 0 ]; then
        echo "Installation successful, updating configuration"
        # Minimal config, existing will remain in /etc
        echo > /etc/frr/vtysh.conf
        rm /etc/frr/frr.conf
        chown frr:frr /etc/frr/vtysh.conf
    fi
    service frr restart

    # Install other nice-to-haves for config editing
    apt-get -y install --reinstall nano
fi
