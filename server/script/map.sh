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
	if [[ $# -lt 1 ]]; then
		mineshErr "Invalid args."
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
}

# hasMine <x> <y>
# return 0 if there is a mine at position (x,y).
# return 1 otherwise.
hasMine()
{
	# TODO: Implement this.
}

