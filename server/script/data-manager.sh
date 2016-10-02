#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"

cleanUpData()
{
	if [[ ! -e ${MINESH_SVR_DATA_DIR} ]]; then
		mineshErr "Cannot find minesh server data directory."
		return 1
	fi


	safeRmDir "${MINESH_SVR_DATA_DIR}"

	return $?
}

# generateMap <width> <height> [--mine-rate <rate-percent>] [--block <block-width> <block-height>]
# A block is a rectangle area on the map.
# A map can be divided into many blocks and a block can be divided into cells.
# A cell is the smallest unit of the map.
# Mines are generated for each block.
generateMap()
{
	local rate=25
	local blockWidth=50
	local blockHeight=50
	local width
	local height
	local rows
	local columns

	if [[ $# -lt 2 ]]; then
		mineshErr "Too few args passed to generateMap"
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
				blockWidth=$2
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
	if [[ ${height}%{blockHeight} -gt 0 ]]; then
		((++rows))
		((height=rows*blockHeight))
		mineshInfo "Rounded height to ${height}."
	fi


	# Generator code here.

}