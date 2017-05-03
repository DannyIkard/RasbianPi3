#!/bin/bash
trap 'stop' SIGINT

#echo "performance" | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

stop() { clear; killall dd; printf "%s" "Exited successfully.  Stopped at "; /opt/vc/bin/vcgencmd measure_temp; exit 0; }
fullload() { dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null & }
fullload &

CPUMINFREQ=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq`
CPUMAXFREQ=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq`
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
STOPTEMP=$((TEMPLIMIT-3))
while [ 1 ]; do
	TIME="$(date)"
	CPUTEMPA=$(</sys/class/thermal/thermal_zone0/temp)
	CPUTEMP=$((CPUTEMPA/1000))
	CPUFREQ=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`
	GPUTEMP=`/opt/vc/bin/vcgencmd measure_temp | cut -d '=' -f2 | cut -d "'" -f1 | awk '{print int($1)}'`
	ARMCLOCK=`/opt/vc/bin/vcgencmd measure_clock arm | cut -d '=' -f2`
	clear
	printf "%s\n\n" "==================== Raspberry Pi 3 Stress Tester ===================="
	printf "%s\n" "  CPU Current: $((CPUFREQ/1000)) Mhz @ $COREVOLT     Min:$((CPUMINFREQ/1000)) Mhz  Mhz Max:$((CPUMAXFREQ/1000)) Mhz"
	printf "%s\n" "  SDRAM Voltage:  C=$MEMOVERVOLTC/$MEMVOLTC  I=$MEMOVERVOLTI/$MEMVOLTI  P=$MEMOVERVOLTP/$MEMVOLTP"
	printf "%s\n\n" "  SDRAM Frequency: $SDRAMFREQ Mhz     GPU Frequency: $GPUFREQ Mhz"
        printf "%s\n" "  ARM Clock: $((ARMCLOCK/1000000)) Mhz"
        printf "%s\n" "  CPU Temp: $CPUTEMP'C     GPU Temp: $GPUTEMP'C     Max Temp: $TEMPLIMIT'C"
	printf "\n"
        printf "%s\n" "----------------------------------------------------------------------"
	printf "%s\n" "$TIME"
        if [[ $CPUTEMP -ge $STOPTEMP || $GPUTEMP -ge $STOPTEMP ]]; then
                echo "****  $STOPTEMP DEGREES REACHED - STOPPING TEST  *****"
                killall dd
                exit 0
        fi
	printf "%s" "Ctrl+C to exit...  "
	sleep 1
done

killall dd
echo "Exit success"
exit 0
