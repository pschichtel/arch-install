#!/bin/sh

setup_network() {
    if ! wget -q --spider http://google.com
    then

        
        if ethernet=$(ip link | grep -oiP 'enp[a-z0-9]+')
        then
            #TODO implement me
            return 1
        elif wireless=$(ip link | grep -oiP 'wlp[a-z0-9]+')
        then
            wifimenu
        fi

    fi

    return 0
}

echo "Devices:"
lsblk -lpo NAME | grep -P '^/.*[^\d]$'

read -p "Device: " disk


