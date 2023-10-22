#!/bin/bash

#TODO: get event source
evtest /dev/input/event4 | while read l; do
if [[ "${l}" =~ value\ 0 ]]; then
        echo "Got press"

        AC="$( cat /sys/class/tty/tty0/active | sed 's/[^0-9]*//g' )";
        TTYS=( $( cat /srv/vm/*/start.sh | awk '{print substr($5,3)}' ) )

        echo "TTYS is ( ${TTYS[@]} )"
        echo "AC is $AC"

        cur=-1
        for i in `seq 0 $(( ${#TTYS[@]} - 1 ))`; do
                echo "try $i"
                if [ "${TTYS[$i]}" == "$AC" ]; then
                        cur="$i"
                        break
                fi
        done

        echo "cur is $cur"

        if [[ "${l}" =~ code\ 113 ]]; then
                        echo "Switch VT"

                        if [ "$cur" == -1 ]; then
                                cur=0
                        elif [ "$cur" -eq  $(( "${#TTYS[@]}" - 1 )) ]; then
                                cur=0
                        else
                                cur="$(( cur + 1 ))"
                        fi

                        echo "newcur is $cur"
                        newvt="${TTYS[$cur]}"
                        echo "newvt is $newvt"
                        chvt $newvt
                        vm_name="$( for i in /srv/vm/*/start.sh; do if $( grep -q vt$newvt $i ); then echo $i; fi; done | sed -e 's/\/start.sh//g;s/^.*\///g' )"
                        # DISPLAY=:$newvt timeout 3 /usr/games/sm  "VM $vm_name"

                        available_vms=( $( for i in /srv/vm/*/start.sh; do i=${i%/*}; i=${i##*/}; if [ "$i" != "$vm_name" ]; then echo "$i"; fi; done ) )
                        available_msg=""
                        if [ ${#available_vms[@]} -gt 0 ]; then
                                available_msg="
Available VMs:"
                                for vm in ${available_vms[@]}; do
                                        available_msg="${available_msg}
${vm}"
                                done
                        fi

                        DISPLAY=:$newvt xmessage -buttons '' -timeout 1 "Switched to '$vm_name' VM ${available_msg}"

        elif [[ "${l}" =~ code\ 115 ]]; then
                        echo "Volume up"
                        amixer set Master 10%+
                        vol="$(amixer get Master | awk '/\[.*\]/{print substr($4,2,length($4)-2)}')"
                        newvt="${TTYS[$cur]}"
                        DISPLAY=:$newvt xmessage -buttons '' -timeout 1 "Set vol $vol"
        elif [[ "${l}" =~ code\ 114 ]]; then
                        echo "Volume down"
                        amixer set Master 10%-
                        vol="$(amixer get Master | awk '/\[.*\]/{print substr($4,2,length($4)-2)}')"
                        newvt="${TTYS[$cur]}"
                        DISPLAY=:$newvt xmessage -buttons '' -timeout 1 "Set vol $vol"
        elif [[ "${l}" =~ code\ 191 ]]; then
                        echo "Get console"
                        newvt="${TTYS[$cur]}"
                        DISPLAY=:$newvt xmessage -buttons '' -timeout 1 "Get console"
                        chvt 1
        fi

fi
done
