#!/bin/bash 

#TODO: get event source
evtest /dev/input/event4 | while read l; do
if [[ "${l}" =~ value\ 0 ]]; then
	echo "Got press"

	if [[ "${l}" =~ code\ 113 ]]; then
			echo "Switch VT"
			AC="$( cat /sys/class/tty/tty0/active | sed 's/[^0-9]*//g' )";
			TTYS=( $( cat /srv/vm/*/start.sh | awk '{print substr($4,2)}' ) )

			cur=-1
			for i in `seq 1 ${#TTYS[@]}`; do
				if [ "$i" == "$AC" ]; then
					cur="$i"
					break
				fi
			done

			if [ "$cur" == -1 ]; then
				cur=0
			elif [ "$cur" == "${#TTYS[@]}" ]; then
				cur=0
			else
				cur="$(( cur + 1 ))"
			fi

			chvt $cur
			vm_name="$( for i in /srv/vm/*/start.sh; do if $( grep -q vt$cur $i ); then echo $i; fi; done | sed -e 's/\/start.sh//g;s/^.*\///g' )"
			DISPLAY=:$cur timeout 3 sm  "VM $vm_name"

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
