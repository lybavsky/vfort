#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh

#If not root then exit
[ "$EUID" -ne 0 ] && err "Script sould be started as root"

if [ $# == 1 ]; then
  echo "Passed parameter: $1"
fi
