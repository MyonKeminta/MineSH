#!/bin/bash


# Descriptor &3, &4: reserved for temporary use
# Descriptor &6: for tcp connection


readonly MINESH_VERSION="v0.1a"
readonly serverConfirmMsg="MineSH-server ${MINESH_VERSION}"
readonly clientConfirmMsg="MineSH-client ${MINESH_VERSION}"
readonly dialogTitle="MineSH ${MINESH_VERSION}"

declare -i mapWidth mapHeight
declare -a theMap
declare -i cameraX cameraY
declare -i cameraWidth cameraHeight
declare -i selectionX selectionY
declare fix_x fix_y
declare isScreenWidthEven

declare waitingForResize

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

# getIndexByCell <x> <y>
# Get the array index of the given position.
getIndexByCell()
{
	echo $(($1+$2*mapWidth))
}


# setColorConfig <1|8|256>
setColorConfig()
{
	
}

# getRand <min> <max>
# Generate a integer in [min, max)
getRand()
{
	local ran=$(dd bs=4 count=1 'if=/dev/urandom' status=none | od --format=u --address-radix=none)
	echo $((ran%($2-$1)+$1))
}

refreshScreen()
{
	:
}

initMapPosition()
{
	eval $(resize)

	cameraHeight=$((LINES-1))
	cameraWidth=$(((COLUMNS-1)/2))

	if [[ $cameraWidth -ge $mapWidth ]]; then
		fix_x=1
		cameraX=$((-(mapWidth - cameraWidth)/2))
	else
		fix_x=""
		cameraX=$(getRand 0 $((mapWidth - cameraWidth)))
	fi
	if [[ $cameraHeight -ge $mapHeight ]]; then
		fix_y=1
		cameraY=$((-(cameraHeight - mapHeight)/2))
	else
		fix_y=""
		cameraY=$(getRand 0 $((mapHeight - cameraHeight)))
	fi
	refreshScreen
}

# screenToMapX <x>
# Convert screen coordinates X into map coordinates X
screenToMapX()
{
	:
}

# screenToMapY <y>
# Convert screen coordinates Y into map coordinates Y
screenToMapY()
{
	:
}

# screenToMapCoordinates <x> <y>
# Convert screen coordinates X,Y into map coordinates X,Y
screenToMapCoordinates()
{
	echo $(screenToMapX $1; screenToMapY $2)
}

# cellSelect <x> <y>
cellSelect()
{
	:
}

# cellSelectionMove <up|down|left|right>
cellSelectionMove()
{
	:
}


onResized()
{
	:
}


receiveLoop()
{
	local response
	local responseHead
	local responseBody

	while true; do
		read response <&6
		responseHead=$(cut -d ' ' -f 1 <<< response)
		responseBody=$(cut -d ' ' -f 2- <<< response)
		responseBody=($responseBody)

		case $responseHead in
			Disconnect )
				;;

			Map )
				;;

			Changed )
				;;
		esac
	done
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
	local server
	server=$(dialog --title "${dialogTitle}" --inputbox "${tip1}\n\n${tip2}" 10 55 3>&1 1>&2 2>&3)

	if [[ $? -ne 0 ]]; then
		clear
		echo "Canceled." >&2
		exit 1
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
		option=$(dialog --title ${dialogTitle} --menu "Connected successfully." 10 30 3 1 "Log in" \
			2 "Play as guest" 3 "Register" 3>&1 1>&2 2>&3)
		if [[ $? -ne 0 ]]; then
			clear
			echo "Exited." >&2
			exit 1
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
