#!/bin/bash

function err() {
	shift
	msg="$@"
	echo "Error: $msg"
	exit 1
}

[ "$EUID" -ne 0 ] && err "Script sould be started as root"


echo "Disable powersave mode when closing laptop"

mkdir -p /etc/NetworkManager/conf.d/
echo "[connection]
wifi.powersave = 2" > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf

systemctl restart NetworkManager
