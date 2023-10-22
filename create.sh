set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh


function vm_create() {
  jcfg="$@"

  clear
  echo "Will create VM: ${jcfg[@]}"

	vm_name=`getval $jcfg .name`
	echo "Processing VM $vm_name"

  disk_source=`getval $jcfg ".disk.source"`
  disk_size=`getval $jcfg ".disk.size"`

  memory_mb=`getval $jcfg ".memory_mb"`
  vram_mb=`getval $jcfg ".vram_mb"`

  echo "memory: $memory_mb"
  echo "vram: $vram_mb"

  cpus=`getval $jcfg ".cpus"`

	rde_user=`getval $jcfg ".rde.user"`
	rde_pwd=`getval $jcfg ".rde.pwd"`

	vnc_pwd=`getval $jcfg ".vnc.pwd"`

  user_name=`getval $jcfg ".user.name"`
  user_pwd=`getval $jcfg ".user.pwd"`

  ip_net=`getval $jcfg ".net"`

  isof=`getval $jcfg ".iso"`


  echo "Validate ip address ${ip_net}"
  ipstr=${ip_net%%\/[0-9]*}
  cidrstr=${ip_net##*\/}

  ip_net="$( get_net $ipstr $cidrstr )"
  ip_gw="$( get_nth_ip $ipstr $cidrstr 1 )"
  ip_dhcp="$( get_nth_ip $ipstr $cidrstr 2 )"
  ip_first="$( get_nth_ip $ipstr $cidrstr 3 )"
  ip_last="$( get_nth_ip $ipstr $cidrstr -2 )"
  ip_mask="$( get_long_mask $cidrstr )"

  if [ "$ip_net" != "$ipstr" ]; then
  	nferr "Net parameter should be net addressm instead got $ipstr" && return 1
	elif [ "$cidrstr" -gt 29 ]; then
  	nferr "Mask should be 29 and less" && return 1
  fi

	vmm="vboxmanage modifyvm $vm_name"

	vt_num="$( get_vt $WDIR )"

	if [ $vt_num -eq "-1" ]; then
		nferr "Not enough free VT" && return 1
	fi


	rde_port="$(( 3389 + $vt_num ))"
	vnc_port="$(( 5000 + $vt_num ))"


	echo "Create VM folder"
	VDIR="${WDIR}/${vm_name}"
	mkdir -p $VDIR

	echo "Will check disk size"
  if [ "$disk_source" == "file" ]; then
  		free_space="`df -BG ${WDIR} | awk '{ if (NR!=1) {print substr($4,0,length($4)-1)} }'`"
  else
  		free_space="`sfdisk --list-free -q $disk_source | cut -d ' ' -f4 | sed -e '1d;s/\.[0-9]*G//g'`"
  fi
  echo "free space: $free_space"
  if [ $free_space -le $disk_size ]; then
  	nferr "Not enough disk space for $vm_name: requested $disk_size, available only $free_space" && return 1
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
 		vmstate="$(vm_state $vm_name)"
 		if [ "$vmstate" != "powered off" -a "$vmstate" != "aborted" ]; then
			echo "VM state is $vmstate, need to poweroff"
			systemctl stop ${UNITNAME}@${vm_name}
			vboxmanage controlvm $vm_name poweroff || echo "Can not poweroff"
		fi
 	fi



	echo "Configure VM memory, cpu and disk"
  $vmm --ioapic on
  $vmm --memory $memory_mb 
  $vmm --vram $vram_mb
  $vmm --graphicscontroller vboxsvga
  $vmm --mouse ps2
  $vmm --usb on --usbehci on --usbxhci on
  $vmm --firmware bios

  $vmm --cpuhotplug on
  $vmm --cpus 1

  $vmm --audio alsa
  $vmm --audioout on --audiocontroller hda 
  


	echo "Configuring VNC"
	vboxmanage setproperty vrdeauthlibrary "VBoxAuthSimple"
	vboxmanage modifyvm $vm_name --vrdeauthtype external

  if [ "$vnc_pwd" != "" ]; then
  	# pwd_hash="$( vboxmanage internalcommands passwordhash "$rde_pwd" | cut -d' ' -f3 )"
		# echo "pwd hash is ${pwd_hash} for $rde_user,$rde_pwd"
    # vboxmanage setextradata $vm_name "VBoxAuthSimple/users/$rde_user" $pwd_hash
  	$vmm --vrde on
	  $vmm --vrdeport $vnc_port
	  $vmm --vrdeproperty VNCPassword=$vnc_pwd 
	else
		$vmm --vrde off
	fi

	echo "Configuring unattended login, password with iso $isof"
  vboxmanage unattended install $vm_name --iso $isof --user $user_name --password $user_pwd --install-additions --post-install-command="shutdown /s || shutdown -P now"
  $vmm --boot1 dvd --boot2 disk --boot3 none --boot4 none
  vboxmanage startvm $vm_name --type headless 2>&1

	myip="$( ip ro get 8.8.8.8 | awk '{print $7}' )"
  dialog --msgbox "You need to connect via VNC ${myip}:${vnc_port} with '${vnc_pwd}' to VM and press continue to boot from iso, when windows will be installed, shutdown the vm " 10 0


	#TODO: set resolution - should exec only on running machine
	vboxmanage controlvm ${vm_name} setvideomodehint 1366 768 32

	# TODO: Temp, delete me
	# VBoxManage controlvm $vm_name poweroff

	while [ "$( vm_running $vm_name )" -eq 1 ]; do
		echo "Waiting for unattended process finish.."
		sleep 10
	done


  $vmm --boot1 disk --boot2 none --boot3 none --boot4 none 

	echo "Umount unattended"
	umount_re $vm_name "Unattended"

	echo "Umount win iso $isof"
	umount_re $vm_name "$isof"



	set +o pipefail
	echo "Check if adapter attached"
	hostif="$( vboxmanage showvminfo $vm_name | grep "^NIC 1:" | grep "Host-only Interface" | sed -e 's/^.*'"'"'\(.*\)'"'"'.*$/\1/g;s/^.*\s\{1,\}//g' )"
	echo "Check if adapter exists"
	inlist="$( vboxmanage list hostonlyifs | awk '/^Name/{print $2}' | grep "$hostif" -q; echo $? )"
	set -o pipefail

	if [ -z "$hostif"  -o "$hostif" == "disabled" -o "$inlist" -eq 1 ]; then
		echo "Add network adapter"
		hostif="$( vboxmanage hostonlyif create 2>/dev/null | tail -n1 | awk '{print substr($2,2,length($2)-2)}' )"
	else
		echo "Adapter $hostif already attached"
	fi

	echo "Will check if dhcp server exists on if network"
	vbox_net="$( vbox_show hostonlyifs $hostif | awk '/VBoxNetworkName/{ print $2 }' )"
	echo "Vboxnet: ${vbox_net}"

	vbox_net_dhcp="$( vbox_show dhcpservers $vbox_net NetworkName)"
	echo "Vboxnet dhcp: ${vbox_net_dhcp}"

	if [ ! -z  "$vbox_net_dhcp" ]; then
		echo "Found dhcp server will delete $vbox_net"
		vboxmanage dhcpserver remove --network="$vbox_net"
	fi

  echo "Will create dhcp server"
	vboxmanage dhcpserver add --interface=$hostif --server-ip $ip_dhcp --netmask $ip_mask --lowerip $ip_first  --upperip $ip_first --enable --set-opt=3 $ip_gw

	echo "Will configure host iface ip addresses"
	vboxmanage hostonlyif ipconfig $hostif --ip $ip_gw --netmask $ip_mask
	$vmm --nic1 hostonly --hostonlyadapter1 $hostif


  echo "Start to configure init scripts"

	echo "xinit $VDIR/vbox.sh  -- :${vt_num} vt${vt_num} -nolisten tcp -keeptty" > $VDIR/start.sh
	chmod +x $VDIR/start.sh


	echo "/usr/bin/vboxsdl --startvm ${vm_name} --fullscreen --vrdp ${vnc_port} --nofstoggle --nohostkey -fullscreenresize -noresize --termacpi " > $VDIR/vbox.sh
	chmod +x $VDIR/vbox.sh
	
	systemctl enable win@${vm_name}.service 2>&1

	# TODO: need to set modehint
	# vboxmanage controlvm ${vm_name} setvideomodehint 1366 768 32

	echo "Set extradata for video mode"
  VBoxManage setextradata ${vm_name} "CustomVideoMode1" "1366x786x24"
	VBoxManage setextradata global GUI/MaxGuestResolution 1366x786

	systemctl start win@${vm_name}.service
	#TODO: do something with net - ip_forward, masquerade, ...
}
