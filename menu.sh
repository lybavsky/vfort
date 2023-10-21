#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh


#format of return array: 
function menu_main() {
    action=$(dialog \
      --title "VM Menu" \
      --no-cancel \
      --clear \
      --menu "Please select VM to delete:" 0 0 4 \
      "create" "Create new VM" \
      "delete" "Delete VMs" \
      "exit" "Exit script" \
      2>&1 1>&4 )

    echo $action
}

function menu_create() {
    name="$(dialog \
      --title "Create VM" \
      --clear \
      --inputbox "Please write name of VM:" 0 0 "$@" 2>&1 1>&4
    )"
    echo "$name"
}

function menu_err_message() {
    dialog \
        --title "Something wrong with params" \
        --clear \
        --no-collapse \
        --msgbox "$1" 0 0 2>&1 1>&4
}

function menu_inputbox() {
    title=$1
    shift
    text=$1
    shift
    val="$(dialog \
      --title "$title" \
      --inputbox "$text" 0 0 "$@" 2>&1 1>&4 
    )"

    echo $val
}

function menu_passwordbox() {
    title=$1
    shift
    text=$1
    shift
    val="$(dialog \
      --title "$title" \
      --insecure \
      --passwordbox "$text" 0 0 "$@" 2>&1 1>&4 
    )"

    echo $val
}

function menu_disk_size() {
    menu_inputbox "Disk size" "Please write size of disk in GB" "$@"
}

function menu_memory() {
    menu_inputbox "Memory size" "Please write size of ram in MB" "$@"
}

function menu_vram() {
    menu_inputbox "VRAM size" "Please write size of video ram in MB" "$@"
}

function menu_cpus() {
    menu_inputbox "CPU count" "Please write count of CPUs" "$@"
}

function menu_vnc_pass() {
    menu_passwordbox "VNC password" "Please provide password for VNC access" "$@"
}

function menu_user_name() {
    menu_inputbox "User name" "Please provide system user name" "$@"
}

function menu_user_pwd() {
    menu_passwordbox "User password" "Please provide system user password" "$@"
}

function menu_net() {
    menu_inputbox "Network address" "Please set network in form x.x.x.x/x" "$@"
}

function menu_disk_source() {
    #TODO: Need to check disk space and available disks
    
    disks=()
    for disk in $( lsblk -p | awk '{ if ($6 == "disk" ) print $1}' ); do
        disks+=(disk)
        disks+=(disk)
    done

    disk_source=$(dialog \
      --title "Disk source" \
      --no-cancel \
      --default-item "$1" \
      --menu "Please choose disk source:" 0 0 4 \
      ${disks[@]} \
      "disk" "Use free disk space" \
      "file" "Use file image in filesystem" \
      "back" "Go to previous menu" \
      "main" "Go to main menu" \
      "exit" "Exit script" \
      2>&1 1>&4 )

    echo $disk_source
}

function menu_iso() {
    iso=$(dialog \
      --title "Select path to iso file" \
      --fselect "$1" 0 0 \
      2>&1 1>&4 )
    echo "$iso"
}

function menu_start() {
    msg="$@"
    dialog \
        --title "Will start creating" \
        --clear \
        --no-collapse \
        --yesno "${msg}" 0 0 2>&1 1>&4

    echo "$?"
}
