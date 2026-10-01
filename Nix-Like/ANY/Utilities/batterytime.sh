#!/bin/sh

#-------------------------------------------------------------------------------
#
#	BATTERY TIMER SCRIPT
#	==================================
#	Darcy Wilson | 14-05-2026
#	Darcy.Wilson@murdoch.edu.au
#	==================================
#
#	==== DESCRIPTION ====
#	This script fetches the initial UNIX Epoch time, prints it in a message
#		to the terminal, prints subsequent times to a '.log' file and
#		then waits for outside input to close, either using the
#		'CTRL + C' method or, as intended for the tests we are
#		conducting, when power is cut to a system from a portable
#		source.
#
#	This script is extremly "dumb", in which I mean it is made to be as
#		simple as possible as not to draw too much processing power
#		away from the system and affect the results of the test. This is
#		why the script does not make any repeated prints to the screen
#		and why there is a sleep command sent every second so it does
#		not put strain on the system and in turn, the battery.
#
#-------------------------------------------------------------------------------

################################################################################

# MAIN SCRIPT FUNCTIONALITY

# Main function which houses the functionality of the script
main()
{
	# Clear the screen so there are no distractions
	clear

	initialepoch=$(date +%s)

	printf 'The current UNIX Epoch time at script start is %s\n\n' "$initialepoch" | tee -a "test_${initialepoch}.log"

	# Loop infinitely until 'CTRL + C' or the battery runs out 
	while true; do
		# Get the new time each loop
		newtime=$(date +%s)

		# Append the new time to the file without printing to screen
		printf '%s\n' "$newtime" >> "test_${initialepoch}.log"

		# Sleep for 1 second as not to stress the CPU out
		sleep 1
	done
}

################################################################################

# FUNCTION CALLS

# Call to 'main()' as POSIX scripts do not look for it automatically like in C/C++
main