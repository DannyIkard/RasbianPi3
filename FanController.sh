#!/bin/bash
while true; do
	CPUTEMPA=$(</sys/class/thermal/thermal_zone0/temp)
	CPUTEMP=$((CPUTEMPA/1000))
	if [[ $CPUTEMP -gt 74 ]]; then
		gpio -g mode 4 out
		gpio -g write 4 1
	fi
	if [[ $CPUTEMP -lt 65 ]]; then
		gpio -g mode 4 out
		gpio -g write 4 0
	fi
	sleep 1
done