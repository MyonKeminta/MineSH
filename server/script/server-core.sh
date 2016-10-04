#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"
source "${MINESH_SERVER_PATH}/script/config.sh"
source "${MINESH_SERVER_PATH}/script/data-manager.sh"
source "${MINESH_SERVER_PATH}/script/map.sh"

tempPath="${MINESH_SVR_DATA_DIR}/.temp"
requestQueue="${tempPath}/queue"
declare ncatPid
declare loopPid

# Established connections
declare -A connections
readonly UNKNOWN=1
readonly CONNECTED=2
readonly GUEST=3
readonly LOGEDIN=4

# Descriptor &5: Request queue


onServerStopped()
{
	if [[ -n $stopped ]]; then
		return 0
	fi
	saveStateMap
	mineshInfo "Server stopped."
	rm -r $tempPath
	if [[ -n $ncatPid ]]; then
		kill $ncatPid
		unset ncatPid
	fi
	stopped=1
}

stopServer()
{
	if [[ -z $stopped ]]; then
		echo 'Stop' > ${requestQueue}
		wait
	fi
}

forceStopServer()
{
	if [[ -n $ncatPid ]]; then
		kill $ncatPid
		unset ncatPid
	fi
	if [[ -n $loopPid ]]; then
		kill $loopPid
		unset loopPid
	fi
	onServerStopped
}

disconnect()
{
	echo "Disconnect" > "${tempPath}/$1"
	$TPUT bold
	$TPUT setaf 1
	mineshLog "ID $1 disconnected."
	$TPUT sgr0
}

serverLoop()
{
	local line
	local request
	while true; do
		read request <&5
		echoc 5 "Got request: $request"
		if [[ $request = "Stop" ]]; then
			for i in ${!connections[@]}; do
				disconnect $i
			done
			onServerStopped
			return 0
		fi

		line=$(cut -d ' ' -f 1 <<< "$request")
		request=$(cut -d ' ' -f 2- <<< "$request")



	done
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


	# Setup the log
	setLogFile "${MINESH_SVR_DATA_DIR}/log"
	$TPUT setaf 6
	$TPUT bold
	mineshLog "Server started"
	$TPUT sgr0


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
			if grep -E -q "^[0-9]+$" <<< $2; then
				port=$2
			else
				mineshErr "Invalid port. Default port will be used."
			fi
		fi
	fi

	if ! loadMap "${MINESH_SVR_DATA_DIR}/map"; then
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
	exec 5<>"$requestQueue"

	local cmd="${MINESH_SERVER_PATH}/script/networkInterface ${requestQueue} ${tempPath}"
	if [[ -n DISABLE_STYLE ]]; then
		cmd="${cmd} --disable-style"
	fi
	ncat -vlk --sh-exec "$cmd" $port &
	ncatPid=$!


	serverLoop &

	loopPid=$!

	trap "forceStopServer; exit 1" 1 2 3
	trap "forceStopServer; exit 1" 15
	
	$TPUT bold
	mineshInfo "Server started. Press Ctrl+D to stop."
	$TPUT sgr0

	local CtrlD=$(echo -e '\x04')

	while read -s -n 1 ch; do
		if [[ $ch = $CtrlD ]]; then
			break
		fi
	done

	stopServer
	return 0
}