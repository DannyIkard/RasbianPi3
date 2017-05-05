#!/bin/bash
clear
while true; do
	A="`gpio read 135`";
	if [[ "$A" != "0" ]]; then
		echo "Undervolt"
	fi
done