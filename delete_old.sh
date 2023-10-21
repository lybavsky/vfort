#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh

while :; do 
    items=()
    
    if [ "$( ls -1 $WDIR/ | wc -l )" -eq 0 ]; then
      dialog --title "No installed VM" --clear --msgbox "No installed VM, will exit" 0 0 
      exit 1
    fi

    for vm in "$WDIR"/*; do
      vmn="${vm##*/}"
      items+=("${vmn}" "${vmn}")
    done
    
    exec 4>&1
    vm_name=$(dialog \
      --title "Delete VM" \
      --clear \
      --no-cancel \
      --menu "Please select VM to delete:" 0 0 4 \
      ${items[@]} \
      "exit" "Exit without deletion" \
      2>&1 1>&4 )
    
    if [ "$vm_name" == "exit" ]; then
      dialog --title "No selection, will exit" --clear --msgbox "Will exit" 0 0 
      exit 0
    fi
    
    echo "Will delete $vm_name"
    
    vmstate="$(vm_state $vm_name)"
    if [ "$vmstate" != "powered off" -a "$vmstate" != "aborted" ]; then
    	echo "VM state is $vmstate, need to poweroff"
    	systemctl stop ${UNITNAME}@${vm_name}.service
    	vboxmanage controlvm $vm_name poweroff || echo "Can not poweroff"
    fi
    
    echo "Will disable unit ${UNITNAME}@${vm_name}"
    systemctl disable ${UNITNAME}@${vm_name}
    
    
  	set +o pipefail
    hostif="$( vboxmanage showvminfo $vm_name | grep "^NIC 1:" | grep "Host-only Interface" | sed -e 's/^.*'"'"'\(.*\)'"'"'.*$/\1/g;s/^.*\s\{1,\}//g' )"
    inlist="$( vboxmanage list hostonlyifs | awk '/^Name/{print $2}' | grep $hostif -q; echo $? )"
    set -o pipefail
    

    vbox_net="$( vbox_show hostonlyifs $hostif | awk '/VBoxNetworkName/{ print $2 }' )"
    vbox_net_dhcp="$( vbox_show dhcpservers $vbox_net NetworkName)"
    
    echo "Checking if enabled dhcpserver for net"
    if [ ! -z "$vbox_net_dhcp" ]; then
      echo "Need to disable dhcpserver for net"
      vboxmanage dhcpserver remove --network="$vbox_net"
    fi
    
    echo "Checking if hostif available"
    if [ ! -z "$hostif" -a "$inlist" -eq 0 ]; then
      echo "Need to delete hostif $hostif"
      vboxmanage hostonlyif remove $hostif
    fi
    
    if [ -f "/srv/vm/$vm_name/disk.vmdk" ]; then
      echo "Probably disk is raw, will delete part"
      part="$( cat "/srv/vm/$vm_name/disk.vmdk" | awk '/RW/{print substr($4,2,length($4)-2)}' )"
    
      device="${part%%[0-9]*}"
      devpref="${#device}"
      partn="${part:$devpref}"
    
      echo "sfdisk --delete $device $partn"
      sfdisk --delete $device $partn
    
      partprobe $device
    fi

    echo "Will delete VM"
    vboxmanage unregistervm $vm_name --delete
    
    
    
    echo "Will delete VM folder"
    rm -r /srv/vm/$vm_name

    dialog --title "Deleted" --clear --msgbox "VM $vm_name should be deleted" 0 0 

done
