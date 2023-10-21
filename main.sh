#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh
source ${CDIR}/create.sh

source ${CDIR}/menu.sh

#If not root then exit
#TODO: Enable root check back
# [ "$EUID" -ne 0 ] && err "Script sould be started as root"


struct=""

if [ $# == 1 ]; then
  echo "Passed parameter: $1"
  [ ! -f "$1" ] && err "File $1 not exists. If you pass param, it should be path to yaml file"
  TMPL=1
  struct="$(cat $1)"
fi


function catch() {
  echo "RC $?: catched $0"
}

trap catch 2


prev_menu=()
prev_params=()
curr_menu="menu_main"
curr_params=""

function last_menu() {
  # clear
  # echo "last_menu before curr_menu: $curr_menu, hist: '${prev_menu[@]}'"
  menu_last="$(( ${#prev_menu[@]} - 1  ))"

  curr_menu="${prev_menu[$menu_last]}"
  unset -v prev_menu[$menu_last]

  curr_params="${prev_params[$menu_last]}"
  unset -v prev_params[$menu_last]

  # echo "last_menu after curr_menu: $curr_menu, hist: '${prev_menu[@]}'"
  # sleep 5
}

function set_menu() {
  prev_menu+=("$curr_menu")
  prev_params+=("$curr_params")
  curr_menu="$1"
  curr_params="$2"

}


exec 4>&1

while true; do
  # clear
  # echo "curr act is '$curr_menu' with params '$curr_params'"
  # echo "curr hist is (${prev_menu[@]})"
  # sleep 1

  result=$(eval "$curr_menu \"$curr_params\"")
  curr_params="$result"

  case "$result" in
    create)
      set_menu menu_create ""
      ;;
    delete)
      echo "will open delete menu"
      ;;
    main)
      curr_menu="menu_main"
      curr_params=""
      prev_menu=()
      continue
      ;;
    back)
      echo "will go to previous menu"
      last_menu
      ;;
    exit)
      exit 0
      ;;
    *)
      case "$curr_menu" in
        menu_err_message)
          last_menu
          ;;
        menu_create)
          if [ "$result" == "" ]; then
            last_menu
          elif [[ ! "$result" =~ ^[0-9a-zA-Z]*$ ]]; then 
            set_menu menu_err_message "VM name should contain only latin symbols and numbers"
          else
            tmp_param="`getyval "$struct" .disk.size`"
            set_menu menu_disk_size "$tmp_param"         
          fi
        ;;
      menu_disk_size)
        if [[ ! "$result" =~ ^[0-9]*$ ]]; then
          set_menu menu_err_message "Disk size should be integer number"
        else
          tmp_param="`getyval "$struct" .disk.type`"
          set_menu menu_disk_type "$tmp_param"
        fi
        ;;
      esac
      ;;
  esac

  # sleep 1


done

echo "after menu"
