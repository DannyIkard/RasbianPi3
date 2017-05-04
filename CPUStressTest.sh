#!/bin/bash
trap 'stop' SIGINT

GetScreenWidth(){
  stty size 2>/dev/null | cut -d " " -f2
}

Separator(){
  if [ $1 ]; then local sepchar="$1"; else local sepchar=" "; fi
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  for x in $(seq 1 $cols); do
    echo -n "$sepchar"
  done && echo ""
}

EchoBold(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[1m$@\033[0m"; else echo -e "\033[1m$@\033[0m"; fi
}



EchoRed(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[1;31m$@\033[0m"; else echo -e "\033[1;31m$@\033[0m"; fi
}



EchoGreen(){
  if [ "$1" = "-n" ]; then shift; echo -en "\033[38;5;22;1m$@\033[0m"; else echo -e "\033[38;5;22;1m$@\033[0m"; fi
}



Title(){
  echo -en "\033[7;1m"
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  (( Spacer = cols - ${#1} ))
  (( Spacer = Spacer / 2 ))
  for x in $(seq 1 $Spacer); do
    echo -n " "
  done
  echo -en "$1"
  local cols=$(GetScreenWidth)
  [ "$cols" ] || cols=80
  for x in $(seq 1 $Spacer); do
    echo -n " "
  done && echo -n " "; echo -e "\033[0m"
}



stop() {
	killall stress;
	EchoRed "Aborted.  Exiting...";
	killall -SIGTERM stress 2</dev/null;
	exit 0;
}



function SystemMonitor(){
	STRESSPID=`ps ax | grep stress | grep -v grep | head -1 | awk '{print $1;}'`;
	TIME="$(date +%H:%M:%S)"
	CPUTEMPA=$(</sys/class/thermal/thermal_zone0/temp)
	CPUTEMP=$((CPUTEMPA/1000))
	CPUFREQ=$((`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`/1000))
	GPUTEMP=`/opt/vc/bin/vcgencmd measure_temp | cut -d '=' -f2 | cut -d "'" -f1 | awk '{print int($1)}'`
	ARMCLOCK=$((`/opt/vc/bin/vcgencmd measure_clock arm | cut -d '=' -f2`/1000000))
	if [[ $ARMCLOCK -lt $((CPUFREQ-2)) ]]; then
		Throttle=`EchoRed 'Throttled'`;
	else
		Throttle="         ";
	fi
	if [[ $ARMCLOCK -lt $((CPUFREQ-100)) ]]; then
		ARMCLOCKCOLORED=`EchoRed ${ARMCLOCK}Mhz`;
	elif [[ $ARMCLOCK -lt $((CPUFREQ-6)) ]]; then
		ARMCLOCKCOLORED="${ARMCLOCK}Mhz";
	else
		ARMCLOCKCOLORED=`EchoGreen ${ARMCLOCK}Mhz`;
	fi
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
	if [[ $GPUTEMP -lt $((CPUTEMP-1)) || $GPUTEMP -gt $((CPUTEMP+1)) ]]; then
		GPUTEMPVARI="GPU Temp: $GPUTEMPCOLORED"
	else
		GPUTEMPVARI=""
	fi
	A=`Title "Raspberry Pi 3 Stress Tester - $TIME"`;
	B="  CPU Current: ${CPUFREQ}Mhz @ $COREVOLT     Min:${CPUMINFREQ}Mhz  Mhz Max:${CPUMAXFREQ}Mhz";
	C="  SDRAM Voltage:  C=$MEMOVERVOLTC/$MEMVOLTC  I=$MEMOVERVOLTI/$MEMVOLTI  P=$MEMOVERVOLTP/$MEMVOLTP";
	D="  SDRAM Frequency: ${SDRAMFREQ}Mhz     GPU Frequency: ${GPUFREQ}Mhz";
	E="  Max Temp: $TEMPLIMIT'C";

	AA="  ARM Clock: ${ARMCLOCKCOLORED} $Throttle";
	AB="  CPU Temp: $CPUTEMPCOLORED    $GPUTEMPVARI";

	SEP=`Separator '_'`;
	sleep 1
	clear

	printf "%s\n\n" "$A"
	printf "%s\n" "$B"
	printf "%s\n" "$C"
	printf "%s\n" "$D"
	printf "%s\n" "$E"
        printf "%s\n" "$SEP"
        printf "%s\n" "$AA"
        printf "%s\n" "$AB"
        printf "%s\n" "$SEP"
	printf "%s\n" "$TIM"
        if [[ $CPUTEMP -ge $STOPTEMP || $GPUTEMP -ge $STOPTEMP ]]; then
                echo "****  $STOPTEMP DEGREES REACHED - STOPPING TEST  *****"
                killall dd
                exit 0
        fi
	printf "%s\n" "$CTRLC"
};



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


#----------------------------------------------------------------------------------------------------------------------
clear
TIME="$(date +%H:%M:%S)"; Title "Raspberry Pi Stress Tester - $TIME"
sleep 1

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

clear; TIME="$(date +%H:%M:%S)"; Title "Raspberry Pi Stress Tester - $TIME"
printf "\n%s\n" "`EchoBold 'Setting scaling governor to performance'`"
echo "performance" | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
sleep 2
EchoBold "Starting stress..."
stress -c 4 -t 900s &
sleep 2
STRESSPID="`ps ax | grep stress | grep -v grep | head -1 | awk '{print $1;}'`";
if [[ "$STRESSPID" = "" ]]; then EchoRed "stress failed to start.  Exiting..."; killall stress; exit 1; fi

while [ "$STRESSPID" != "" ]; do
	SystemMonitor
done

printf "\n\n"
exit 0