#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"
source "${MINESH_SERVER_PATH}/script/config.sh"
source "${MINESH_SERVER_PATH}/script/data-manager.sh"

tempPath="${MINESH_SVR_DATA_DIR}/.temp"
requestQueue="%{tempPath}/queue"
declare ncatPid

onServerStopped()
{
	saveStateMap
	mineshInfo "Server stopped."
	rm -r $tempPath
}

serverLoop()
{

}

# runServer [-p <port>]
runServer()
{
	if [[ ${MINESH_SVR_DATA_DIR:-null} = null ]]; then
		mineshErr "***FATAL ERROR: MINESH_SVR_DATA_DIR env variable not existed."
		return 10
	fi

	if [[ -e $tempPath ]]; then
		rm -r $tempPath
	fi

	mkdir -p $tempPath



	# Load config file.
	loadConfig
	local result=$?
	if [[ $result -eq 1 ]]; then
		makeDefault
		saveConfig
		if [[ $? -ne 0 ]]; then
			mineshErr "Cannot create config file."
			onServerStopped
			return 1
		fi
	elif [[ $result -ne 0 ]]; then
		mineshErr "Read config file failed."
		onServerStopped
		return 1
	fi

	local port=$default_port

	# Use specified port if any.
	if [[ $# -eq 2 ]]; then
		if [[ $1 = "-p" ]]; then
			if grep "^[0-9]+$" <<< $2; then
				port=$2
			else
				mineshErr "Invalid port. Default port will be used."
			fi
		fi
	fi

	if ! loadMap; then
		mineshErr "Load map file failed."
		onServerStopped
		return 1
	fi

	ncat --version
	if [[ $? -ne 0 ]]; then
		mineshErr "Ncat not installed. Cannot run the server."
		onServerStopped
		return 2
	fi

	mkfifo "$requestQueue"

	local cmd="${MINESH_SERVER_PATH}/script/networkInterface ${requestQueue} ${tempPath}"
	if [[ -n DISABLE_STYLE ]]; then
		cmd="${cmd} --disable-style"
	fi
	ncat -vlk --sh-exec "$cmd" $port &
	ncatPid=$!

	serverLoop &

	local loopPid=$!

	trap "echo 'stop' > ${requestQueue}; wait; exit 1" 0 1 2 3 15
	
	$TPUT bold
	mineshInfo "Server started. Press Ctrl+D to stop."
	while read -s -n 1; do
		:
	done

	echo 'stop' > ${requestQueue}
	wait
	return 0
}