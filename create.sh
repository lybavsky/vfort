set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh


function create() {
  clear
  echo "Will create VM: $0"
  sleep 2
}
