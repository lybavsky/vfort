#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
[ "$EUID" -ne 0 ] && err "Script sould be started as root"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh


	# TODO: path to get enabled systemd services
	# /etc/systemd/system/getty.target.wants/win@common.service
