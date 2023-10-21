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


function menu_disk_size() {
    size="$(dialog \
      --title "Disk type" \
      --inputbox "Please write size of disk in GB" 0 0 "$@" 2>&1 1>&4 
    )"

    echo $size
}

function menu_disk_type() {
    #Need to check disk space and available disks
    action=$(dialog \
      --title "Disk type" \
      --no-cancel \
      --default-item "$1" \
      --menu "Please choose disk type:" 0 0 4 \
      "disk" "Use free disk space" \
      "file" "Use file image in filesystem" \
      "back" "Go to previous menu" \
      "main" "Go to main menu" \
      "exit" "Exit script" \
      2>&1 1>&4 )

    echo $action
}
