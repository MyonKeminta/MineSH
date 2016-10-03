#!/bin/bash

# Uncomment this statement to disable color and bold text.
# export readonly DISABLE_STYLE=1

export readonly MINESH_SERVER_PATH=$(cd $(dirname $(which $0)); pwd)
export readonly MINESH_SVR_DATA_DIR="~/.minesh-server"
export readonly MINESH_VERSION="v0.1a"

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"
source "${MINESH_SERVER_PATH}/script/config.sh"
source "${MINESH_SERVER_PATH}/script/data-manager.sh"
source "${MINESH_SERVER_PATH}/script/server-core.sh"

quitNormally()
{
	exit 0
}

# If there are no args, go to the interactive mode.
interactiveMode()
{
	local path=$MINESH_SERVER_PATH
	local regRmComment='^([^#]|$)'
	local TPUT
	if [[ -n ${DISABLE_STYLE} ]]; then
		TPUT=":"
	else
		TPUT="tput"
	fi

	grep --color=never -E $regRmComment "${path}/text/intro.txt"
	echo ""
	grep --color=never -E $regRmComment "${path}/text/menu.txt"

	while true; do
		echo -n '> '

		# Set input style
		$TPUT setaf 3
		$TPUT bold

		if ! read input; then
			echo 'exit'
			$TPUT sgr0
			quitNormally
		fi

		$TPUT sgr0

		case $input in
			"" )
				# Blank line. Do nothing.
				;;

			start )
				echo "Please specify which port to run server (Enter to use default value):"
				read input
				if [[ -n $input ]]; then
					runServer -p $input
				else
					runServer
				fi
				exit $?
				;;

			config )
				configEdit
				;;

			create )
				echo "Please enter map args:"
				echo "<width> <height> [--mine-rate <rate-percent>] [--block <block-width> <block-height>]"
				read input
				generateMap $input
				;;

			# setup )
			# 	;;

			clean )
				cleanUpData
				;;

			backup )
				mineshErr "Not implemented yet."
				;;

			restore )
				mineshErr "Not implemented yet."
				;;

			help )
				grep --color=never -E $regRmComment "${path}/text/menu.txt"
				;;

			exit )
				quitNormally
				;;

			* )
				mineshUndefinedCommand $input
		esac


	done
}

# If passed in args
runWithArgs()
{
	:
}


# Main
if [[ $# -eq 0 ]]; then
	interactiveMode
else
	runWithArgs
fi

quitNormally
