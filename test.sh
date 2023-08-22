#!/bin/bash
set -e 
set -o pipefail 

URL="https://raw.githubusercontent.com/lybavsky/vfort/develop"

WINURL="https://software.download.prss.microsoft.com/dbazure/Win10_22H2_Russian_x64v1.iso?t=c6925b7f-4981-424a-b2ac-2a1b2835b05b&e=1692794388&h=d1e8e5b5aac2b4ec885ac52c61cba5c4ab6dc4bd96d42c43444807e50a579d9c"


catch() {
  echo "Got some error on line $LINENO"
  exit 0
}

trap "catch" ERR


function err() {
	shift
	msg="$@"
	echo "Error: $msg"
	exit 1
}

[ "$EUID" -ne 0 ] && err "Script sould be started as root"


echo "Disable powersave mode when closing laptop"
sed -i /etc/systemd/logind.conf -e '/HandleLidSwitch/d'
sed -i /etc/systemd/logind.conf -e '$aHandleLidSwitch=ignore'
systemctl restart systemd-logind.service

echo "Start to install virtualbox and additional soft"
apt update 
apt install -y bridge-utils xinit virtualbox virtualbox-ext-pack virtualbox-guest-utils virtualbox-guest-additions-iso dialog python3 python3-pip

pip3 install yq


if [ ! -f "/win.iso" ]; then
	echo "Download windows 10 iso"
	wget -O /win.iso "$WINURL"
else
	echo "/win.iso already presented"
fi


echo "Make VM directories"
mkdir -p /srv/vm

CFG_URL="$URL/vm.yaml"

curl -f $CFG_URL 2>/dev/null | yq -r '.|to_entries()' | while read jcfg; do
	echo "Got $jcfg";
done
