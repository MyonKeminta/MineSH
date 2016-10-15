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


declare PUTGAP
declare PUTCELL
declare PUTSELECTION

declare -r RESET_COLOR=$(tput sgr0)

# Mono color
declare -r UNCLR1=$(tput rev)

# 8 color
declare -r NUM8=$(tput setaf 2)
declare -r UNCLR8=$(tput setab 6)
declare -r BOMBED8=$(tput setaf 1; tput rev)
declare -r FLAGGED8=$(tput setaf 3; tput rev)

# 256 color
declare -ra NUM256=("" \
$(tput setaf 46) \
$(tput setaf 51) \
$(tput setaf 16) \
$(tput setaf 57) \
$(tput setaf 165) \
$(tput setaf 201) \
$(tput setaf 208) \
$(tput setaf 196) )
declare -r UNCLR256=$(tput setab 6)
declare -r BOMBED256=$(tput setaf 196; tput rev)
declare -r FLAGGED256=$(tput setaf 190; tput rev)


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

# screenToMapX <x>
# Convert screen coordinates X into map coordinates X
screenToMapX()
{
	echo $(($1 + cameraX))
}

# screenToMapY <y>
# Convert screen coordinates Y into map coordinates Y
screenToMapY()
{
	echo $(($1 + cameraY))
}

# screenToMapCoordinates <x> <y>
# Convert screen coordinates X,Y into map coordinates X,Y
screenToMapCoordinates()
{
	echo $(screenToMapX $1; screenToMapY $2)
}

mapToScreenX()
{
	echo $(($1 - cameraX))
}

mapToScreenY()
{
	echo $(($1 - cameraY))
}

# _putGap1|_putGap8|_putGap256 <x> <y>
# x: [0, w]
# Print the gap on the left of given cell.
_putGap1()
{
	if [[ $1 -le 0 && $1 -ge $mapWidth ]]; then
		echo -n ' '
		return 0
	fi

	local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	local r=${theMap[$(getIndexByCell $1 $2)]}

	if grep -q -E "[0-8]" <<< "$l$r"; then
		echo -n ' '
		return 0
	fi

	echo -n "${UNCLR1} ${RESET_COLOR}"
}

_putGap8()
{
	if [[ $1 -le 0 && $1 -ge $mapWidth ]]; then
		echo -n ' '
		return 0
	fi

	local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	local r=${theMap[$(getIndexByCell $1 $2)]}

	if grep -q -E "[0-8]" <<< "$l$r"; then
		echo -n ' '
	elif [[ $l = '.' || $r = '.' ]]; then
		echo -n "${UNCLR8} ${RESET_COLOR}"
	elif [[ $l = '!' || $r = '!' ]]; then
		echo -n "${FLAGGED8} ${RESET_COLOR}"
	else
		echo -n "${BOMBED8} ${RESET_COLOR}"
	fi
}

_putGap256()
{
	if [[ $1 -le 0 && $1 -ge $mapWidth ]]; then
		echo -n ' '
		return 0
	fi

	local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	local r=${theMap[$(getIndexByCell $1 $2)]}

	if grep -q -E "[0-8]" <<< "$l$r"; then
		echo -n ' '
	elif [[ $l = '.' || $r = '.' ]]; then
		echo -n "${UNCLR256} ${RESET_COLOR}"
	elif [[ $l = '!' || $r = '!' ]]; then
		echo -n "${FLAGGED256} ${RESET_COLOR}"
	else
		echo -n "${BOMBED256} ${RESET_COLOR}"
	fi
}

# _putCell1|_putCell8|_putCell256 <x> <y>
# Print the given cell value.
_putCell1()
{
	local value=${map[$(getIndexByCell $1 $2)]}
	case $value in
		0 )
			echo -n ' '
			;;
		[1-8] )
			echo -n $value
			;;
		'!' )
			echo -n ${UNCLR1}'!'${RESET_COLOR}
			;;
		9 )
			echo -n ${UNCLR1}'*'${RESET_COLOR}
			;;
		'.' )
			echo -n ${UNCLR1}' '${RESET_COLOR}
			;;
	esac
}

_putCell8()
{
	local value=${map[$(getIndexByCell $1 $2)]}
	case $value in
		0 )
			echo -n ' '
			;;
		[1-8] )
			echo -n "${NUM8}${value}${RESET_COLOR}"
			;;
		9 )
			echo -n ${BOMBED8}'*'${RESET_COLOR}
			;;
		'!' )
			echo -n ${FLAGGED8}'!'${RESET_COLOR}
			;;
		'.' )
			echo -n ${UNCLR8}' '${RESET_COLOR}
			;;
	esac
}

_putCell256()
{
	local value=${map[$(getIndexByCell $1 $2)]}
	case $value in
		0 )
			echo -n ' '
			;;
		[1-8] )
			echo -n "${NUM256[$value]}${value}${RESET_COLOR}"
			;;
		9 )
			echo -n ${BOMBED256}'*'${RESET_COLOR}
			;;
		'!' )
			echo -n ${FLAGGED256}'!'${RESET_COLOR}
			;;
		'.' )
			echo -n ${UNCLR256}' '${RESET_COLOR}
			;;
	esac
}

# _putSelection1|_putSelection8|_putSelection256 <x> <y>
# Print cell selection mark on the cell x,y in the map.
# Auto detect position on screen.
# If not in screen, do nothing.
_putSelection1()
{
	local x=$(mapToScreenX $1)
	local y=$(mapToScreenY $2)
	if [[ $x -lt 0 || $x -ge $cameraWidth || $y -lt 0 || $y -ge $cameraHeight ]]; then
		return 1
	fi

	tput cup $y $((x*2))
	if [[ $1 -le 0 ]]; then
		echo -n '['
	else
		local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
		local r=${theMap[$(getIndexByCell $1 $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n '['
		else
			echo -n "${UNCLR1}[${RESET_COLOR}"
		fi
	fi

	tput cup $y $((x*2+2))
	if [[ $1 -gt $mapWidth ]]; then
		echo -n ']'
	else
		local l=${theMap[$(getIndexByCell $1 $2)]}
		local r=${theMap[$(getIndexByCell $(($1+1)) $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n ']'
		else
			echo -n "${UNCLR1}]${RESET_COLOR}"
		fi
	fi
}

_putSelection8()
{
	local x=$(mapToScreenX $1)
	local y=$(mapToScreenY $2)
	if [[ $x -lt 0 || $x -ge $cameraWidth || $y -lt 0 || $y -ge $cameraHeight ]]; then
		return 1
	fi

	tput cup $y $((x*2))
	if [[ $1 -le 0 ]]; then
		echo -n '['
	else
		local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
		local r=${theMap[$(getIndexByCell $1 $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n '['
		elif [[ $l = '.' || $r = '.' ]]; then
			echo -n "${UNCLR8}[${RESET_COLOR}"
		elif [[ $l = '!' || $r = '!' ]]; then
			echo -n "${FLAGGED8}[${RESET_COLOR}"
		else
			echo -n "${BOMBED8}[${RESET_COLOR}"
		fi
	fi

	tput cup $y $((x*2+2))
	if [[ $1 -gt $mapWidth ]]; then
		echo -n ']'
	else
		local l=${theMap[$(getIndexByCell $1 $2)]}
		local r=${theMap[$(getIndexByCell $(($1+1)) $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n ']'
		elif [[ $l = '.' || $r = '.' ]]; then
			echo -n "${UNCLR8}]${RESET_COLOR}"
		elif [[ $l = '!' || $r = '!' ]]; then
			echo -n "${FLAGGED8}]${RESET_COLOR}"
		else
			echo -n "${BOMBED8}]${RESET_COLOR}"
		fi
	fi
}

_putSelection256()
{
	local x=$(mapToScreenX $1)
	local y=$(mapToScreenY $2)
	if [[ $x -lt 0 || $x -ge $cameraWidth || $y -lt 0 || $y -ge $cameraHeight ]]; then
		return 1
	fi

	tput cup $y $((x*2))
	if [[ $1 -le 0 ]]; then
		echo -n '['
	else
		local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
		local r=${theMap[$(getIndexByCell $1 $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n '['
		elif [[ $l = '.' || $r = '.' ]]; then
			echo -n "${UNCLR256}[${RESET_COLOR}"
		elif [[ $l = '!' || $r = '!' ]]; then
			echo -n "${FLAGGED256}[${RESET_COLOR}"
		else
			echo -n "${BOMBED256}[${RESET_COLOR}"
		fi
	fi

	tput cup $y $((x*2+2))
	if [[ $1 -gt $mapWidth ]]; then
		echo -n ']'
	else
		local l=${theMap[$(getIndexByCell $1 $2)]}
		local r=${theMap[$(getIndexByCell $(($1+1)) $2)]}

		if grep -q -E "[0-8]" <<< "$l$r"; then
			echo -n ']'
		elif [[ $l = '.' || $r = '.' ]]; then
			echo -n "${UNCLR256}]${RESET_COLOR}"
		elif [[ $l = '!' || $r = '!' ]]; then
			echo -n "${FLAGGED256}]${RESET_COLOR}"
		else
			echo -n "${BOMBED256}]${RESET_COLOR}"
		fi
	fi
}

# setColorConfig <1|8|256>
setColorConfig()
{
	case $1 in
		1 )
			PUTGAP=_putGap1
			PUTCELL=_putCell1
			PUTSELECTION=_putSelection1
			;;

		8 )
			PUTGAP=_putGap8
			PUTCELL=_putCell8
			PUTSELECTION=_putSelection8
			;;

		256 )
			PUTGAP=_putGap256
			PUTCELL=_putCell256
			PUTSELECTION=_putSelection256
			;;

		* )
			echo "Invalid color type." >&2
			;;
	esac
}

sendUpdateMapRequest()
{
	local x=$((cameraX-5))
	local y=$((cameraY-5))
	local w=$((cameraWidth+10))
	local h=$((cameraHeight+10))
	if [[ $x -lt 0 ]]; then
		((w+=x))
		x=0
	fi
	if [[ $y -lt 0 ]]; then
		((h+=y))
		y=0
	fi
	if [[ $((x+w)) -gt $mapWidth ]]; then
		w=$((mapWidth-x))
	fi
	if [[ $((y+h)) -gt $mapHeight ]]; then
		h=$((mapHeight-y))
	fi

	echo "Get $x $y $w $h" >&6
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
	tput clear

	local rowBegin rowEnd
	# local colBegin colEnd
	if [[ $cameraHeight -gt $mapHeight ]]; then
		rowBegin=$(((cameraHeight - mapHeight)/2))
		rowEnd=$((rowBegin + mapHeight))
	else
		rowBegin=0
		rowEnd=$cameraHeight
	fi

	for (( i = rowBegin; i < rowEnd; i++ )); do
		tput cup $i 0
		for (( j = cameraX; j < cameraX+cameraWidth; ++j )); do
			if [[ $j -lt 0 ]]; then
				echo -n '  '
			elif [[ $j -ge $mapWidth ]]; then
				break
			else
				$PUTGAP $j $((cameraY+i))
				$PUTCELL $j $((cameraY+i))
			fi
		done
		if [[ $((cameraX+cameraWidth)) -lt $mapWidth ]]; then
			$PUTGAP $((cameraX+cameraWidth)) $((cameraY+i))
			if [[ $((COLUMNS%2)) -eq 0 ]]; then
				$PUTCELL $((cameraX+cameraWidth)) $((cameraY+i))
			fi
		fi
	done
	$PUTSELECTION $selectionX $selectionY
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
		cameraY=$((-(mapHeight - cameraHeight)/2))
	else
		fix_y=""
		cameraY=$(getRand 0 $((mapHeight - cameraHeight)))
	fi
}



cellDeselect()
{
	:
}

# cellSelect <x> <y>
cellSelect()
{
	:
}

# # cellSelectionMove <up|down|left|right>
# cellSelectionMove()
# {
# 	:
# }


onResized()
{
	:
}


receiveLoop()
{
	local response
	local responseHead
	local responseBody
	local x y w h

	while true; do
		read response <&6
		responseHead=$(cut -d ' ' -f 1 <<< response)
		responseBody=$(cut -d ' ' -f 2- <<< response)
		responseBody=($responseBody)

		case $responseHead in
			Disconnect )
				exit 0
				;;

			Map )
				x=$(cut -d ' ' -f 1 <<< responseBody)
				y=$(cut -d ' ' -f 2 <<< responseBody)
				w=$(cut -d ' ' -f 3 <<< responseBody)
				h=$(cut -d ' ' -f 4 <<< responseBody)
				responseBody=( $(cut -d ' ' -f 5- <<< responseBody) )
				for (( i = 0; i < h; i++ )); do
					for (( j = 0; j < w; j++ )); do
						map[$(getIndexByCell $((x+j)) $((y+i)))]=responseBody[$((i*w+j))]
					done
				done
				refreshScreen
				;;

			Changed )
				sendUpdateMapRequest
				;;
		esac
	done
}

mainLoop()
{
	local input
	while true; do
		read -n 1 -s input

	done
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

		if [[ $mapWidth -le 0 || $mapHeight -le 0 ]]; then
			gameState=$FAILED
			echo "***FETAL ERROR: Server returned invalid data.***"
			return 3
		fi
	elif [[ ${response[0]} = "Deny" ]]; then
		echo "${response[@]}"
		return 1
	fi

	return 0
}

runGame()
{
	echo "Please Wait..." >&2

	for (( i = 0; i < $mapWidth*$mapHeight; i++ )); do
		map[$i]='.'
	done

	receiveLoop &
	receiveLoopPid=$!

	initMapPosition

	sendUpdateMapRequest

	cellSelect $((cameraX+cameraWidth/2)) $((cameraY+cameraHeight/2))

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
		option=$(dialog --title "${dialogTitle}" --menu "Connected successfully." 10 30 3 1 "Log in" \
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
				enterAsGuest
				if [[ $? -eq 1 ]]; then
					dialog --title "${dialogTitle}" --msgbox \
						"Server denied your request." 6 30
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
	if grep -q "256color" <<< "$TERM"; then
		setColorConfig 256
	else
		setColorConfig 8
	fi
	interactiveMode
else
	runWithArgs $*
fi


exit $?
