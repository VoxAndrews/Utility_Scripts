#!/bin/sh

#-------------------------------------------------------------------------------
#
#	RASPBERRY PI 5 BENCHMARKING SCRIPT
#	==================================
#	Darcy Wilson | 12-01-2026
#	Darcy.Wilson@murdoch.edu.au
#	==================================
#
#	==== DESCRIPTION ====
#	This script leverages the Dialog DA9091 PMIC on the Raspberry Pi 5 to
#		obtain data on the current voltage, temperature and CPU clock
#		speeds of the device. First it collects Idle data for sixty 
#		seconds, followed by five minutes of `stress` utility data, and 
#		finally, sixty more seconds of cooldown data.
#
#	The script has been created to follow the IEEE Std 1003.1-2024
#		(POSIX.1-2024) Standard and should work on most official 
#		distributions and subsets of the Raspberry Pi Operating System.
#
#       The values used in this script for the 'stress' command were taken 
#		from DietPi's call to the command:
#
# `stress -t "$STRESS_TEST_DURATION"s -c $(( $G_HW_CPU_CORES * 2 )) -i "$G_HW_CPU_CORES" -m "$G_HW_CPU_CORES" --vm-bytes "$memory_per_thread"M -d 2 &`
#
#	Note, the values are NOT avalible in the DietPi script but are instead 
#		obtained through calls made during the DietPi script's
#		execution. The DietPi script was modified to output the values 
#		to terminal and were then manually input here. The values 
#		obtained were correct as of DietPi v9.20 for a Raspberry Pi 5B
#		8GB Model.
#
#	==== NOTES & ADDENDUMS ====
#	1. This script is intended ONLY for the Raspberry Pi 5 as it is relies 
#		on the data fed to it from the Dialog DA9091 PMIC for SOME 
#		voltage readings. If the script detects that it is NOT running 
#		on a Raspberry Pi 5, it will either run without outputting 
#		voltage values (If it is on other models of Raspberry Pi) or 
#		exit with an error.
#	2. Despite this not being an issue till long after I'm gone, and I
#		doubt anyone will use this past this project, it should be
#		noted that depending on the implementation of `date` on a POSIX
#		comptaible system, it may return a 32-Bit Integer as opposed to
#		a 64-Bit integer when `%s` is given to represent the UNIX
#		Epoch. This is because up until IEEE Std 1003.1-2024
#		(POSIX.1-2024), `time_m` (Per the ISO/IEC 9899:2018 or C18
#		Specification) was represented as a 32-Bit Integer 
#		(Tuesday, 19 January 2038 03:14:07 GMT) instead of a 64-Bit
#		Integer (Friday, 11 April 2262 23:47:16.854 GMT)
#	3. Dialog was aquired by Renesas some time ago so the chip used for
#		checking the voltages may come under the Renesas name instead
#		of Dialog in places (But should still be the same model
#		otherwise).
#	4. The 'While' loops were to be put into their own helper function but
#		currently I am unsure of how to pass a conditional to a function
#		as calling the function from within the loop costs extra time.
#	5. This SHOULD work with most POSIX compatible systems, however I am
#		unsure how many shells being used by modern operating systems
#		are IEEE Std 1003.1-2024 (POSIX.1-2024) compliant at this time.
#		Your milage may vary depending on what OS you are using this on,
#		so refer to IEEE Std 1003.1-2017 (POSIX.1-2017) (Revision of 
#		IEEE Std 1003.1-2008) and use it as a reference to make changes
#		if needed.
#	6. " 'stress' is a tool that imposes a configurable amount of CPU,
#		memory, I/O, or disk stress on a POSIX-compliant operating
#		system and reports any errors it detects.'stress' is not a
#		benchmark. It is a tool used by system administrators to
#		evaluate how well their systems will scale, by kernel
#		programmers to evaluate perceived performance characteristics,
#		and by systems programmers to expose the classes of bugs which 
#		only or more frequently manifest themselves when the system is 
#		under heavy load". In this case, we are using 'stress' to
#		benchmark the temperatures, voltages and speeds of a device
#		while a device is at it's absolute limit.
#	7. 'mkstemp' was used as opposed to 'mktemp' as there is no POSIX
#		specification for an 'mktemp' command, and despite it being
#		avalible in most operating systems, the specification can vary
#		as well as there being potential security/usage issues reported
#		online with how the utility creates files. The 'm4' command
#		allows access to 'mkstemp' from the 'Standard C library
#		(libc, -lc)'.
#
#	==== REFERENCES ====
#		- https://www.tomshardware.com/how-to/raspberry-pi-benchmark-vcgencmd
#		- https://pubs.opengroup.org/onlinepubs/9699919799.2018edition/
#		- https://www.iso.org/iso-8601-date-and-time-format.html
#       	- https://github.com/MichaIng/DietPi/blob/9ba799f0ad8c251eabb75646bc331fdcca57ea7e/dietpi/dietpi-config#L3510C5-L3510C11
#		- https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-revision-codes
#		- https://github.com/jfikar/RPi5-power
#
#-------------------------------------------------------------------------------

################################################################################

# SCRIPT VARIABLES

## SHELL VARIABLES
### SHELL FORMATTING
# Set Tab Width to 2 Characters
tabs 2

## CONSTANT VARIABLES
HOME_DIR="${HOME}" # The home directory of the user's account on the system (Relative to the current user calling the file)
START_TIME=$(date "+%s") # Time since UNIX Epoch (1970-01-01T00:00:00Z) in seconds
OUTFILE="stress-benchmark_$START_TIME.csv" # The data from the benchmarking output to a CSV file
RPI_REV=$(cat < /proc/cpuinfo | grep Revision) # Raspberry Pi Revision String (E.g. 'Revision	: e04171')

### Text Colours
BLACK="$(tput setaf 0)"		# Black
RED="$(tput setaf 1)"		# Red
GREEN="$(tput setaf 2)"		# Green
YELLOW="$(tput setaf 3)"	# Yellow
BLUE="$(tput setaf 4)"		# Blue
PURPLE="$(tput setaf 5)"	# Purple
CYAN="$(tput setaf 6)"		# Cyan
WHITE="$(tput setaf 7)"		# White

### Background Colours
BG_BLACK="$(tput setab 0)"	# Black - Background
BG_RED="$(tput setab 1)"	# Red - Background
BG_GREEN="$(tput setab 2)"	# Green - Background
BG_YELLOW="$(tput setab 3)"	# Yellow - Background
BG_BLUE="$(tput setab 4)"	# Blue - Background
BG_PURPLE="$(tput setab 5)"	# Purple - Background
BG_CYAN="$(tput setab 6)"	# Cyan - Background
BG_WHITE="$(tput setab 7)"	# White - Background

### Text States
NORMAL="$(tput sgr0)"		# Text reset
BOLD="$(tput bold)"		# Bold
UNDERLINE="$(tput smul)"	# Underline
RM_UNDERLINE="$(tput rmul)"	# Remove underline
BLINK="$(tput blink)"		# Blinking
REVERSE="$(tput rev)"		# Reverse

## NON-CONSTANT VARIABLES
pid="" # PID of a given command/process
idle_time=60
stress_time=300
cooldown_time=60
csv_directory="$HOME_DIR"

################################################################################

# HELPER FUNCTIONS

# Print the usage (Help) message to the user after giving the -h option to the script
usage()
{
	printf '%s\n'"Usage: ./voltagebench [${BOLD}OPTION...${NORMAL}]"
	printf '\n\nThis script benchmarks the Raspberry Pi 4 through 5 platforms and stores the results in a CSV file.\n\n' | fold -bs

	printf '\n%s\n\n' "${BOLD}OPTIONS${NORMAL}"

	printf '\t%-15s\t%-60s\n' './voltagebench -i' "# Sets idle log time (default 60 seconds)" | fold -bs
	printf '\t%-15s\t%-60s\n' './voltagebench -s' "# Sets ${NORMAL}${UNDERLINE}stress${NORMAL} log time (default 300 seconds)" | fold -bs
	printf '\t%-15s\t%-60s\n' './voltagebench -c' '# Sets cooldown log time (default 60 seconds)' | fold -bs
	printf '\t%-15s\t%-60s\n' './voltagebench -l' "# Sets CSV output location (default ${BOLD}${csv_directory}${NORMAL})" | fold -bs
	printf '\t%-15s\t%-60s\n\n' './voltagebench -h' '# Help & Usage Information' | fold -bs

	printf '\n%s\n\n' "${BOLD}EXAMPLES${NORMAL}"

	printf '\t%s\n\n' "If the user wishes to set the time of a given portion of the benchmark to a specific amount, either to test for a longer or shorter period of time, all times must be given in seconds" | fold -bs

	printf '\t%s\n\n' "./voltagebench -i 120 -s 600 -c 30"

	printf '\t%s\n\n' "To set a new destination for the CSV file, the user needs to enter the absolute path they want to use, or the relative path from where this script was called (It is recommended if pointing to the home directory NOT to use '~/' as it is not POSIX compliant. Instead, use the 'HOME' environment variable or an absolute path as shown below.)" | fold -bs

	printf '\t%s"%s"\n\n' "./voltagebench -i 50 -l " "/home/testuser/Documents"

	printf '\n%s\n\n' "${BOLD}NOTE${NORMAL}"

	printf '\t%s\n\n' "If you are having issues running this script or getting results, it is likely that your user does not have access to the outputs from the 'vcgencmd' command which this script relies on. To fix this, add the following lines to ${BOLD}/lib/udev/rules.d/10-vc.rules${NORMAL} as sudo/root:" | fold -bs

	printf '\t%s"%s"%s%s"%s"%s%s"%s"\n' "KERNEL==" "vcio" ", " "GROUP=" "video" ", " "MODE=" "0660" | fold -bs
	printf '\t%s"%s"%s%s"%s"%s%s"%s"\n' "KERNEL==" "vchiq" ", " "GROUP=" "video" ", " "MODE=" "0660" | fold -bs
	printf '\t%s"%s"%s%s"%s"%s%s"%s"\n' "SUBSYSTEM==" "vc-sm" ", " "GROUP=" "video" ", " "MODE=" "0660" | fold -bs
	printf '\t%s"%s"%s%s"%s"%s%s"%s"\n' "KERNEL==" "vcsm-cma" ", " "GROUP=" "video" ", " "MODE=" "0660" | fold -bs

	printf '\t%s\n\n' "Then run these commands as sudo/root:" | fold -bs

	printf '\t%s\n' "sudo chgrp video /dev/vcio" | fold -bs
	printf '\t%s\n' "sudo chmod 0660 /dev/vcio" | fold -bs
	printf '\t%s\n\n' "sudo usermod -a -G video ${BOLD}USERNAME${NORMAL}" | fold -bs

	printf '\t%s\n\n' "Replacing ${BOLD}USERNAME${NORMAL} with your system account name, and finally, restart the machine to gain access." | fold -bs

	printf '\n%s\n\n' "${BOLD}AUTHOR${NORMAL}"

	printf '\t%s\n' "Created by Darcy L. C. Wilson <Darcy.Wilson@murdoch.edu.au>" | fold -bs
	printf '\t%s\n\n' "Copyright 2026" | fold -bs
	printf '\t%s\n\n' "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>" | fold -bs
}

# Prints system messages given to it by the user with differing levels represented by short codes and text colours
systemMessage()
{
	colour=$WHITE
	system_message="INFO"

	case $1 in
		"i") # [INFO]
			colour=$BLUE

			;;
		"s") # [SUCCESS]
			colour=$GREEN
			system_message="SUCCESS"

			;;
		"w") # [WARN]
			colour=$YELLOW
			system_message="WARN"

			;;
		"e") # [ERROR]
			colour=$RED
			system_message="ERROR"

			;;
		*) # Non-Raspberry Pi Device OR Raspberry Pi 3 & Lower
			colour=$WHITE
			system_message="DEFAULT"

			;;
	esac

	printf '%s\n' "${colour}${BOLD}================================================================================${NORMAL}"
        
        # [ .. ] can't match globs so it's recommended to use switch case statements
	case $1 in
	        *"b"*) # Adds the BLINKING effect to the text
			colour=$WHITE
			
			printf '%s' "${BLINK}"

		        ;;
	esac

	printf '%s\n' "${colour}${BOLD}[${system_message}]${NORMAL} ${2}" | fold -bs
	printf '%s\n\n' "${colour}${BOLD}================================================================================${NORMAL}"
}

# Checks the hardware revision of the device and informs if this script is compatible or not
hardwareRevisionCheck()
{
	# Switch case statement which looks through the output of $RPI_REV and finds matching revision codes
	# (Currently devices other than the Raspberry Pi 5 or those based on it just print warning messages
	# or exit the script but have been left as seperate cases in case extra functionality with older
	# hardware is needed in the future)
	case $RPI_REV in
		# Raspberry Pi 5
		*"e04171"*|*"d04171"*|*"c04171"*|*"b04171"*|*"d04170"*|*"c04170"*|*"b04170"*)
			systemMessage "s" "The script has detected that this device is a Raspberry Pi 5."

		        ;;
		# Raspberry Pi 5-based Devices (CM5/CM5 Lite, 500/500+)
		*"b04180"*|*"c04180"*|*"d04180"*|*"e04180"*|*"d04190"*|*"e04190"*|*"b041a0"*|*"c041a0"*|*"d041a0"*|*"e041a0"*)
			systemMessage "w" "This script has detected a Raspberry Pi device but was not designed for this model as it does not contain the Dialog [Renesas] DA9091 PMIC. Exiting now..."

			exit 0

		        ;;
		# Raspberry Pi 4
		*"a03111"*|*"b03111"*|*"c03111"*|*"b03112"*|*"c03112"*|*"b03114"*|*"c03114"*|*"d03114"*|*"b03115"*|*"c03115"*|*"d03115"*)
			systemMessage "w" "This script has detected a Raspberry Pi device but was not designed for this model as it does not contain the Dialog [Renesas] DA9091 PMIC. Exiting now..."

			exit 0

		        ;;
		# Raspberry Pi 4-based Devices (CM4, 400)
		*"c03130"*|*"a03140"*|*"b03140"*|*"c03140"*|*"d03140"*)
			systemMessage "w" "This script has detected a Raspberry Pi device but was not designed for this model as it does not contain the Dialog [Renesas] DA9091 PMIC. Exiting now..."

			exit 0

		        ;;
		# Raspberry Pi Zero 2 W
		*"902120"*)
			systemMessage "w" "This script has detected a Raspberry Pi device but was not designed for this model as it does not contain the Dialog [Renesas] DA9091 PMIC. Exiting now..."

			exit 0

		        ;;
		# Non-Raspberry Pi Device OR Raspberry Pi 3 & Lower
		*)
			systemMessage "e" "This script was not designed for this device and will now exit."

			exit 0

		        ;;
	esac
}

# Creates a temporary file and takes an integer as a value for the time to wait after the file was created (In case multiples are being made)
createTmpFile()
{
	tmpFile=$(printf '%s' "mkstemp(XXXXXX)" | m4)

	printf '%s' "$tmpFile"

	sleep "$1"
}

# Kill a process represented by a PID if it is active and then wait a second
killProcess()
{
	if kill -0 "$1" 2> /dev/null; then
		kill "$1" stress
		
		sleep 1
	fi
}

################################################################################

# MAIN SCRIPT FUNCTIONALITY

# Main function which houses the functionality of the script
main()
{
	# Hardware revision check
	hardwareRevisionCheck

	# Start benchmarking
	printf 'Timestamp (UNIX Epoch),CPU Temperature (Celsius),CPU Clock Speed (MHz),CPU Throttled,VC4 Scaler Clock Speed,Consumption (W),Benchmarking Status\n' > "${csv_directory}/$OUTFILE"

        systemMessage "i" "${BOLD}${csv_directory}/${OUTFILE}${NORMAL} has been created."

	systemMessage "i" "Log Idle ($idle_time Seconds)"
	
	printf '%s\n\n' "${BLINK}${BG_PURPLE}${BOLD}PLEASE WAIT...${NORMAL}"

	# Create temporary files and reset variables for data storage
	pmic_data=$(createTmpFile "1")
	pmic_amperage=$(createTmpFile "1")
	pmic_voltage=$(createTmpFile "1")
	current_wattage=""

	endTime=$(( $(date +%s) + idle_time )) # Calculate end time.
	
	# Loop and get the status of the device before the `stress` test
	while [ "$(date +%s)" -lt "$endTime" ]; do
		timestamp=$(date "+%s")
		cpu_temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
		cpu_clock_speed=$(($(vcgencmd measure_clock arm | awk -F= '{print $2}') / 1000000))
		throttled_status=$(vcgencmd get_throttled | awk -F= '{print $2}')
		core_clock_speed=$(($(vcgencmd measure_clock core | awk -F= '{print $2}') / 1000000))

		vcgencmd pmic_read_adc > "${pmic_data}"

		cat < "${pmic_data}" | grep current | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g'            > "${pmic_amperage}"
		cat < "${pmic_data}" | grep volt    | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g' | head -12 > "${pmic_voltage}"

		current_wattage=$(paste "${pmic_amperage}" "${pmic_voltage}" | awk '{sum+=$1*$2}END{print sum}')

		printf '%s,%s,%s,%s,%s,%s,%s\n' "$timestamp" "$cpu_temp" "$cpu_clock_speed" "$throttled_status" "$core_clock_speed" "$current_wattage" "idle" >> "${csv_directory}/$OUTFILE"

		sleep 1
	done

	# Delete temporary files
	rm "${pmic_amperage}" "${pmic_voltage}" "${pmic_data}"

	sleep 1
	
	systemMessage "s" "Idle logging complete!"

	systemMessage "i" "Log ${NORMAL}${UNDERLINE}stress${NORMAL} ($stress_time Seconds)"
	
	printf '%s\n\n' "${BLINK}${BG_PURPLE}${BOLD}PLEASE WAIT...${NORMAL}"

	# Create temporary files and reset variables for data storage
	pmic_data=$(createTmpFile "1")
	pmic_amperage=$(createTmpFile "1")
	pmic_voltage=$(createTmpFile "1")
	current_wattage=""

	# The `stress` utility
	stress --quiet -c 8 -i 4 -m 4 --vm-bytes 2026M -d 2 -t "$stress_time" &

	# The PID of the current `stress` command
	pid=$!

	# Gather data on the device during the `stress` test. Check if the
	# `stress` process represented by `pid=$!` is running and stop the 
	# while loop once it's finished
	while kill -0 $pid 2> /dev/null; do
		timestamp=$(date "+%s")
		cpu_temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
		cpu_clock_speed=$(($(vcgencmd measure_clock arm | awk -F= '{print $2}') / 1000000))
		throttled_status=$(vcgencmd get_throttled | awk -F= '{print $2}')
		core_clock_speed=$(($(vcgencmd measure_clock core | awk -F= '{print $2}') / 1000000))

		vcgencmd pmic_read_adc > "${pmic_data}"

		cat < "${pmic_data}" | grep current | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g'            > "${pmic_amperage}"
		cat < "${pmic_data}" | grep volt    | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g' | head -12 > "${pmic_voltage}"

		current_wattage=$(paste "${pmic_amperage}" "${pmic_voltage}" | awk '{sum+=$1*$2}END{print sum}')

		printf '%s,%s,%s,%s,%s,%s,%s\n' "$timestamp" "$cpu_temp" "$cpu_clock_speed" "$throttled_status" "$core_clock_speed" "$current_wattage" "stress" >> "${csv_directory}/$OUTFILE"

		sleep 1
	done

	# Delete temporary files
	rm "${pmic_amperage}" "${pmic_voltage}" "${pmic_data}"

	sleep 1

	killProcess $pid
	
	systemMessage "s" "${NORMAL}${UNDERLINE}stress${NORMAL} logging complete!"

	systemMessage "i" "Log Cooldown ($cooldown_time Seconds)"
	
	printf '%s\n\n' "${BLINK}${BG_PURPLE}${BOLD}PLEASE WAIT...${NORMAL}"

	# Create temporary files and reset variables for data storage
	pmic_data=$(createTmpFile "1")
	pmic_amperage=$(createTmpFile "1")
	pmic_voltage=$(createTmpFile "1")
	current_wattage=""

	endTime=$(( $(date +%s) + cooldown_time )) # Calculate end time.

	# Loop and get the status of the device during it's cooldown period
	# from the `stress` test
	while [ "$(date +%s)" -lt "$endTime" ]; do
		timestamp=$(date "+%s")
		cpu_temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
		cpu_clock_speed=$(($(vcgencmd measure_clock arm | awk -F= '{print $2}') / 1000000))
		throttled_status=$(vcgencmd get_throttled | awk -F= '{print $2}')
		core_clock_speed=$(($(vcgencmd measure_clock core | awk -F= '{print $2}') / 1000000))

		vcgencmd pmic_read_adc > "${pmic_data}"

		cat < "${pmic_data}" | grep current | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g'            > "${pmic_amperage}"
		cat < "${pmic_data}" | grep volt    | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g' | head -12 > "${pmic_voltage}"

		current_wattage=$(paste "${pmic_amperage}" "${pmic_voltage}" | awk '{sum+=$1*$2}END{print sum}')

		printf '%s,%s,%s,%s,%s,%s,%s\n' "$timestamp" "$cpu_temp" "$cpu_clock_speed" "$throttled_status" "$core_clock_speed" "$current_wattage" "cooldown" >> "${csv_directory}/$OUTFILE"

		sleep 1
	done

	# Delete temporary files
	rm "${pmic_amperage}" "${pmic_voltage}" "${pmic_data}"

	sleep 1
	
	systemMessage "s" "Cooldown logging complete!"

	systemMessage "s" "The benchmarking tool has completed succesfully! Data can be viewed at ${BOLD}${csv_directory}/${OUTFILE}${NORMAL}"
}

################################################################################

# Initial Messages

# Script name and version
printf '%s\n\n' "${UNDERLINE}Raspberry Pi 5 Benchmarking Script${NORMAL} (${BOLD}v1.0.0${NORMAL})"

# Gets the options that the user gave and their values
while getopts i:s:c:l:h opt; do
	case "$opt" in
        	i)
			idle_time="$OPTARG"

			;;
        	s)
			stress_time="$OPTARG"

			;;
        	c)
			cooldown_time="$OPTARG"

			;;
        	l)
			csv_directory="$OPTARG"

			;;
        	h)
			usage

			exit 0

			;;
		*)
			usage >&2

			exit 1

			;;
        esac
done
shift $((OPTIND - 1))

# FUNCTION CALLS

# Call to 'main()' as POSIX scripts do not look for it automatically like in C/C++
main

################################################################################

# CLEANUP

# Kill 'stress' processes if it's still active
killProcess $pid