#!/bin/bash
set -e 
set -o pipefail 

URL="https://raw.githubusercontent.com/lybavsky/vfort/develop"

WINURL="https://software.download.prss.microsoft.com/dbazure/Win10_22H2_Russian_x64v1.iso?t=c6925b7f-4981-424a-b2ac-2a1b2835b05b&e=1692794388&h=d1e8e5b5aac2b4ec885ac52c61cba5c4ab6dc4bd96d42c43444807e50a579d9c"
WDIR="/srv/vm"


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

function getval() {
	json=$1
	val=$2

	echo "${json[@]}" | jq -r ".value$val"
}

function getkey() {
	json=$1

	echo "${json[@]}" | jq -r ".key"
}

echo "Disable powersave mode when closing laptop"
sed -i /etc/systemd/logind.conf -e '/HandleLidSwitch/d'
sed -i /etc/systemd/logind.conf -e '$aHandleLidSwitch=ignore'
systemctl restart systemd-logind.service

echo "Check packages to install"
pkgs_to_install=(bridge-utils xinit virtualbox virtualbox-ext-pack virtualbox-guest-utils virtualbox-guest-additions-iso dialog python3 python3-pip jq)
pkgs_will_install=()
pkgs_installed=( $(dpkg -l | awk '/^ii/{print $2}' ) )
for pkg_to_install in ${pkgs_to_install[@]}; do
        if [[ "$pkg_to_install" =~ " ${pkgs_installed[@]} " ]]; then
                pkgs_will_install+=($pkg_to_install)
        fi
done

if [ "${#pkgs_will_install[@]}" -ne 0 ]; then
        echo "Start to install packages"
        apt update
        apt install -y ${pkgs_will_install[@]}
else
        echo "No need to install packages"

fi

pip3 install yq


if [ ! -f "/win.iso" ]; then
	echo "Download windows 10 iso"
	wget -O /win.iso "$WINURL"
else
	echo "/win.iso already presented"
fi


echo "Make VM directories"
mkdir -p $WDIR

CFG_URL="$URL/vm.yaml"

curl -f $CFG_URL 2>/dev/null | yq -c '.vms|to_entries[]' | while read jcfg; do
	echo "Got $jcfg";

	vm_name=`getkey $jcfg`
	echo "Processing VM $vm_name"

  disk_source=`getval $jcfg ".disk.source"`
  disk_size=`getval $jcfg ".disk.size"`
  echo "disk source: $disk_source, size $disk_size"

  if [ "$disk_source" == "file" ]; then
  		free_space="`df -BG /srv/vm | awk '{ if (NR!=1) {print substr($4,0,length($4)-1)} }'`"
  else
  		free_space=""
  fi
  echo "free space: $free_space"

done
