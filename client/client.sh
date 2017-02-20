#!/bin/bash


# Descriptor &3, &4: reserved for temporary use
# Descriptor &6: process queue
# Descriptor &7: TCP connection. Do not read directly from &7.


readonly MINESH_VERSION="v0.1a"
readonly serverConfirmMsg="MineSH-server ${MINESH_VERSION}"
readonly clientConfirmMsg="MineSH-client ${MINESH_VERSION}"
readonly dialogTitle="MineSH ${MINESH_VERSION}"
export readonly pipePath="/dev/shm/minesh-client-${USER}-$$"

declare -ix mapWidth mapHeight
declare -ax theMap
declare -ix cameraX cameraY
declare -ix cameraWidth cameraHeight
declare -ix selectionX selectionY
declare -x fix_x fix_y
declare -x isScreenWidthEven


declare -x waitingForResize

declare -x receiveLoopPid
declare -x networkLoopPid
declare -x mainPid

readonly NULL=1
readonly UNKNOWN=2
readonly CONNECTED=3
readonly GUEST=4
readonly LOGEDIN=5
readonly DISCONNECTED=-1
readonly FAILED=-2
export gameState=$NULL


declare -x PUTGAP
declare -x PUTCELL
declare -x PUTSELECTION

declare -rx RESET_COLOR=$(tput sgr0)


declare -x COLOR_CONFIG

# Mono color
declare -rx UNCLR1=$(tput rev)

# 8 color
declare -rx NUM8=$(tput setaf 2)
declare -rx UNCLR8=$(tput setab 6)
declare -rx BOMBED8=$(tput setaf 1; tput rev)
declare -rx FLAGGED8=$(tput setaf 3; tput rev)

# 256 color
declare -rax NUM256=("" \
$(tput setaf 46) \
$(tput setaf 51) \
$(tput setaf 21) \
$(tput setaf 57) \
$(tput setaf 165) \
$(tput setaf 201) \
$(tput setaf 208) \
$(tput setaf 196) )
declare -rx UNCLR256=$(tput setab 75)
declare -rx BOMBED256=$(tput setaf 196; tput rev)
declare -rx FLAGGED256=$(tput setaf 190; tput rev)

declare -rx CLR_EOL=$(tput el)

declare -rx ESC=$(echo -en "\E")


declare -i scrollCount=0


readonly OPERATE_HELP_DOCUMENT="\
[Arrow]          Move selection\n\
[Shift+Arrow]    Move selection for 5 cells distance\n\
[Ctrl+Arrow]     Move camera for 2 cells distance\n\
[Alt+Arrow]      Move camera for half of the screen\n\
\n\
[Z]              Reveal the selected cell\n\
[X]              Flag the selected cell\n\
[Space]          Auto check cells around the selected cell\n\
[Q]|[Esc]        Leave the game\
"

readonly CMD_OPTION_HELP_DOCUMENT="\
-h | --help\n\
	Print this help and exit.\n\
\n\
-s | --server  <server>\n\
	Specify the server you want to connect to.\n\
-g | --guest\n\
	Enter the game as guest. (default)\n\
\n\
	Login function is not implemented yet.\n\
\n\
\n\
-c | --color 1|8|256\n\
	Select the color profile: 1-color, 8-color, or 256-color.\n\
	By default, 256-color profile will be used if supported.
	If not, 8-color will be used.\n\
"



onStopped()
{
	exec 6<&- 6>&- 7<&- 7>&-
	rm "$pipePath"
	if [[ "$gameState" -ge $GUEST ]]; then
		gameState=$DISCONNECTED
		tput clear
		tput cvvis
	fi
}

onStoppedByServer()
{
	if [[ -n "$exited" ]]; then
		return 0
	fi
	exited=1
	onStopped
}

onStoppedByUser()
{
	if [[ -n "$exited" ]]; then
		return 0
	fi
	exited=1
	[[ -n "$receiveLoopPid" ]] && kill $receiveLoopPid
	[[ -n "$networkLoopPid" ]] && kill $networkLoopPid
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


# _putGap1|_putGap8|_putGap256 <index>
# DEPRECATED: _putGap1|_putGap8|_putGap256 <x> <y>
# x: [0, w]
# Print the gap on the left of given cell.
_putGap1()
{
	if [[ $1 -le 0 && $1 -ge $mapWidth ]]; then
		echo -n ' '
		return 0
	fi

	# local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	# local r=${theMap[$(getIndexByCell $1 $2)]}
	local l=${theMap[$(($1-1))]}
	local r=${theMap[$1]}

	# if grep -q -E "[0-8]" <<< "$l$r"; then
	if [[ $l = [0-8] || $r = [0-8] ]]; then
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

	# local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	# local r=${theMap[$(getIndexByCell $1 $2)]}
	local l=${theMap[$(($1-1))]}
	local r=${theMap[$1]}

	# if grep -q -E "[0-8]" <<< "$l$r"; then
	if [[ $l = [0-8] || $r = [0-8] ]]; then
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

	# local l=${theMap[$(getIndexByCell $(($1-1)) $2)]}
	# local r=${theMap[$(getIndexByCell $1 $2)]}
	local l=${theMap[$(($1-1))]}
	local r=${theMap[$1]}

	# if grep -q -E "[0-8]" <<< "$l$r"; then
	if [[ $l = [0-8] || $r = [0-8] ]]; then
		echo -n ' '
	elif [[ $l = '.' || $r = '.' ]]; then
		echo -n "${UNCLR256} ${RESET_COLOR}"
	elif [[ $l = '!' || $r = '!' ]]; then
		echo -n "${FLAGGED256} ${RESET_COLOR}"
	else
		echo -n "${BOMBED256} ${RESET_COLOR}"
	fi
}

# _putCell1|_putCell8|_putCell256 <index>
# DEPRECATED: _putCell1|_putCell8|_putCell256 <x> <y>
# Print the given cell value.
_putCell1()
{
	# local value=${theMap[$(getIndexByCell $1 $2)]}
	local value=${theMap[$1]}
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
	# local value=${theMap[$(getIndexByCell $1 $2)]}
	local value=${theMap[$1]}
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
	# local value=${theMap[$(getIndexByCell $1 $2)]}
	local value=${theMap[$1]}
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
	tput cup $cameraHeight 0
}

_putSelection8()
{
	local x=$(mapToScreenX $1)
	local y=$(mapToScreenY $2)
	if [[ $x -lt 0 || $x -ge $cameraWidth || $y -lt 0 || $y -ge $cameraHeight ]]; then
		return 1
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

	tput cup $cameraHeight 0
}

_putSelection256()
{
	local x=$(mapToScreenX $1)
	local y=$(mapToScreenY $2)
	if [[ $x -lt 0 || $x -ge $cameraWidth || $y -lt 0 || $y -ge $cameraHeight ]]; then
		return 1
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

	tput cup $cameraHeight 0
}

# setColorConfig <1|8|256>
setColorConfig()
{
	case $1 in
		1 )
			export COLOR_CONFIG=1
			export PUTGAP=_putGap1
			export PUTCELL=_putCell1
			export PUTSELECTION=_putSelection1
			;;

		8 )
			export COLOR_CONFIG=8
			export PUTGAP=_putGap8
			export PUTCELL=_putCell8
			export PUTSELECTION=_putSelection8
			;;

		256 )
			export COLOR_CONFIG=256
			export PUTGAP=_putGap256
			export PUTCELL=_putCell256
			export PUTSELECTION=_putSelection256
			;;

		* )
			echo "Invalid color type." >&2
			;;
	esac
}

sendUpdateMapRequest()
{
	local x=$((cameraX-10))
	local y=$((cameraY-10))
	local w=$((cameraWidth+20))
	local h=$((cameraHeight+20))
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

	echo "Get $x $y $w $h" >&7
}

# getRand <min> <max>
# Generate a integer in [min, max)
getRand()
{
	# local ran=$(dd bs=4 count=1 'if=/dev/urandom' status=none | od --format=u --address-radix=none)
	local ran=$(dd bs=4 count=1 'if=/dev/urandom' 2>/dev/null | od -tu -Anone)
	echo $((ran%($2-$1)+$1))
}

refreshScreen()
{
	# tput clear

	local rowBegin rowEnd
	# local colBegin colEnd
	local index
	if [[ $cameraHeight -gt $mapHeight ]]; then
		rowBegin=$(((cameraHeight - mapHeight)/2))
		rowEnd=$((rowBegin + mapHeight))
	else
		rowBegin=0
		rowEnd=$cameraHeight
	fi


	for (( i = rowBegin; i < rowEnd; i++ )); do
		tput cup $i 0
		index=$(getIndexByCell $cameraX $((cameraY+i)))
		for (( j = cameraX; j < cameraX+cameraWidth; ++j )); do
			if [[ $j -lt 0 ]]; then
				echo -n '  '
			elif [[ $j -ge $mapWidth ]]; then
				break
			else
				# $PUTGAP $j $((cameraY+i))
				# $PUTCELL $j $((cameraY+i))
				$PUTGAP $index
				$PUTCELL $index
			fi
			(( ++index ))
		done
		if [[ $((cameraX+cameraWidth)) -lt $mapWidth ]]; then
			# $PUTGAP $((cameraX+cameraWidth)) $((cameraY+i))
			$PUTGAP $index
			if [[ $((COLUMNS%2)) -eq 0 ]]; then
				# $PUTCELL $((cameraX+cameraWidth)) $((cameraY+i))
				$PUTCELL $index
			fi
		fi
		echo -n "$CLR_EOL"
	done
	$PUTSELECTION $selectionX $selectionY

	# for (( i = 0; i < mapWidth*mapHeight; i++ )); do
	# 	echo -n "${theMap[$i]} "
	# done > b
}

initMapPosition()
{
	#eval $(resize)
	export LINES=$(tput lines)
	export COLUMNS=$(tput cols)

	export cameraHeight=$((LINES-1))
	export cameraWidth=$(((COLUMNS-1)/2))

	if [[ $cameraWidth -ge $mapWidth ]]; then
		export fix_x=1
		export cameraX=$((-(mapWidth - cameraWidth)/2))
	else
		export fix_x=""
		export cameraX=$(getRand 0 $((mapWidth - cameraWidth)))
	fi
	if [[ $cameraHeight -ge $mapHeight ]]; then
		export fix_y=1
		export cameraY=$((-(mapHeight - cameraHeight)/2))
	else
		export fix_y=""
		export cameraY=$(getRand 0 $((mapHeight - cameraHeight)))
	fi
}



cellDeselect()
{
	local x=$(((selectionX - cameraX)*2))
	local y=$((selectionY - cameraY))
	tput cup $y $x
	$PUTGAP $(getIndexByCell $selectionX $selectionY)
	tput cup $y $((x+2))
	$PUTGAP $(getIndexByCell $((selectionX+1)) $selectionY)
}

# cellSelect <x> <y>
cellSelect()
{
	selectionX="$1"
	selectionY="$2"
	[[ $selectionX -lt 0 ]] && selectionX=0
	[[ $selectionY -lt 0 ]] && selectionY=0
	[[ $selectionX -ge $mapWidth ]] && selectionX=$(($mapWidth-1))
	[[ $selectionY -ge $mapHeight ]] && selectionY=$(($mapHeight-1))
	local toRefresh=''
	if [[ -z $fix_x ]]; then
		if [[ $cameraX -gt $selectionX ]]; then
			((scrollCount += cameraX - selectionX))
			cameraX=$selectionX
			toRefresh=1
		elif [[ $cameraX -le $((selectionX - cameraWidth)) ]]; then
			((scrollCount += selectionX - cameraWidth + 1 - cameraX))
			cameraX=$((selectionX-cameraWidth+1))
			toRefresh=1
		fi
	fi
	if [[ -z $fix_y ]]; then
		if [[ $cameraY -gt $selectionY ]]; then
			((scrollCount += cameraY - selectionY))
			cameraY=$selectionY
			toRefresh=1
		elif [[ $cameraY -le $((selectionY - cameraHeight)) ]]; then
			((scrollCount += selectionY - cameraHeight + 1 - cameraY))
			cameraY=$((selectionY-cameraHeight+1))
			toRefresh=1
		fi
	fi
	if [[ -n $toRefresh ]]; then
		[[ ${scrollCount} -ge 9 ]] && { scrollCount=0; sendUpdateMapRequest; }
		refreshScreen
	fi

	$PUTSELECTION $selectionX $selectionY
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


localMsgHandler()
{
	if [[ $1 = "usercmd" ]]; then
		shift
# 		if grep -q -E "(^exit$)|(^ *(move|screen)(left|right|up|down) *[0-9]* *$)|\
# ("; then
# 			#statements
# 		fi
	fi

	case $1 in
		moveleft )
			cellDeselect
			cellSelect $((selectionX-$2)) $selectionY
			;;

		moveright )
			cellDeselect
			cellSelect $((selectionX+$2)) $selectionY
			;;

		moveup )
			cellDeselect
			cellSelect $selectionX $((selectionY-$2))
			;;

		movedown )
			cellDeselect
			cellSelect $selectionX $((selectionY+$2))
			;;

		select )
			cellDeselect
			cellSelect "$2" "$3"
			;;

		screenleft )
			if [[ -z $fix_x ]]; then
				((cameraX-=$2))
				[[ $cameraX -lt 0 ]] && cameraX=0
				[[ $selectionX -ge $((cameraX + cameraWidth)) ]] && selectionX=$((cameraX + cameraWidth - 1))
				refreshScreen
				((scrollCount+=$2))
				if [[ $scrollCount -ge 9 ]]; then
					scrollCount=0
					sendUpdateMapRequest
				fi
			fi
			;;

		screenright )
			if [[ -z $fix_x ]]; then
				((cameraX+=$2))
				[[ $cameraX -gt $((mapWidth - cameraWidth)) ]] && cameraX=$((mapWidth - cameraWidth))
				[[ $selectionX -lt $cameraX ]] && selectionX=$cameraX
				refreshScreen
				((scrollCount+=$2))
				if [[ $scrollCount -ge 9 ]]; then
					scrollCount=0
					sendUpdateMapRequest
				fi
			fi
			;;

		screenup )
			if [[ -z $fix_y ]]; then
				((cameraY-=$2))
				[[ $cameraY -lt 0 ]] && cameraY=0
				[[ $selectionY -ge $((cameraY + cameraHeight)) ]] && selectionY=$((cameraY + cameraHeight - 1))
				refreshScreen
				((scrollCount+=$2))
				if [[ $scrollCount -ge 9 ]]; then
					scrollCount=0
					sendUpdateMapRequest
				fi
			fi
			;;

		screendown )
			if [[ -z $fix_y ]]; then
				((cameraY+=$2))
				[[ $cameraY -gt $((mapHeight - cameraHeight)) ]] && cameraY=$((mapHeight - cameraHeight))
				[[ $selectionY -lt $cameraY ]] && selectionY=$cameraY
				refreshScreen
				((scrollCount+=$2))
				if [[ $scrollCount -ge 9 ]]; then
					scrollCount=0
					sendUpdateMapRequest
				fi
			fi
			;;

		check )
			if [[ ${theMap[$(getIndexByCell $selectionX $selectionY)]} = '.' ]]; then
				echo "Check $selectionX $selectionY" >&7
			fi
			;;

		flag )
			if [[ ${theMap[$(getIndexByCell $selectionX $selectionY)]} = '.' ]]; then
				echo "Flag $selectionX $selectionY" >&7
			fi
			;;

		autocheck )
			local num="${theMap[$(getIndexByCell $selectionX $selectionY)]}"
			local temp
			if [[ "$num" = [1-8] ]]; then
				local unclearedList=""
				local unclearedCount=0
				local flaggedCount=0
				local bombedCount=0
				local totalCount=0

				for (( i = $selectionX-1; i <= $selectionX+1; i++ )); do
					for (( j = $selectionY-1; j <= $selectionY+1; j++ )); do
						[[ "$i" -eq "$selectionX" && "$j" -eq "$selectionY" ]] && continue
						[[ "$i" -lt 0 || "$i" -ge $mapWidth ]] && continue
						[[ "$j" -lt 0 || "$j" -ge $mapHeight ]] && continue
						case ${theMap[$(getIndexByCell $i $j)]} in
							'.' )
								((++totalCount))
								((++unclearedCount))
								unclearedList="$unclearedList $i $j"
								;;

							'!' )
								((++totalCount))
								((++flaggedCount))
								;;

							'9' )
								((++totalCount))
								((++bombedCount))
								;;
						esac
					done
				done

				if [[ "$unclearedCount" -gt 0 ]]; then
					if [[ "$num" -eq "$totalCount" ]]; then
						echo "Flag $unclearedList" >&7
					elif [[ "$num" -eq "$((flaggedCount+bombedCount))" ]]; then
						echo "Check $unclearedList" >&7
					fi
				fi
			fi
			;;

		# command )
		# 	;;

		kill )
			kill $mainPid
			;;

		* )
			tput cup $cameraHeight 0
			[[ "$COLOR_CONFIG" != '1' ]] && tput setaf 1
			tput rev
			tput el
			echo -n "ERROR: $* No such command." >&2
			tput cup $cameraHeight 0
			tput sgr0
	esac
}

receiveLoop()
{
	local response
	local responseHead
	local responseBody
	local x y w h
	local dataIndex
	local mapIndex

	for (( i = 0; i < $mapWidth*$mapHeight; i++ )); do
		theMap[$i]='.'
	done

	cellSelect $((cameraX+cameraWidth/2)) $((cameraY+cameraHeight/2))


	while true; do
		read response <&6
		# echo $response >> a
		responseHead=$(cut -d ' ' -f 1 <<< "$response")
		responseBody=$(cut -d ' ' -f 2- <<< "$response")
		# responseBody=($responseBody)
		case $responseHead in
			Disconnect )
				kill $mainPid
				exit 0
				;;

			Map )
				x=$(cut -d ' ' -f 1 <<< "$responseBody")
				y=$(cut -d ' ' -f 2 <<< "$responseBody")
				w=$(cut -d ' ' -f 3 <<< "$responseBody")
				h=$(cut -d ' ' -f 4 <<< "$responseBody")
				responseBody=$(cut -d ' ' -f 5- <<< "$responseBody")
				responseBody=($responseBody)
				# echo "$x $y $w $h $responseBody" >> a
				dataIndex=0
				for (( i = 0; i < h; i++ )); do
					mapIndex=$(getIndexByCell $x $((y+i)))
					for (( j = 0; j < w; j++ )); do
						theMap[$((mapIndex++))]=${responseBody[$((dataIndex++))]}
					done
				done
				refreshScreen
				;;

			Changed )
				sendUpdateMapRequest
				;;

			_Local )
				localMsgHandler $responseBody
				;;
		esac
	done
}

userInputLoop()
{
	local input
	local tempchar
	IFS='#'
	while true; do
		read -n 1 -s input
		if [[ "$input" = "$ESC" ]]; then
			while read -t 0.005 -s -n 1 tempchar; do
				input="$input$tempchar"
			done
		fi

		case $input in
			' ' )
				echo "_Local autocheck" >&6
				;;

			z|Z )
				echo "_Local check" >&6
				;;

			x|X )
				echo "_Local flag" >&6
				;;

			q|Q|"$ESC" )
				tput cup $cameraHeight 0
				if [[ "$COLOR_CONFIG" = '1' ]]; then
					tput rev
				else
					tput setab 3
					tput setaf 0
				fi
				tput el
				tput cvvis
				echo -n "Are you sure want to exit? [y/n]: "
				read -s -n 1 input
				if [[ "$input" = 'y' || "$input" = 'Y' ]]; then
					tput sgr0
					exit 0
				elif [[ "$input" = "$ESC" ]]; then
					# Flush
					while read -s -n 1 -t 0.005; do
						:
					done
				fi

				tput cup $cameraHeight 0
				tput civis
				tput sgr0
				tput el
				;;

			"$ESC[A" )
				# Up arrow
				echo "_Local moveup 1" >&6
				;;

			"$ESC[B" )
				# Down arrow
				echo "_Local movedown 1" >&6
				;;

			"$ESC[C" )
				# Right arrow
				echo "_Local moveright 1" >&6
				;;

			"$ESC[D" )
				# Left arrow
				echo "_Local moveleft 1" >&6
				;;

			"$ESC[1;5A" )
				# Ctrl+Up
				echo "_Local screenup 2" >&6
				;;

			"$ESC[1;5B" )
				# Ctrl+Down
				echo "_Local screendown 2" >&6
				;;

			"$ESC[1;5C" )
				# Ctrl+Right
				echo "_Local screenright 2" >&6
				;;

			"$ESC[1;5D" )
				# Ctrl+Left
				echo "_Local screenleft 2" >&6
				;;

			"$ESC[1;2A" )
				# Shift+Up
				echo "_Local moveup 5" >&6
				;;

			"$ESC[1;2B" )
				# Shift+Down
				echo "_Local movedown 5" >&6
				;;

			"$ESC[1;2C" )
				# Shift+Right
				echo "_Local moveright 5" >&6
				;;

			"$ESC[1;2D" )
				# Shift+Left
				echo "_Local moveleft 5" >&6
				;;

			"$ESC[1;3A" )
				# Alt+Up
				echo "_Local screenup $((cameraHeight/2))" >&6
				;;

			"$ESC[1;3B" )
				# Alt+Down
				echo "_Local screendown $((cameraHeight/2))" >&6
				;;

			"$ESC[1;3C" )
				# Alt+Right
				echo "_Local screenright $((cameraWidth/2))" >&6
				;;

			"$ESC[1;3D" )
				# Alt+Left
				echo "_Local screenleft $((cameraWidth/2))" >&6
				;;

			":" )
				tput cup $cameraHeight 0
				if [[ "$COLOR_CONFIG" = '1' ]]; then
					tput rev
				else
					tput setab 2
					tput setaf 0
				fi
				tput el
				tput cvvis
				local confirmed=''
				local charTmp
				input=''
				echo -n ': '
				while read -s -n 1 charTmp; do
					if [[ "$charTmp" = '' ]]; then
						confirmed=1
						break
					fi
					if [[ "$charTmp" = "$ESC" ]]; then
						# Flush
						while read -s -n 1 -t 0.005; do
							:
						done
						break
					fi
					echo -n "$charTmp"
					input="${input}${charTmp}"
				done
				tput sgr0
				tput civis
				tput cup $cameraHeight 0
				tput el
				[[ -n $confirmed ]] && echo "_Local usercmd $input" >&6
				;;
			
		esac
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
	exec 7<>"/dev/tcp/${1}/${2}"
	local result=$?
	if [[ $result -ne 0 ]]; then
		echo "Failed connecting to [${1}:${2}]." >&2
		return $result
	fi
	unset result

	gameState=$UNKNOWN

	# cat <&7 >&6 &
	local msg
	while true; do
		read msg <&7
		echo "$msg" >&6
	done &
	networkLoopPid=$!

	echo "${clientConfirmMsg}" >&7
	read serverInfo <&6
	if [[ $serverInfo != $serverConfirmMsg ]]; then
		exec 6>&- 6<&-
		echo "Cannot establish connection: Maybe this is not a MineSH server, the versions mismatched, or the server is full." >&2
		return 2
	fi
	gameState=$CONNECTED
	return 0
}

enterAsGuest()
{
	echo "Guest" >&7
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

	initMapPosition

	tput civis
	receiveLoop &
	receiveLoopPid=$!

	sendUpdateMapRequest

	# cellSelect $((cameraX+cameraWidth/2)) $((cameraY+cameraHeight/2))

	userInputLoop
}


interactiveMode()
{
	dialog --version > /dev/null 2> /dev/null
	if [[ "$?" -ne 0 ]]; then
		echo "Package 'dialog' is required to run interactive intro." >&2
		exit 1
	fi

	local tip1="Please enter the server you want to connect to."
	local tip2="(Example: www.abc.com:2333 or 127.0.0.1:65535)"
	local server
	# read
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
		option=$(dialog --title "${dialogTitle}" --menu "Connected successfully." 11 30 4 1 "Log in" \
			2 "Play as guest" 3 "Register" 4 "Help" 3>&1 1>&2 2>&3)
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
					return $?
				fi
				;;

			3 )
				dialog --title "${dialogTitle}" --msgbox "Not implemented yet." 6 30
				clear
				;;

			4 )
				dialog --title "${dialogTitle} Help" --msgbox "$OPERATE_HELP_DOCUMENT" 20 70
				clear
				;;
		esac
	done
}

runWithArgs()
{
	local server
	while [[ $# -gt 0 ]]; do
		case $1 in
			-h | --help )
				echo "$clientConfirmMsg"
				echo
				echo -e "$CMD_OPTION_HELP_DOCUMENT"
				echo -e "$OPERATE_HELP_DOCUMENT"
				return 0
				;;

			-s | --server )
				shift
				if [[ $# -lt 1 ]]; then
					echo "ERROR: No server address given. Exited." >&2
					return 1
				fi
				server="$1"
				;;

			-g | --guest )
				:
				;;

			-c | --color )
				shift
				if [[ $# -lt 1 ]]; then
					echo "ERROR: No color profile given. Please choose one of 1, 8 and 256." >&2
					return 1
				fi
				if ! grep -q -E "^(1|8|256)$" <<< "$1"; then
					echo "ERROR: Invalid color profile \"$1\". Please choose one of 1, 8 and 256." >&2
					return 1
				fi
				setColorConfig "$1"
				;;

			* )
				echo "ERROR: Invalid arg: $1." >&2
				return 1
				;;
		esac
		shift
	done
	if [[ -z "$server" ]]; then
		interactiveMode
	else
		connectToServer "$(cut -d ':' -f 1 <<< "$server")" "$(cut -d ':' -f 2 <<< "$server")"
		local result=$?
		if [[ $result -ne 0 ]]; then
			echo "Failed connecting to server." >&2
			return $result
		fi

		enterAsGuest
		if [[ $? -eq 1 ]]; then
			echo "Server denied your request." >&2
		else
			runGame
			return $?
		fi
	fi
}

export mainPid=$$

if [[ -e "${pipePath}" ]]; then
	echo "Unexpected error: Already running game in the current terminal." >&2
	echo "If not, please delete \"${pipePath}\" manually and try again." >&2
	exit 20
fi

mkfifo "${pipePath}"
if [[ $? -ne 0 ]]; then
	echo "Error occured on creating pipe : \"${pipePath}\"" >&2
	exit 21
fi

exec 6<>"${pipePath}"
trap "onStoppedByUser; exit 1" 1 2 3
trap "onStoppedByUser" 0

if grep -q "256color" <<< "$TERM"; then
	setColorConfig 256
else
	setColorConfig 8
fi

if [[ $# -eq 0 ]]; then
	interactiveMode
else
	runWithArgs $@
fi


exit $?
