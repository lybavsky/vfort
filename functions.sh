#!/bin/bash
#Useful functions for this script

catch() {
  echo "Got some error on line $1"
  exit 0
}

function nferr() {
	msg="$@"
	echo "Error: $msg" >&2
}

function err() {
	msg="$@"
	echo "Error: $msg"
	exit 1
}


function getval() {
	json=$1
	val=$2

	echo "${json[@]}" | jq -r ".value$val"
}

function getkey() {
	json=$1

	echo "${json[@]}" | jq -r ".key"
}

function getyval() {
	json=$1
	val=$2

	echo "${json[@]}" | yq -r "$val"
}

function setyval() {
  if [ $# -ne 3 ]; then
    return
  fi

  json=$1
  key=$2
  val=$3

  echo "${json[@]}" | yq --yaml-output "$key|=$val"
}

function umount_re() {
	vmname=$1
	re=$2

	vboxmanage showvminfo $vmname | grep "$re" | while read l; do 
	  echo "umount $l"
  	ctrl="${l%% \(*}"
  	num="${l%%)*}"
  	dev="${num##*, }"
  	port="${num##* (}"; port="${port%%, *}"
  	vboxmanage storageattach $vmname --storagectl "$ctrl" --port "$port" --device "$dev" --type hdd --medium none || echo fail
  done
}


#NET FUNCTIONS BLOCK
function ip_to_dec() {
  dec=0
  IFS="." read -a octs <<< "$1"
  for i in 0 1 2 3; do
    dec="$(( dec * 256 + ${octs[i]} ))"
  done
  echo "$dec"
}

function dec_to_ip() {
  dec=$1
  str=""
  for i in `seq 1 4`; do
    mod="$(( $dec % 256 ))"
    dec="$(( $dec / 256 ))"
    str=$mod"."$str
  done

  echo ${str%%.}
}

# usage: get_net IP.IP.IP.IP MASK
function get_net() {
  ip=$1
  mask=$2
  dec="$( ip_to_dec $ip )"
  mdec="$(( dec / 256 * 256 ))"
  echo "$( dec_to_ip $mdec )"
}

function get_gw() {
  ip=$1
  mask=$2
  dec="$( ip_to_dec $ip )"
  mdec="$(( dec / 256 * 256 + 1 ))"
  echo "$( dec_to_ip $mdec )"
}

function get_net_cnt() {
  hosts=1
  for i in `seq $1 1 31`; do
    hosts="$(( hosts * 2 ))"
  done
  echo $hosts
}

function get_nth_ip() {
  ip=$1
  mask=$2
  nth=$3
  dec="$( ip_to_dec $ip )"
  cnt="$( get_net_cnt $mask )"
  if [ "$nth" -ge 0 ]; then
    mdec="$(( dec / $cnt * $cnt + ( $nth ) ))"
  else
    mdec="$(( ( (dec / $cnt ) + 1 ) * $cnt + ( $nth ) ))"
  fi
  echo "$( dec_to_ip $mdec )"
}

function get_long_mask() {
  max="$( ip_to_dec 255.255.255.255 )"
  cnt="$( get_net_cnt $1 )"
  mask="$(( max - cnt + 1 ))"
  echo "$( dec_to_ip $mask )"
}

function get_mask_from_cnt() {
  cnt=$1
  mask=32
  while [ $cnt -gt 1 ]; do
    cnt="$(( cnt / 2 ))"
    mask="$(( mask - 1 ))"
  done

  echo $mask
}

function get_short_mask() {
  max="$( ip_to_dec 255.255.255.255 )"
  mask="$( ip_to_dec $1 )"
  cnt="$(( $max - $mask + 1 ))"
  echo "$( get_mask_from_cnt $cnt)"
}

function is_ip_in_net() {
  str=$1
  ip=$2
  ipstr=${str%%\/[0-9]*}
  cidrstr=${str##*\/}

  first="$( ip_to_dec `get_nth_ip $ipstr $cidrstr 0 ` )"
  last="$( ip_to_dec `get_nth_ip $ipstr $cidrstr -1 ` )"
  ipdec="$( ip_to_dec $ip )"

  if [ $first -le $ipdec -a $ipdec -le $last ]; then
    echo 1
  else
    echo 0
  fi

}

function validate_cidr() {
  ip_net="$1"
  ipstr=${ip_net%%\/[0-9]*}
  cidrstr=${ip_net##*\/}

  ip_net="$( get_net $ipstr $cidrstr )"
  ip_gw="$( get_nth_ip $ipstr $cidrstr 1 )"
  ip_dhcp="$( get_nth_ip $ipstr $cidrstr 2 )"
  ip_first="$( get_nth_ip $ipstr $cidrstr 3 )"
  ip_last="$( get_nth_ip $ipstr $cidrstr -2 )"
  ip_mask="$( get_long_mask $cidrstr )"

  if [ "$ip_net" != "$ipstr" ]; then
  	echo "Net parameter should be CIDR net, instead we got $ipstr"
	elif [ "$cidrstr" -gt 29 ]; then
  	echo "Mask should be 29 and less"
  fi
}

#NET FUNCTIONS BLOCK

function get_vt() {
pth=$1
used=( $( cat $pth/*/start.sh | awk '{print substr($4,2)}' ) )
for i in `seq 2 10`; do
  if [[ ! "${used[@]}" =~ "$i" ]]; then
    echo "$i"
    return
  fi
done
echo -1
return
}


function vm_state() {
  vboxmanage showvminfo $1 | awk '/^State:/{ print gensub(/State: *(.*) \(.*$/,"\\1","g",$0) }'
}
function vm_running() {
  if [ "$(vm_state $1 )" == "powered off" ]; then
    echo 0
  else
    echo 1
  fi
}


#Usage: got type (like hostonlyifs) and name, 3rd - optional - Field to start write
function vbox_show() {
  kind=$1
  name=$2
  field=$3
  [ -z "$field" ] && field="Name"
  vboxmanage list $kind | awk -v ifname=$name '
  BEGIN{ inv=0 }
  {
    if ( $1 == "'"$field"':" ) { 
      if ( $2==ifname ) { inv=1 } 
      else { inv=0 } 
      }; 
    if ( inv==1 ) { 
      print $0 
    } 
  }'
}
