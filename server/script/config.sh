#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"

declare -ix allow_guest default_port max_online

readonly configFile="${MINESH_SVR_DATA_DIR}/config/server.conf"

makeDefault()
{
	allow_guest=1
	default_port=2333
	max_online=100
}

loadConfig()
{
	makeDefault

	# If no config file:
	if [[ ! -f $configFile ]]; then
		mineshNoConfig
		return 1
	fi

	# If no read permission:
	if [[ ! -r $configFile ]]; then
		mineshNoReadPermission
		return 2
	fi

	source configFile
}

printConfig()
{
	echo "allow_guest=${allow_guest}"
	echo "default_port=${default_port}"
	echo "max_online=${max_online}"
}

saveConfig()
{
	# If no write permission:
	if [[ -f $configFile && ! -w $configFile ]]; then
		mineshNoWritePermission
		return 3
	fi

	printConfig > configFile
}

resetConfig()
{
	makeDefault
	saveConfig
	return $?
}

configEdit()
{
	loadConfig
	local result=$?
	local modified=0
	local tips="${MINESH_SERVER_PATH}/text/config.txt"
	local regRmComment='^([^#]|$)'

	if [[ $result -eq 2 ]]; then
		mineshErr "Cannot enter config edit mode."
		return $result
	fi

	grep --color=never -E $regRmComment $tips
	echo ""
	echo "Current config:"
	printConfig

	while [[ true ]]; do
		echoc 4 -n 'config'
		echo -n ' > '

		$TPUT setaf 3
		$TPUT bold

		if ! read input; then
			echo 'back'
		 	$TPUT sgr0
		 	if [[ modified -eq 0 ]]; then
		 		return 0
		 	fi
			echo -n "Are you sure want to discard your changes? "
		 	if confirm; then
				return 0
		 	fi
		fi

		$TPUT sgr0

		case $input in
			"" )
				# Blank line. Do nothing.
				;;

			list )
				# List current config.
				printConfig
				;;

			save )
				# Save the config.
				if saveConfig; then
					modified=0
				else
					mineshErr "Saving config failed."
				fi
				;;

			default )
				# Reset settings to default value.
				makeDefault
				modified=1
				;;

			help )
				grep --color=never -E $regRmComment $tips
				;;

			back )
				# Exit to main menu.
				# If saved or not modified:
				if [[ $modified -eq 0 ]]; then
					return 0;
				fi
				
				# If config has been changed but not saved:
				echo -n "Are you sure want to discard your changes? "
				if confirm; then
					return 0
				fi

				;;

			* )
				if echo $input | grep -q -E "^[a-zA-Z_][a-zA-Z0-9_]*=[0-9]+$"; then
					# If input is a assignment statement
					local key=$(echo $input | cut -d = -f 1)
					if [[ -n $key ]]; then
						eval $input
						modified=1
						echoc 2 "Set $key to $(echo $input | cut -d = -f 2)"
					else
						mineshErr "No such field: $input"
					fi

				else
					# Invalid input.
					mineshUndefinedCommand $input
				fi
				;;
		esac

	done
}