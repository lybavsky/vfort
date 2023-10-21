#!/bin/bash
set -e 
set -o pipefail 

CDIR="`dirname $( readlink -f $0 )`"
source ${CDIR}/vars.sh
source ${CDIR}/functions.sh
source ${CDIR}/create.sh
source ${CDIR}/delete.sh

source ${CDIR}/menu.sh

#If not root then exit
#TODO: Enable root check back
# [ "$EUID" -ne 0 ] && err "Script sould be started as root"


struct="
name: ''
disk:
  size: 10
  source: file
memory_mb: 1024
vram_mb: 64
cpus: 1
vnc:
  pwd: ''
rde:
  user: admin
  pwd: admin
user:
  name: username
  pwd: ''
net: 192.168.0.0/24
iso: /path_to_image.iso
"

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
  menu_last="$(( ${#prev_menu[@]} - 1  ))"

  curr_menu="${prev_menu[$menu_last]}"
  unset -v prev_menu[$menu_last]

  curr_params="${prev_params[$menu_last]}"
  unset -v prev_params[$menu_last]
}

function set_menu() {
  prev_menu+=("$curr_menu")
  prev_params+=("$curr_params")
  curr_menu="$1"
  curr_params="$2"
}

function process_int_msg() {
  tmpl_path="$1"
  result="$2"
  msg_err_valid="$3"
  next_menu="$4"
  new_tmpl_path="$5"

  if [ "$result" == "" ]; then
    last_menu
  elif [[ ! "$result" =~ ^[0-9]*$ ]]; then 
    set_menu menu_err_message "$msg_err_valid"
  else
    struct="$(setyval "$struct" "$tmpl_path" "$result")"
    tmpl_param="`getyval "$struct" $new_tmpl_path`"
    set_menu $next_menu "$tmpl_param"
  fi
}

function process_str_msg() {
  tmpl_path="$1"
  result="$2"
  next_menu="$3"
  new_tmpl_path="$4"

  if [ "$result" == "" ]; then
    last_menu
  else
    struct="$(setyval "$struct" "$tmpl_path" '"'"$result"'"')"
    tmpl_param="`getyval "$struct" $new_tmpl_path`"
    set_menu $next_menu "$tmpl_param"
  fi
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
      set_menu menu_delete ""
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
        menu_delete)
          if [ "$result" != "" ]; then
            vm_delete $result
          else 
            last_menu
          fi
          ;;
        menu_create)
          if [ "$result" == "" ]; then
            last_menu
          elif [[ ! "$result" =~ ^[0-9a-zA-Z]*$ ]]; then 
            set_menu menu_err_message "VM name should contain only latin symbols and numbers"
          else
            struct="$(setyval "$struct" .name '"'"$result"'"')"


            tmp_param="`getyval "$struct" .disk.size`"
            set_menu menu_disk_size "$tmp_param"
          fi
          ;;
        menu_disk_size)
          process_int_msg .disk.size "$result"  "Disk size should be integer number" \
            menu_disk_source .disk.source
          ;;
        menu_disk_source)
          struct="$(setyval "$struct" .disk.source '"'"$result"'"')"

          set_menu menu_memory "`getyval "$struct" .memory_mb`"
          ;;
        menu_memory)
          process_int_msg .memory_mb "$result" "Memory should be integer number" \
            menu_vram .vram_mb
          ;;
        menu_vram)
          process_int_msg .vram_mb "$result" "Video memory should be integer number" \
            menu_cpus  .cpus
          ;;
        menu_cpus)
          process_int_msg .cpus "$result" "CPU count should be integer number" \
            menu_vnc_pass .vnc.pwd
          ;;
        menu_vnc_pass)
          process_str_msg .vnc.pwd "$result" menu_user_name .user.name
          ;;
        menu_user_name)
          process_str_msg .user.name "$result" menu_user_pwd .user.pwd
          ;;
        menu_user_pwd)
          process_str_msg .user.pwd "$result" menu_net .net
          ;;
        menu_net)
          if [ "$result" == "" ]; then
            last_menu
          else 
            val_msg="$( validate_cidr $result )"

            if [ "$val_msg" != "" ]; then 
              set_menu menu_err_message "$val_msg"
            else
              struct="$(setyval "$struct" .net '"'"$result"'"')"
              tmp_param="`getyval "$struct" .iso`"
              set_menu menu_iso "$tmp_param"
            fi
          fi
          ;;
        menu_iso)
          if [ "$result" == "" ]; then
            last_menu
          else
            struct="$(setyval "$struct" .iso '"'"$result"'"')"

            if [ ! -f "$result" ]; then
              set_menu menu_err_message "There is no file $result"
            elif [[ ! "$result" =~ ^.*.iso$ ]]; then
              set_menu menu_err_message "File $result has no .iso postfix"
            else 
              set_menu menu_start "Will start process\n${struct//$'\n'/\\n}\nContinue?"
            fi
          fi
          ;;
        menu_start)
          if [ "$result" -eq 1 ]; then
            last_menu
          else
            echo "Will start"

            res=$( vm_create "$( echo "${struct[@]}" | yq -c )" 2>&1 1>&4 )

            echo "res is $res"
            sleep 10

          fi
          ;;
        *)
          err "Unknown result of menu $curr_menu: $result"
          exit 1
          ;;
      esac
      ;;
  esac

  # sleep 1


done

echo "after menu"
