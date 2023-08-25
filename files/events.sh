#!/bin/bash

#TODO: get event source
evtest /dev/input/event4 | while read l; do
if [[ "${l}" =~ value\ 0 ]]; then
        echo "Got press"

        if [[ "${l}" =~ code\ 113 ]]; then
                        echo "Switch VT"
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
                        DISPLAY=:$newvt timeout 3 sm  "VM $vm_name"

        elif [[ "${l}" =~ code\ 115 ]]; then
                        echo "Volume up"
                        amixer set Master 10%+
        elif [[ "${l}" =~ code\ 114 ]]; then
                        echo "Volume down"
                        amixer set Master 10%-
        elif [[ "${l}" =~ code\ 191 ]]; then
                        echo "Get console"
                        chvt 3
        fi

fi
done
