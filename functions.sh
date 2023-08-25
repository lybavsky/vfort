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
# function parse_ip() {
#   str=$1
#   ipstr=${str%%\/[0-9]*}
#   cidrstr=${str##*\/}
#   ip_to_dec $ipstr
#   dec_to_ip "$( ip_to_dec $ipstr )"
#   get_net $ipstr $cidrstr
#   get_net_cnt $cidrstr
#   is_ip_in_net 192.168.0.0/24 192.168.1.255
#
# get_short_mask 255.255.255.0
#   ip_gw="$( get_nth_ip $ipstr $cidrstr 1 )"
#   ip_dhcp="$( get_nth_ip $ipstr $cidrstr 2 )"
#   ip_first="$( get_nth_ip $ipstr $cidrstr 3 )"
#   ip_last="$( get_nth_ip $ipstr $cidrstr -2 )"
#   ip_mask="$( get_long_mask $cidrstr )"
#   echo "ip_gw $ip_gw, ip_dhcp $ip_dhcp, ip_first $ip_first, ip_last $ip_last, ip_mask $ip_mask"
#
# }
# parse_ip 192.168.0.148/26
#NET FUNCTIONS BLOCK

function get_vt() {
pth=$1
used=( $( cat $pth/*/start.sh | awk '{print substr($4,2)}' ) )
for i in `seq 1 10`; do
  if [[ ! "${used[@]}" =~ "$i" ]]; then
    echo "$i"
    return
  fi
done
echo -1
return
}

