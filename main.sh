#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh

#If not root then exit
#TODO: Enable root check back
# [ "$EUID" -ne 0 ] && err "Script sould be started as root"

if [ $# == 1 ]; then
  echo "Passed parameter: $1"
  [ ! -f "$1" ] && err "File $1 not exists. If you pass param, it should be path to yaml file"
fi


while :; do 
    exec 4>&1
    action=$(dialog \
      --title "Delete VM" \
      --clear \
      --no-cancel \
      --menu "Please select VM to delete:" 0 0 4 \
      "create" "Create new VM" \
      "delete" "Delete VMs" \
      "exit" "Exit script" \
      2>&1 1>&4 )

case $action in
  exit) 
    exit 0
    ;;
  *)
    clear
    echo "$action"
    sleep 1
    ;;
esac


done
