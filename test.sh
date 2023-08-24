#!/bin/bash
set -e 
set -o pipefail 

URL="https://raw.githubusercontent.com/lybavsky/vfort/develop"

WINURL="https://software.download.prss.microsoft.com/dbazure/Win10_22H2_Russian_x64v1.iso?t=c6925b7f-4981-424a-b2ac-2a1b2835b05b&e=1692794388&h=d1e8e5b5aac2b4ec885ac52c61cba5c4ab6dc4bd96d42c43444807e50a579d9c"
WDIR="/srv/vm"

ISOF="/win.iso"

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

function umount_re() {
	vmname=$1
	re=$2

	vboxmanage showvminfo $vmname | grep "$re" | while read l; do 
  	ctrl="${l%% \(*}"
  	num="${l%%)*}"
  	dev="${num##*, }"
  	port="${num##* (}"; port="${port%%, *}"
  	vboxmanage storageattach $vmname --storagectl "$ctrl" --port $port --device $dev --type hdd --medium none
  done
}

if [ ! -f "/etc/systemd/system/win@.service" ]; then
	echo "Creating systemd unit"
	cat > /etc/systemd/system/win@.service <<EOF
[Unit]
Description=Start and shutdown win
Requires=systemd-modules-load.service
Wants=network.target multi-user.target
After=systemd-modules-load.service network.target multi-user.target

[Service]
Type=simple
ExecStart=bash -c $WDIR/%i/start.sh
ExecStop=/usr/bin/VBoxManage controlvm %i acpipowerbutton

[Install]
WantedBy=getty.target
EOF

	systemctl daemon-reload
fi

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


if [ ! -f "$ISOF" ]; then
	echo "Download windows 10 iso"
	wget -O $ISOF "$WINURL"
else
	echo "$ISOF already presented"
fi

echo "Fix virtualbox net ranges"
mkdir -p /etc/vbox
echo "* 0.0.0.0/0 ::/0" > /etc/vbox/networks.conf 
systemctl restart virtualbox

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

    vboxmanage storagectl $vm_name --name "SATA Controller" --add sata --controller IntelAhci
    vboxmanage storageattach $vm_name --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium  $img_name
  
 	else 
 		echo "VM $vm_name already exists"
 	fi

  memory_mb=`getval $jcfg ".memory_mb"`
  vram_mb=`getval $jcfg ".vram_mb"`
  echo "ram: $memory_mb, vram: $vram_mb"


	echo "Configure VM memory, cpu and disk"
  vboxmanage modifyvm $vm_name --ioapic on
  vboxmanage modifyvm $vm_name --memory $memory_mb --vram $vram_mb
  vboxmanage modifyvm $vm_name --graphicscontroller vboxsvga

  vboxmanage modifyvm $vm_name --mouse ps2
  vboxmanage modifyvm $vm_name --firmware bios

  cpus=`getval $jcfg ".cpus"`

  vboxmanage modifyvm $vm_name --cpuhotplug on
  vboxmanage modifyvm $vm_name --cpus 1

  vboxmanage modifyvm $vm_name --audio alsa
  vboxmanage modifyvm $vm_name --audioout on --audiocontroller hda 
  
  vboxmanage modifyvm $vm_name --usb on --usbehci on --usbxhci on


	echo "Configuring RDE"
	rde_user=`getval $jcfg ".rde.user"`
	rde_pwd=`getval $jcfg ".rde.pwd"`
	rde_port=`getval $jcfg ".rde.port"`

	vboxmanage setproperty vrdeauthlibrary "VBoxAuthSimple"
	vboxmanage modifyvm common --vrdeauthtype external

  if [ "$rde_pwd" != "" ]; then
  	pwd_hash="$( vboxmanage internalcommands passwordhash "$rde_pwd" )"

    vboxmanage setextradata $vm_name "VBoxAuthSimple/users/$rde_user" "$pwd_hash"
  	vboxmanage modifyvm $vm_name --vrde on
	  vboxmanage modifyvm $vm_name --vrdeport $rde_port
	else
		vboxmanage modifyvm $vm_name --vrde off
	fi

	#Need to fix this
	echo "Configuring VNC"
	vnc_pwd=`getval $jcfg ".vnc.pwd"`
	vnc_port=`getval $jcfg ".vnc.port"`
  if [ "$vnc_pwd" != "" ]; then
	  vboxmanage modifyvm $vm_name --vrdeproperty VNCPassword=$vnc_pwd 
	else
	fi

	echo "Configuring unattended login, password"

  user_name=`getval $jcfg ".user.name"`
  user_pwd=`getval $jcfg ".user.pwd"`

  echo vboxmanage unattended install $vm_name --iso $ISOF --user $user_name --password $user_pwd
  vboxmanage unattended install $vm_name --iso $ISOF --user $user_name --password $user_pwd  --install-additions #--start-vm=headless
  vboxmanage modifyvm $vm_name --boot1 dvd --boot2 disk --boot3 none --boot4 none
  vboxmanage startvm $vm_name --type headless

	myip="$( ip ro get 8.8.8.8 | awk '{print $7}' )"
  dialog --msgbox "You need to connect via RDP ${myip}:${rde_port} as ${rde_user}:${rde_pwd} to VM and press continue to boot from iso, when windows will be installed, shutdown the vm " 10 0


	while [ "$( vboxmanage showvminfo $vm_name | grep "State:.*running" -q )" -ne 0 ]; done
		echo "Waiting for unattended process finish.."
		sleep 60
	done

  vboxmanage modifyvm $vm_name --boot1 disk --boot2 none --boot3 none --boot4 none 

	echo "Umount unattended"
	umount_re $vm_name "Unattended"

	echo "Umount win iso"
	umount_re $vm_name "$img_name"

	echo "Add network adapter"
	hostif="$( vboxmanage hostonlyif create 2>/dev/null | tail -n1 | awk '{print substr($2,2,length($2)-2)}' )"
	#vboxmanage list hostonlyifs
	
  ip_gw=`getval $jcfg ".ip.gw"`
  ip_dhcpa=`getval $jcfg ".ip.dhcpa"`
  ip_mask=`getval $jcfg ".ip.mask"`
  ip_lower=`getval $jcfg ".ip.lower"`
  ip_upper=`getval $jcfg ".ip.upper"`
	vboxmanage hostonlyif ipconfig vboxnet0 --ip $ip_gw --netmask $ip_mask
  vboxmanage dhcpserver add --interface=$hostif --server-ip $ip_dhcpa --netmask $ip_mask --lowerip $ip_lower  --upperip $ip_upper --enable --set-opt=3 $ip_gw

  vboxmanage modifyvm $vm_name --nic1 hostonly --hostonlyadapter1 $hostif


  echo "Start to configure init scripts"

	vt_num=`getval $jcfg ".vt"`
	echo "xinit $VDIR/vbox.sh  -- :1 vt${vt_num} -nolisten tcp -keeptty" > $VDIR/start.sh
	chmod +x $VDIR/start.sh
	
	#TODO: Here - to put vbox sdl
	
	systemctl enable win@${vm_name}.service

done
