#!/bin/bash

# if color and bold was disabled:
TPUT="tput"
if [[ -n $DISABLE_STYLE ]]; then
	TPUT=":"
fi

# Print text with color.
# Usage: echoc <color> <args to echo...>
# Example(Print a red line): echoc 1 -ne 'wtf\n'
echoc()
{
	$TPUT setaf $1
	shift
	echo $*
	$TPUT sgr0
}

confirm()
{
	while [[ true ]]; do
		echo -n "[y/n]: "
		$TPUT setaf 3
		$TPUT bold
		read input
		$TPUT sgr0

		if [[ $input = 'y' || $input = 'Y' ]]; then
			return 0
		fi

		if [[ $input = 'n' || $input = 'N' ]]; then
			return 1
		fi

		echoc 1 "Invalid input."
	done
}

#Ask before rm
#Return 3 if canceled
safeRmDir()
{
	$TPUT bold
	echoc 1 "Are you sure want to remove directory $1?"
	$TPUT sgr0
	if ! confirm; then
		echoc 4 "Canceled."
		return 3
	fi
	rm -r "$1"
	local result=$?
	if [[ $result -ne 0 ]]; then
		echoc 1 "Unexpected error occured on deleting"
		return $result
	fi
	return 0
}