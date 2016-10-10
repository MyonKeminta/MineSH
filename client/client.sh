#!/bin/bash


# Descriptor &3, &4: reserved for temporary use
# Descriptor &6: for tcp connection


readonly MINESH_VERSION="v0.1a"
readonly serverConfirmMsg="MineSH-server ${MINESH_VERSION}"
readonly clientConfirmMsg="MineSH-client ${MINESH_VERSION}"
readonly dialogTitle="MineSH ${MINESH_VERSION}"

declare -i mapWidth mapHeight
declare -a theMap

declare receiveLoopPid

readonly NULL=1
readonly UNKNOWN=2
readonly CONNECTED=3
readonly GUEST=4
readonly LOGEDIN=5
readonly DISCONNECTED=-1
readonly FAILED=-2
gameState=$NULL


onStopped()
{
	exec 6<&- 6>&-
}

onStoppedByServer()
{
	onStopped
}

onStoppedByUser()
{
	kill $receiveLoopPid
	onStopped
}


receiveLoop()
{
	:
}

mainLoop()
{
	:
}

# connectToServer <address> <port>
connectToServer()
{
	if [[ $# -lt 2 ]]; then
		echo "Too few args given." >&2
		return 1
	fi
	echo "Connecting to [${1}:${2}]..."
	exec 6<>"/dev/tcp/${1}/${2}"
	local result=$?
	if [[ $result -ne 0 ]]; then
		echo "Failed connecting to [${1}:${2}]."
		return $result
	fi
	unset result

	gameState=$UNKNOWN

	echo "${clientConfirmMsg}" >&6
	read serverInfo <&6
	if [[ $serverInfo != $serverConfirmMsg ]]; then
		exec 6>&- 6<&-
		echo "This is not a MineSH server or version mismatched." >&2
		return 2
	fi
	gameState=$CONNECTED
	return 0
}

enterAsGuest()
{
	echo "Guest" >&6
	local response
	read response <&6
	response=($response)
	if [[ ${response[0]} = "Accept" ]]; then
		mapWidth=${response[1]}
		mapHeight=${response[2]}
		gameState=$GUEST

		if [[ mapWidth -le 0 || mapHeight -le 0 ]]; then
			gameState=$FAILED
			echo "***FETAL ERROR: Server returned invalid data.***"
			exit 3
		fi
	elif [[ ${response[0]} = "Deny" ]]; then
		echo "${response[@]}"
		return 1
	fi
}

runGame()
{
	receiveLoop &
	receiveLoopPid=$!

	mainLoop
}


interactiveMode()
{
	local tip1="Please enter the server you want to connect to."
	local tip2="(Example: www.abc.com:2333 or 127.0.0.1:65535)"
	local server=$(dialog --title "${dialogTitle}" --inputbox "${tip1}\n\n${tip2}" 10 55 3>&1 1>&2 2>&3)
	if [[ $? -ne 0 ]]; then
		clear
		echo "Canceled." >&2
		return 1
	fi
	clear
	connectToServer "$(cut -d ':' -f 1 <<< ${server})" "$(cut -d ':' -f 2 <<< ${server})"
	local result=$?
	if [[ $result -ne 0 ]]; then
		echo "Failed connecting to server." >&2
		return $result
	fi

	local option
	while true; do
		option=$(dialog --title %{dialogTitle} --menu "Connected successfully." 10 30 3 1 "Log in" \
			2 "Play as guest" 3 "Register" 3>&1 1>&2 2>&3)
		if [[ $? -ne 0 ]]; then
			clear
			echo "Exited." >&2
			break
		fi
		case $option in
			1 )
				dialog --title "${dialogTitle}" --msgbox "Not implemented yet." 6 30
				clear
				;;

			2 )
				local errmsg=$(enterAsGuest)
				if [[ $? -eq 1 ]]; then
					dialog --title "${dialogTitle}" --msgbox \
						"Server denied your request:\n${errmsg}" 6 30
					clear
				else
					runGame
					break
				fi
				;;

			3 )
				dialog --title "${dialogTitle}" --msgbox "Not implemented yet." 6 30
				clear
				;;
		esac
	done
}

runWithArgs()
{
	:
	# TODO: Finish this
}

if [[ $# -eq 0 ]]; then
	interactiveMode
else
	runWithArgs $*
fi


exit $?