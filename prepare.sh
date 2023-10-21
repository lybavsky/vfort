#!/bin/bash
#Script to prepare server, install necessary packages, disable acpi and so on

CDIR="`dirname $( readlink -f $0 )`"
[ "$EUID" -ne 0 ] && err "Script sould be started as root"
source ${CDIR}/vars.sh


echo "Copy win@.service template"
if [ ! -f "/etc/systemd/system/win@.service" ]; then
	echo "Creating systemd unit"
	cat ${CDIR}/files/win.service.tmpl | sed -e 's/WDIR/'"${WDIR//\//\\/}"'/g'> /etc/systemd/system/${UNITNAME}@.service
	systemctl daemon-reload
fi


echo "Disable powersave mode when closing laptop"
sed -i /etc/systemd/logind.conf -e '/HandleLidSwitch/d'
sed -i /etc/systemd/logind.conf -e '$aHandleLidSwitch=ignore'
systemctl restart systemd-logind.service


echo "Check packages to install"
pkgs_to_install=(
  bridge-utils 
  xinit 
  virtualbox 
  virtualbox-ext-pack 
  virtualbox-guest-utils 
  virtualbox-guest-additions-iso 
  dialog 
  python3 
  python3-pip 
  jq 
  sm 
  evtest 
  alsa-utils
  yq
)
pkgs_will_install=()
pkgs_installed=( $(dpkg -l | awk '/^ii/{print $2}' ) )
for pkg_to_install in ${pkgs_to_install[@]}; do
        if [[ "$pkg_to_install" =~ " ${pkgs_installed[@]} " ]]; then
                pkgs_will_install+=($pkg_to_install)
        fi
done


echo "Install packages"
if [ "${#pkgs_will_install[@]}" -ne 0 ]; then
        echo "Start to install packages: ${#pkgs_will_install[@]}"
        apt update
        apt install -y ${pkgs_will_install[@]}
else
        echo "No need to install packages"

fi


echo "Install pip3 packages"
pip_to_install=(
  yq  
)
pip3 install ${pip_to_install[@]}


echo "Checking iso image on server"
if [ ! -f "$ISOF" ]; then
	echo "Download windows 10 iso"
	wget -O $ISOF "$WINURL"
else
	echo "$ISOF already presented"
fi


echo "Virtualbox disable ip network check"
if [ ! -f "/etc/vbox/networks.conf" ]; then
	echo "Fix virtualbox net ranges"
	mkdir -p /etc/vbox
	echo "* 0.0.0.0/0 ::/0" > /etc/vbox/networks.conf 
	systemctl restart virtualbox
fi


echo "Copy evtest script"
cp $CDIR/files/events.sh /usr/local/bin/events.sh
chmod +x /usr/local/bin/events.sh

echo "Copy evtest system unit"
cp $CDIR/files/evtest.service /etc/systemd/system/evtest.service
systemctl daemon-reload
systemctl enable evtest.service
systemctl start evtest.service

echo "Make VM directory $WDIR"
mkdir -p $WDIR

