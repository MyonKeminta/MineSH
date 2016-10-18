#!/bin/bash

source "${MINESH_SERVER_PATH}/script/utils.sh"
source "${MINESH_SERVER_PATH}/script/errinfo.sh"

# File path
declare _mineMapPath
declare _stateMapPath

declare -a _mineMap
declare -a _stateMap

declare -i _mapWidth
declare -i _mapHeight


getMapWidth()
{
	echo $_mapWidth
}

getMapHeight()
{
	echo $_mapHeight
}

# getIndexByCell <x> <y>
# echo the index of the element representing the given cell in the map array.
getIndexByCell()
{
	echo $(($1+$2*$_mapWidth))
}

# getCellByIndex <i>
# echo the cell coordinate of the ith element in the map array.
getCellByIndex()
{
	echo "$(($1%$_mapWidth)) $(($1/$_mapWidth))"
}


# loadMap <map-dir-path>
# Load map from file to memory.
# map-dir-path/mine.map stores positions of mines. That should not be modified.
# map-dir-path/state.map stores which cell was flagged, bombed or cleared.
loadMap()
{
	if [[ $# -lt 1 || -z $1 || ! -e $1 ]]; then
		mineshErr "loadMap: Invalid args."
		return 1
	fi
	_mineMapPath="$1/mine.map"
	_stateMapPath="$1/state.map"

	mineshInfo "Loading map..."

	local size
	local data

	{
		read size
		_mapWidth=$(cut -d ' ' -f 1 <<< "$size")
		_mapHeight=$(cut -d ' ' -f 2 <<< "$size")
		if [[ $_mapWidth -le 0 || $_mapHeight -le 0 ]]; then
			mineshErr "Failed loading map: Map file invalid."
			return 1
		fi

		read data
		_mineMap=($data)
	} < "${_mineMapPath}"

	read data < "${_stateMapPath}"
	_stateMap=($data)

	mineshInfo "Success loading map."
}

# Save state map into file.
saveStateMap()
{
	mineshLog "Saving state map..."
	if [[ -z $_stateMapPath ]]; then
		mineshErr "Map path is null. Failed saving state map."
		return 1
	fi

	{
		for (( i = 0; i < _mapHeight*_mapWidth; i++ )); do
			echo -n "${_stateMap[$i]} "
		done
		echo
	} > $_stateMapPath
	mineshLog "Saving state map completed."
	return 0
}

# hasMine <x> <y>
# return 0 if there is a mine at position (x,y).
# return 1 otherwise.
hasMine()
{
	[[ ${_mineMap[$(getIndexByCell "$1" "$2")]} = '9' ]]
	return $?
}

# getCellState <x> <y>
# echo 0-8 for cleared cells.
# echo 9 for bombed cells.
# echo . for uncleared cells.
# echo ! for flagged cells
getCellState()
{
	echo ${_stateMap[$(getIndexByCell "$1" "$2")]}
}

# isUnknown <x> <y>
# return 0 if the cell is unknown
isUnknown()
{
	[[ $(getCellState "$1" "$2") = '.' ]]
	return $?
}

# getCellValue <x> <y>
# echo 0-8 if no mine in the cell, and the value represents the count of mines around the cell.
# echo 9 if there's a mine in this cell.
getCellValue()
{
	# if hasMine "$1" "$2"; then
	# 	echo 9
	# 	return 0
	# fi

	# local adjacent=$((0xff))

	# # Remove left side if x == 0
	# if [[ $1 -eq 0 ]]; then
	# 	adjacent=$((adjacent&0x3e))
	# fi

	# # Remove right side if x == width-1
	# if [[ $1 -eq $_mapWidth-1 ]]; then
	# 	adjacent=$((adjacent&0xe3))
	# fi

	# # Remove top side if y == 0
	# if [[ $2 -eq 0 ]]; then
	# 	adjacent=$((adjacent&0x8f))
	# fi

	# #Remove bottom side if y == height-1
	# if [[ $2 -eq $_mapHeight-1 ]]; then
	# 	adjacent=$((adjacent&0xf8))
	# fi

	# local result=0

	echo ${_mineMap[$(getIndexByCell "$1" "$2")]}
}


# getRegionState <x> <y> <w> <h>
getRegionState()
{
	local i
	local j
	local index
	for (( i = 0; i < $4; i++ )); do
		index=$(getIndexByCell $1 $(($2+$i)))
		for (( j = 0; j < $3; j++ )); do
			echo -n "${_stateMap[$((index++))]} "
		done
	done
	echo
}

# triggerCells <x> <y> [...]
# Mark the cells as triggered.
# If mine under the cell, bomb.
triggerCells()
{
	while [[ $# -ge 2 ]]; do
		if isUnknown "$1" "$2"; then
			_stateMap[$(getIndexByCell "$1" "$2")]=$(getCellValue "$1" "$2")
		fi
		shift 2
	done
}

# checkCell <x> <y> [...]
# This means user clicked cell (x,y) to open it.
# More than one pair of x,y may be given.
# Expand cleared area in need.
checkCells()
{
	local result=1
	while [[ $# -ge 2 ]]; do
		if isUnknown "$1" "$2"; then
			result=0
			triggerCells "$1" "$2"
			if [[ $(getCellValue "$1" "$2") = 0 ]]; then
				if [[ $1 -ne 0 ]]; then
					checkCells "$(($1 - 1))" "$2"
				fi
				if [[ $1 -ne $(($_myWidth - 1)) ]]; then
					checkCells "$(($1 + 1))" "$2"
				fi
				if [[ $2 -ne 0 ]]; then
					checkCells "$1" "$(($2 - 1))"
				fi
				if [[ $2 -ne $(($_myHeight - 1)) ]]; then
					checkCells "$1" "$(($2 + 1))"
				fi
				if [[ $1 -ne 0 && $2 -ne 0 ]]; then
					checkCells "$(($1 - 1))" "$(($2 - 1))"
				fi
				if [[ $1 -ne 0 && $2 -ne $(($_myHeight - 1)) ]]; then
					checkCells "$(($1 - 1))" "$(($2 + 1))"
				fi
				if [[ $1 -ne $(($_myWidth - 1 )) && $2 -ne 0 ]]; then
					checkCells "$(($1 + 1))" "$(($2 - 1))"
				fi
				if [[ $1 -ne $(($_myWidth - 1 )) && $2 -ne $(($_myHeight - 1)) ]]; then
					checkCells "$(($1 + 1))" "$(($2 + 1))"
				fi
			fi
		fi
		shift 2
	done
	return $result
}

# putFlag <x> <y> [...]
# This means user right clicked cell (x,y) to flag it.
# More than one pair of x,y may be given.
# DO NOT FLAG IF NO MINE HERE!!!
putFlags()
{
	local changed=1
	while [[ $# -ge 2 ]]; do
		if hasMine "$1" "$2" && isUnknown "$1" "$2"; then
			_stateMap[$(getIndexByCell "$1" "$2")]='!'
			changed=0
		fi
		shift 2
	done
	return $changed
}



# getRand <min> <max>
# Generate a integer in [min, max)
getRand()
{
	local ran=$(dd bs=4 count=1 'if=/dev/urandom' status=none | od --format=u --address-radix=none)
	echo $((ran%($2-$1)+$1))
}


# generateMap <width> <height> [--mine-rate <rate-percent>] [--block <block-width> <block-height>]
# A block is a rectangle area on the map.
# A map can be divided into many blocks and a block can be divided into cells.
# A cell is the smallest unit of the map.
# Mines are generated for each block.
generateMap()
{
	local -i rate=25
	local -i blockWidth=50
	local -i blockHeight=50
	local -i width
	local -i height
	local -i rows
	local -i columns

	if [[ $# -lt 2 ]]; then
		mineshErr "Too few args passed to generateMap"
		return 1
	fi

	if ! grep -q -E "^[0-9]+$" <<< $1 || ! grep -q -E "^[0-9]+$" <<< $2 || [[ $1 -lt 1 || $2 -lt 1 ]]; then
		mineshErr "Invalid map size."
		return 1
	fi

	width=$1
	height=$2
	shift 2

	while [[ $# -gt 0 ]]; do
		local current=$1
		shift
		case $current in
			--mine-rate )
				if [[ $# -lt 1 ]]; then
					mineshErr "generateMap: Invalid args"
					return 1
				fi

				if ! grep -q -E "^[0-9]+$" <<< $1; then
					mineshErr "generateMap: Invalid args"
					return 1
				fi

				rate=$1
				if [[ $rate -gt 100 ]]; then
					rate=100
				fi
				shift
				;;

			--block )
				if [[ $# -lt 2 ]]; then
					mineshErr "generateMap: Invalid args"
					return 1
				fi

				if ! grep -q -E "^[0-9]+$" <<< $1 || ! grep -q -E "^[0-9]+$" <<< $2; then
					mineshErr "generateMap: Invalid args"
					return 1
				fi

				blockWidth=$1
				blockHeight=$2
				shift 2
				;;

			* )
				mineshErr "generateMap: Invalid args"
				return 1
				;;
		esac
	done

	if [[ -e "${MINESH_SVR_DATA_DIR}/map" ]]; then
		mineshInfo "Map file already existed. Are you sure to override them?"
		if ! confirm; then
			mineshInfo "Canceled generating map."
			return 3
		fi

		safeRmDir "${MINESH_SVR_DATA_DIR}/map"
		local result=$?

		if [[ $result -ne 0 ]]; then
			return $result
		fi
	fi

	columns=$((width/blockWidth))
	rows=$((height/blockHeight))

	#Round to integer counts of rows and columns.
	if [[ ${width}%${blockWidth} -gt 0 ]]; then
		((++columns))
		((width=colomns*blockWidth))
		mineshInfo "Rounded width to ${width}."
	fi
	if [[ ${height}%${blockHeight} -gt 0 ]]; then
		((++rows))
		((height=rows*blockHeight))
		mineshInfo "Rounded height to ${height}."
	fi

	echo "Preparing to generate..."

	local map

	for (( i = 0; i < width*height; i++ )); do
		map[$i]=0
	done

	local blockTemp

	for (( i = 0; i < blockWidth*blockHeight; i++ )); do
		blockTemp[$i]=$i
	done

	local blockMineCount=$((blockWidth*blockHeight*rate/100))

	local ran
	local temp
	local leftBorderFlag
	local rightBorderFlag
	local topBorderFlag
	local bottomBorderFlag

	# Debug code
	# echo $blockWidth $blockHeight $rows $columns $rate

	echo "Generating mines..."

	for (( i = 0; i < rows; i++ )); do
		for (( j = 0; j < columns; j++ )); do
			# Display the progress.
			echo -en "\rProgress: $(((i*columns+j)*100/(rows*columns)))%     "

			# Randomize the first $blockMineCount elements. No neet to reset.
			for (( k = 0; k < blockMineCount; k++ )); do
				ran=$(getRand 0 $((blockWidth*blockHeight)))
				temp=${blockTemp[$k]}
				blockTemp[$k]=${blockTemp[$ran]}
				blockTemp[$ran]=$temp
			done

			# Put mines into the map.
			for (( k = 0; k < blockMineCount; k++ )); do
				# WTF!??
				temp=$((((i*blockWidth+${blockTemp[$k]}/blockWidth)*columns+j)*blockWidth+${blockTemp[$k]}%blockWidth))
				[[ $((temp/width)) -eq 0 ]]
				topBorderFlag=$?
				[[ $((temp/width)) -eq $((height-1)) ]]
				bottomBorderFlag=$?
				[[ $((temp%width)) -eq 0 ]]
				leftBorderFlag=$?
				[[ $(((temp+1)%width)) -eq 0 ]]
				rightBorderFlag=$?

				((map[$temp]+=9))
				if [[ $leftBorderFlag -ne 0 ]]; then
					((++map[$temp-1]))
					if [[ $topBorderFlag -ne 0 ]]; then
						((++map[$temp-$width-1]))
					fi
					if [[ $bottomBorderFlag -ne 0 ]]; then
						((++map[$temp+$width-1]))
					fi
				fi

				if [[ $topBorderFlag -ne 0 ]]; then
					((++map[$temp-$width]))
				fi

				if [[ $bottomBorderFlag -ne 0 ]]; then
					((++map[$temp+$width]))
				fi

				if [[ $rightBorderFlag -ne 0 ]]; then
					((++map[$temp+1]))
					if [[ $topBorderFlag -ne 0 ]]; then
						((++map[$temp-$width+1]))
					fi
					if [[ $bottomBorderFlag -ne 0 ]]; then
						((++map[$temp+$width+1]))
					fi
				fi

			done
		done
	done

	echo -e "\rProgress: 100%     "


	# # Generate numbers on each cell
	# echo "Converting data..."
	# for (( i = 0; i < height; i++ )); do
	# 	echo -en "\rProgress: $((i*100/height))%     "
	# 	for (( j = 0; j < width; j++ )); do
	# 		local index=$((i*width+j))

	# 	done
	# done

	# echo -e "\rProgress: 100%"


	# Save the generated map.
	echo "Saving..."

	if [[ ! -e "${MINESH_SVR_DATA_DIR}/map" ]]; then
		mkdir "${MINESH_SVR_DATA_DIR}/map"
	fi

	{
		echo "$width $height"
		for (( i = 0; i < width*height; i++ )); do
			if [[ ${map[$i]} -gt 9 ]]; then
				echo -n "9 "
			else
				echo -n "${map[$i]} "
			fi
		done
	} > "${MINESH_SVR_DATA_DIR}/map/mine.map"
	if [[ $? -ne 0 ]]; then
		mineshErr "Failed Saving the mine map. Generation failed."
		return 5
	fi

	{
		for (( i = 0; i < width*height; i++ )); do
			echo -n ". "
		done
	} > "${MINESH_SVR_DATA_DIR}/map/state.map"
	if [[ $? -ne 0 ]]; then
		mineshErr "Failed Saving the state map. Generation failed."
		return 6
	fi

	echo "Done."

	return 0
}
