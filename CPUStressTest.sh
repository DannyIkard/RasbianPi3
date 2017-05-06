#!/bin/bash
. ./SharedLib
trap 'Stop' SIGINT

SV="/dev/shm/PiClocker/vars";
mkdir -p $SV


WrapUp() {
	killall -SIGTERM "`cat $SV/SubPID`" 2>/dev/null;
	rm -rf $SV
	exit 0;
}


Stop() {
	killall stress;
	EchoRed "Aborted.  Exiting...";
	killall -SIGTERM stress 2</dev/null;
	WrapUp
}


function SystemMonitorSub(){
      (
	echo "$$" >>$SV/SubPID;
      while true; do
	LASTLTIMED="$THISLTIMED";
	THISLTIMED=$(date +%s);
	LITIMED=$((THISLTIMED-LASTLTIMED));
	TOTALTIMED=$((THISLTIMED-LAUNCHTIMED));
	TOTALTIME=$(date +%H:%M:%S --date @$TOTALTIMED)
	STRESSPID=`ps ax | grep stress | grep -v grep | head -1 | awk '{print $1;}'`;
	CPUTEMPA=$(</sys/class/thermal/thermal_zone0/temp)
	CPUTEMP=$((CPUTEMPA/1000))
	GPUTEMP=`/opt/vc/bin/vcgencmd measure_temp | cut -d '=' -f2 | cut -d "'" -f1 | awk '{print int($1)}'`
	ARMCLOCK=$((`/opt/vc/bin/vcgencmd measure_clock arm | cut -d '=' -f2`/1000000))
	if [[ $ARMCLOCK -lt $((CPUFREQ-2)) ]]; then
		THROTTLE=`EchoRed 'Throttled'`;
		THROTTLEDTIMED=$((THROTTLEDTIMED+LITIMED));
	else
		THROTTLE="         ";
	fi
	THROTTLEDPCNT=`awk -v t1="$THROTTLEDTIMED" -v t2="$TOTALTIMED" 'BEGIN{printf "%.0f", t1/t2 * 100}'`;
	if [[ $THROTTLEDPCNT -gt 5 ]]; then
		THROTTLEDPCNTCOLORED=`EchoRed "${THROTTLEDPCNT}%"`;
	else
		THROTTLEDPCNTCOLORED=`EchoGreen "${THROTTLEDPCNT}%"`;
	fi
	if [[ $ARMCLOCK -lt $((CPUFREQ-100)) ]]; then
		ARMCLOCKCOLORED=`EchoRed ${ARMCLOCK}Mhz`;
	elif [[ $ARMCLOCK -lt $((CPUFREQ-6)) ]]; then
		ARMCLOCKCOLORED="${ARMCLOCK}Mhz";
	else
		ARMCLOCKCOLORED=`EchoGreen ${ARMCLOCK}Mhz`;
	fi
#	if [[ $ARMCLOCK -eq 600 ]]; then
		


#	if [[ $ARMCLOCK -ge $((CPUFREQ-6)) ]]; then
#		ARMCLOCKCOLORED=`EchoGreen ${ARMCLOCK}Mhz`;
#	fi
	if [[ $CPUTEMP -lt $((TEMPLIMIT-10)) ]]; then
		CPUTEMPCOLORED=`EchoGreen $CPUTEMP"'C"`;
	else
		CPUTEMPCOLORED=`EchoRed $CPUTEMP"'C"`;
	fi
	if [[ $GPUTEMP -lt $((TEMPLIMIT-10)) ]]; then
		GPUTEMPCOLORED=`EchoGreen $GPUTEMP"'C"`;
	else
		GPUTEMPCOLORED=`EchoRed $GPUTEMP"'C"`;
	fi
#	if [[ $GPUTEMP -lt $((CPUTEMP-2)) || $GPUTEMP -gt $((CPUTEMP+2)) ]]; then
#		GPUTEMPVARI="GPU Temp: $GPUTEMPCOLORED"
#	else
#		GPUTEMPVARI=""
#	fi
	TITLE=`Title "Raspberry Pi 3 Stress Tester - $TOTALTIME"`;
	SEP=`Separator '_'`;

	PWRLOWN="`gpio read 135`";
	if [ $PWRLOWN -ne 0 ]; then
		echo "$PWRLOWN    $(date +%H:%M:%S)" >>PWRLOWN.log;
		PWRLOWNTXT="`EchoRed 'Power supply undervoltage detected'`";
		echo "$PWRLOWNTXT" >$SV/PWRLOWNTXT;
		echo "*" >$SV/PWRLOWNIND;
	else
		echo " " >$SV/PWRLOWNIND;
	fi

	echo "$TOTALTIME" >$SV/TOTALTIME;
	echo "$ARMCLOCKCOLORED" >$SV/ARMCLOCKCOLORED;
	echo "$THROTTLE" >$SV/THROTTLE;
	echo "$THROTTLEDPCNTCOLORED" >$SV/THROTTLEDPCNTCOLORED;
	echo "$CPUTEMPCOLORED" >$SV/CPUTEMPCOLORED;
	echo "$GPUTEMPCOLORED" >$SV/GPUTEMPCOLORED;
	echo "$SEP" >$SV/SEP;
	echo "$TITLE" >$SV/TITLE;
	echo "$CPUTEMP" >$SV/CPUTEMP;

	sleep .2
      done;
	) &
}



LAUNCHTIMED=$(date +%s);
LASTLTIMED=$(date +%s);
THISLTIMED=$(date +%s);
TOTALTIMED=0;
TOTALTIME="00:00:00";
THROTTLEDTIMED=0;
CPUMINFREQ=$((`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq`/1000))
CPUMAXFREQ=$((`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq`/1000))
MEMVOLTC=`/opt/vc/bin/vcgencmd measure_volts sdram_c | cut -d '=' -f2`
MEMVOLTI=`/opt/vc/bin/vcgencmd measure_volts sdram_i | cut -d '=' -f2`
MEMVOLTP=`/opt/vc/bin/vcgencmd measure_volts sdram_p | cut -d '=' -f2`
COREVOLT=`/opt/vc/bin/vcgencmd measure_volts core | cut -d '=' -f2`
TEMPLIMIT=`/opt/vc/bin/vcgencmd get_config temp_limit | cut -d '=' -f2`
SDRAMFREQ=`/opt/vc/bin/vcgencmd get_config sdram_freq | cut -d '=' -f2`
MEMOVERVOLTC=`/opt/vc/bin/vcgencmd get_config over_voltage_sdram_c | cut -d '=' -f2`
MEMOVERVOLTI=`/opt/vc/bin/vcgencmd get_config over_voltage_sdram_i | cut -d '=' -f2`
MEMOVERVOLTP=`/opt/vc/bin/vcgencmd get_config over_voltage_sdram_p | cut -d '=' -f2`
GPUFREQ=`/opt/vc/bin/vcgencmd get_config gpu_freq | cut -d '=' -f2`
STOPTEMP=83
CTRLC=`EchoBold 'Press Ctrl+C to exit...'`;
CPUFREQ=$((`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`/1000))
PWRLOWNTXT="";

function SystemMonitor(){
	TOTALTIME="`cat $SV/TOTALTIME`";
	ARMCLOCKCOLORED="`cat $SV/ARMCLOCKCOLORED`";
	THROTTLE="`cat $SV/THROTTLE`";
	THROTTLEDPCNTCOLORED="`cat $SV/THROTTLEDPCNTCOLORED`";
	CPUTEMPCOLORED="`cat $SV/CPUTEMPCOLORED`";
	GPUTEMPCOLORED="`cat $SV/GPUTEMPCOLORED`";
	SEP="`cat $SV/SEP`";
	TITLE="`cat $SV/TITLE`";
	CPUTEMP="`cat $SV/CPUTEMP`";
	PWRLOWNTXT="`cat $SV/PWRLOWNTXT 2>/dev/null`";
	PWRLOWNIND="`cat $SV/PWRLOWNIND 2>/dev/null`";

	A="$TITLE";
	B="  CPU Current: ${CPUFREQ}Mhz @ $COREVOLT     Min:${CPUMINFREQ}Mhz  Mhz Max:${CPUMAXFREQ}Mhz";
	C="  SDRAM Voltage:  C=$MEMOVERVOLTC/$MEMVOLTC  I=$MEMOVERVOLTI/$MEMVOLTI  P=$MEMOVERVOLTP/$MEMVOLTP";
	D="  SDRAM Frequency: ${SDRAMFREQ}Mhz     GPU Frequency: ${GPUFREQ}Mhz";
	E="  Max Temp: $TEMPLIMIT'C";
	AA="  ARM Clock: ${ARMCLOCKCOLORED} $THROTTLE";
	AB="  CPU Temp: $CPUTEMPCOLORED"
	AC="  GPU Temp: $GPUTEMPCOLORED";
	AD="  Percentage ARM spent throttled: $THROTTLEDPCNTCOLORED";
	AE="  ${PWRLOWIND}${PWRLOWTXT}${PWRLOWIND}";
	sleep .8
	clear

	printf "%s\n\n" "$A"
	printf "%s\n" "$B"
	printf "%s\n" "$C"
	printf "%s\n" "$D"
	printf "%s\n" "$E"
        printf "%s\n" "$SEP"
        printf "%s\n" "$AA"
        printf "%s\n" "$AB"
        printf "%s\n" "$AC"
        printf "%s\n" "$AD"
        printf "%s\n" "$AE"
        printf "%s\n" "$SEP"
#        if [[ $CPUTEMP -ge $STOPTEMP || $GPUTEMP -ge $STOPTEMP ]]; then
#                echo "****  $STOPTEMP DEGREES REACHED - STOPPING TEST  *****"
#                killall dd
#                exit 0
#        fi
	printf "%s\n" "$CTRLC"
};





#----------------------------------------------------------------------------------------------------------------------
clear
TIME="$(date +%H:%M:%S)"; Title "Raspberry Pi Stress Tester - $TIME"

if [[ $(dpkg-query -W -f='${Status}' stress 2>/dev/null | grep -c "ok installed") = "0" ]]; then
	printf "\n"
	EchoBold "Installing stress..."
	Separator "_"
	sudo apt-get install stress
	sleep 5
	clear; TIME="$(date +%H:%M)"; Title "Raspberry Pi Stress Tester - $TIME"
fi



if [[ ! -f cpuburn-a53 ]]; then
	printf "\n"
	EchoBold "Downloading cpuburn..."
	Separator "_"
	wget https://raw.githubusercontent.com/ssvb/cpuburn-arm/master/cpuburn-a53.S
	gcc -o cpuburn-a53 cpuburn-a53.S
	rm -rf cpuburn-a53.S
	sleep 5
	clear; TIME="$(date +%H:%M)"; Title "Raspberry Pi Stress Tester - $TIME"
fi

echo "performance" | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
stress -c 4 -t 900s &
STRESSPID="`ps ax | grep stress | grep -v grep | head -1 | awk '{print $1;}'`";
if [[ "$STRESSPID" = "" ]]; then EchoRed "stress failed to start.  Exiting...  "; Stop; fi
SystemMonitorSub
sleep 1
while [ "$STRESSPID" != "" ]; do
	SystemMonitor
done
WrapUp