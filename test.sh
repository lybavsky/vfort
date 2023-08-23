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


echo "Make VM directory $WDIR"
mkdir -p $WDIR

CFG_URL="$URL/vm.yaml"

curl -f $CFG_URL 2>/dev/null | yq -c '.vms|to_entries[]' | while read jcfg; do
	echo "Got $jcfg";


	vm_name=`getkey $jcfg`
	echo "Processing VM $vm_name"

	VDIR="${WDIR}/${vm_name}"
	mkdir -p $VDIR

  disk_source=`getval $jcfg ".disk.source"`
  disk_size=`getval $jcfg ".disk.size"`
  echo "disk source: $disk_source, size $disk_size"

	echo "Will check disk size"
  if [ "$disk_source" == "file" ]; then
  		free_space="`df -BG /srv/vm | awk '{ if (NR!=1) {print substr($4,0,length($4)-1)} }'`"
  else
  		free_space="`sfdisk --list-free -q $disk_source | cut -d ' ' -f4 | sed -e '1d;s/\.[0-9]*G//g'`"
  fi
  echo "free space: $free_space"
  if [ $free_space -le $disk_size ]; then
  	err "Not enough disk space for $vm_name: requested $disk_size, available only $free_space"
  fi

  echo "Will create disk"
  if [ "$disk_source" == "file" ]; then
  	img_name="$VDIR/disk.vdi"
  	echo "Disk name $img_name"
  	if [ -f $img_name ]; then
			echo "Image already exists"
		else
			vboxmanage createhd --filename $img_name --size $(( $disk_size * 1024 )) --format VDI
		fi
  else
  	img_name="$VDIR/disk.vmdk"
  	echo "Disk name $img_name"

		if [ -f $img_name ]; then
			echo "Disk image already exists"
		else
  		echo ",${disk_size}G" | sfdisk -X gpt $disk_source -a --force
  		partition="$( fdisk -x -lu $disk_source -o Device | tail -n1 )"
  		partprobe $disk_source
  		#also can use echo 1 > /sys/block/sda/device/rescan

			vboxmanage internalcommands createrawvmdk -filename $img_name -rawdisk $partition
		fi
  fi


	if [ "$( vboxmanage showvminfo $vm_name >/dev/null 2>&1; echo $? )" -ne 0 ]; then
		echo "Creating VM $vm_name"
 		vboxmanage createvm --name $vm_name --ostype Windows10_64 --register --basefolder $VDIR
 	else 
 		echo "VM $vm_name already exists"
 	fi

  memory_mb=`getval $jcfg ".memory_mb"`
  vram_mb=`getval $jcfg ".vram_mb"`
  echo "ram: $memory_mb, vram: $vram_mb"


  vboxmanage modifyvm $vm_name --ioapic on
  vboxmanage modifyvm $vm_name --memory $memory_mb --vram $vram_mb
  vboxmanage modifyvm $vm_name --graphicscontroller vboxsvga
  VBoxManage storagectl $vm_name --name "SATA Controller" --add sata --controller IntelAhci
  VBoxManage storageattach $vm_name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium  $img_name
  
  VBoxManage modifyvm $vm_name --mouse ps2
  VBoxManage modifyvm $vm_name --firmware bios

  #TODO: we are here
  VBoxManage modifyvm $vm_name --vrdeproperty VNCPassword=VNCPASS --vrdeport 3390
  
  VBoxManage modifyvm $vm_name --cpuhotplug on
  VBoxManage modifyvm $vm_name --cpus 1
  
  VBoxManage unattended install $vm_name --iso /root/win10.iso --user lybavsky --password VNCPASS
  VBoxManage modifyvm $vm_name --boot1 dvd --boot2 disk --boot3 none --boot4 none 
  
  VBoxManage storagectl $vm_name --name "IDE Controller" --add ide --controller PIIX4       
  VBoxManage storageattach $vm_name --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium /usr/share/virtualbox/VBoxGuestAdditions.iso
  
  vboxmanage hostonlyif create
  vboxmanage modifyvm $vm_name --nic1 hostonly --hostonlyadapter1 vboxnet2
  vboxmanage dhcpserver add --interface=vboxnet2 --ip 192.168.57.1 --netmask 255.255.255.0 --lowerip 192.168.57.100  --upperip 192.168.57.200
  vboxmanage dhcpserver modify --ifname vboxnet2 --enable
  
  VBoxManage modifyvm $vm_name --audio alsa
  VBoxManage modifyvm $vm_name --audioout on --audiocontroller hda 
  
  VBoxManage modifyvm $vm_name --usb on --usbehci on --usbxhci on


done
