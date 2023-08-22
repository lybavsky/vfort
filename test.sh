#!/bin/bash

WINURL="https://software.download.prss.microsoft.com/dbazure/Win10_22H2_Russian_x64v1.iso?t=c6925b7f-4981-424a-b2ac-2a1b2835b05b&e=1692794388&h=d1e8e5b5aac2b4ec885ac52c61cba5c4ab6dc4bd96d42c43444807e50a579d9c"

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

echo "Start to install virtualbox"
apt update 
apt install -y bridge-utils xinit virtualbox virtualbox-ext-pack virtualbox-guest-utils virtualbox-guest-additions-iso

echo "Download windows 10 iso"
wget -O /win.iso "$WINURL"
