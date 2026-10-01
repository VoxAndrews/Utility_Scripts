#!/bin/sh

#-------------------------------------------------------------------------------
#
#	RASPBERRY PI 5 DATA LOGGING SCRIPT
#	==================================
#	Darcy Wilson | 31-08-2026
#	Darcy.Wilson@murdoch.edu.au
#	==================================
#
#	==== DESCRIPTION ====
#	This script logs a set of system statistics to a CSV file which the
#		user can obtain and read back at a later date. It's intended
#		purpose is to be run in the background in conjunction with other
#		ongoing tests to add to the pool of examinable data post-test.
#
#	This script leverages the Dialog DA9091 PMIC on the Raspberry Pi 5 to
#		obtain data on the current voltage, temperature and CPU clock
#		speeds of the device. It will ONLY work with the Raspberry Pi 5
#		and is NOT intended to be used with any other Linux-based systems
#		or POSIX-compatible subsystems.
#
#	The script has been created to follow the IEEE Std 1003.1-2024
#		(POSIX.1-2024) Standard and should work on most official 
#		distributions and subsets of the Raspberry Pi Operating System.
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
#	6. 'mkstemp' was used as opposed to 'mktemp' as there is no POSIX
#		specification for an 'mktemp' command, and despite it being
#		avalible in most operating systems, the specification can vary
#		as well as there being potential security/usage issues reported
#		online with how the utility creates files. The 'm4' command
#		allows access to 'mkstemp' from the 'Standard C library
#		(libc, -lc)'.
#
#	==== REFERENCES ====
#		- https://www.tomshardware.com/how-to/raspberry-pi-benchmark-vcgencmd
#		- https://pubs.opengroup.org/onlinepubs/9799919799/
#			- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/date.html
#		- https://www.iso.org/iso-8601-date-and-time-format.html
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
OUTFILE="system-logging_$START_TIME.csv" # The data from the benchmarking output to a CSV file

### Text States
NORMAL="$(tput sgr0)"		# Text reset
BOLD="$(tput bold)"		# Bold

## NON-CONSTANT VARIABLES
timeout=10800 # 3 Hours in seconds
csv_directory="$HOME_DIR"

################################################################################

# HELPER FUNCTIONS

# Print the usage (Help) message to the user after giving the -h option to the script
usage()
{
	printf '%s\n'"Usage: ./datalogging [${BOLD}OPTION...${NORMAL}]"
	printf '\n\nThis script logs the statistics of the system and stores the results in a CSV file.\n\n' | fold -bs

	printf '\n%s\n\n' "${BOLD}OPTIONS${NORMAL}"

	printf '\t%-15s\t%-60s\n\n' './datalogging -h' '# Help & Usage Information' | fold -bs
	printf '\t%-15s\t%-60s\n' './datalogging -t' "# Sets the timeout time in seconds (default ${BOLD}${timeout} seconds${NORMAL})" | fold -bs
	printf '\t%-15s\t%-60s\n' './datalogging -l' "# Sets CSV output location (default ${BOLD}${csv_directory}${NORMAL})" | fold -bs

	printf '\n%s\n\n' "${BOLD}EXAMPLES${NORMAL}"

	printf '\t%s\n\n' "To set a new destination for the CSV file, the user needs to enter the absolute path they want to use, or the relative path from where this script was called (It is recommended if pointing to the home directory NOT to use '~/' as it is not POSIX compliant. Instead, use the 'HOME' environment variable or an absolute path as shown below.)" | fold -bs

	printf '\t%s"%s"\n\n' "./datalogging -t 300 -l " "/home/USERNAME/Documents"

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

# Creates a temporary file
createTmpFile()
{
	tmpFile=$(printf '%s' "mkstemp(/tmp/XXXXXX)" | m4)

	printf '%s' "$tmpFile"

	sleep 1
}

################################################################################

# MAIN SCRIPT FUNCTIONALITY

# Main function which houses the functionality of the script
main()
{
	# Start benchmarking
	printf 'UNIX Time,UTC Time,Local Time,CPU Temp (C),CPU Clock Speed (MHz),CPU Throttled,VC4 Scaler Clock Speed,Consumption (W)\n' > "${csv_directory}/$OUTFILE"

	# Create temporary files and reset variables for data storage
	pmic_data=$(createTmpFile)
	pmic_amperage=$(createTmpFile)
	pmic_voltage=$(createTmpFile)
	current_wattage=""

	endTime=$(( $(date +%s) + timeout )) # Calculate the time that the loop will end at
	
	# Loop till the time has run out, obtain system stats and print them to the CSV file
	while [ "$(date +%s)" -lt "$endTime" ]; do
		unix_timestamp=$(date "+%s")
		utc_timestamp=$(date -u "+%Y-%m-%d %H:%M:%S") # Formatted to match MySQL's `DATETIME` type formatting
		local_timestamp=$(date "+%Y-%m-%d %H:%M:%S") # Formatted to match MySQL's `DATETIME` type formatting
		cpu_temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
		cpu_clock_speed=$(($(vcgencmd measure_clock arm | awk -F= '{print $2}') / 1000000))
		throttled_status=$(vcgencmd get_throttled | awk -F= '{print $2}')
		core_clock_speed=$(($(vcgencmd measure_clock core | awk -F= '{print $2}') / 1000000))

		vcgencmd pmic_read_adc > "${pmic_data}"

		cat < "${pmic_data}" | grep current | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g'            > "${pmic_amperage}"
		cat < "${pmic_data}" | grep volt    | awk '{print substr($2, 1, length($2)-1)}' | sed 's/.*=//g' | head -12 > "${pmic_voltage}"

		current_wattage=$(paste "${pmic_amperage}" "${pmic_voltage}" | awk '{sum+=$1*$2}END{print sum}')

		printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$unix_timestamp" "$utc_timestamp" "$local_timestamp" "$cpu_temp" "$cpu_clock_speed" "$throttled_status" "$core_clock_speed" "$current_wattage" >> "${csv_directory}/$OUTFILE"

		sleep 1
	done

	# Delete temporary files
	rm "${pmic_amperage}" "${pmic_voltage}" "${pmic_data}"

	sleep 1
}

################################################################################

# Gets the options that the user gave and their values
while getopts t:l:h opt; do
	case "$opt" in
        	t)
			timeout="$OPTARG"

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