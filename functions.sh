#!/bin/bash
#Useful functions for this script

catch() {
  echo "Got some error on line $1"
  exit 0
}

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

