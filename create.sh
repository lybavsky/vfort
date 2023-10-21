set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh


function vm_create() {
  data="$1"
  jcfg="$( echo "${data[@]}" | yq -c )"
  clear
  echo "Will create VM: ${jcfg[@]}"
  sleep 2
}
