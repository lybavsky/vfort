set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh

function vm_delete() {
  name="$1"
  echo "VM to delete: $name"
}
