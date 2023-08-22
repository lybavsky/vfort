#!/bin/bash

function err() {
	shift
	msg="$@"
	echo "Error: $msg"
	exit 1
}

[ "$EUID" -ne 0 ] && err "Script sould be started as root"


echo "Disable powersave mode when closing laptop"
sed -i /etc/systemd/logind.conf -e '/HandleLidSwitch/d'
sed -i /etc/systemd/logind.conf -e '$a/HandleLidSwitch=ignore'
systemctl restart systemd-logind.service
