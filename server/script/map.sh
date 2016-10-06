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
	_mineMapPath="$1/state.map"

	# TODO: Finish this
}

# Save state map into file.
saveStateMap()
{
	# TODO: Implement this.
	:
}

# hasMine <x> <y>
# return 0 if there is a mine at position (x,y).
# return 1 otherwise.
hasMine()
{
	# TODO: Implement this.
	:
}

# getCellState <x> <y>
# echo 0-8 for cleared cells.
# echo 9 for bombed cells.
# echo . for uncleared cells.
# echo ! for flagged cells
getCellState()
{
	# TODO: Implement this.
	:
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
	# TODO: Implement this.
	:
}


# getRegionState <x> <y> <w> <h>
getRegionState()
{
	:
}

# triggerCells <x> <y> [...]
# Mark the cells as triggered.
# If mine under the cell, bomb.
triggerCells()
{
	while [[ $# -ge 2 ]]; do
		if [[ $(getCellState "$1" "$2") = '.' ]]; then
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
	# TODO: Implement this.
	:
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

