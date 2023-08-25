#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
[ "$EUID" -ne 0 ] && err "Script sould be started as root"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh

items=()

for vm in $WDIR/*; do
  items+=(${vm##*/} $vm)
done

exec 4>&1
selection="$(dialog \
  --title "Delete VM" \
  --clear \
  --cancel-label "Exit" \
  --menu "Please select VM to delete:" 0 0 4 \
  ${items[@]} \
  2>&1 1>&4
)"

exec 4>&-

if [ -z "$selection"]; then
  dialog --title "No selection, will exit"
  exit 0
fi

echo "selected $selection"

	# TODO: path to get enabled systemd services
	# /etc/systemd/system/getty.target.wants/win@common.service
