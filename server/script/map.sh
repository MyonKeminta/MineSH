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
getCellState()
{
	# TODO: Implement this.
	:
}

# checkCell <x> <y>
# This means user clicked cell (x,y) to open it.
# Expand cleared area in need.
checkCell()
{
	# TODO: Implement this.
	:
}

# putFlag <x> <y>
# This means user right clicked cell (x,y) to flag it.
# DO NOT FLAG IF NO MINE HERE!!!
putFlag()
{
	# TODO: Implement this.
	:
}

