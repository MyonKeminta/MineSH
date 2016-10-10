#!/bin/bash


# Initialize the environment

serverPath=$(dirname $(cd $(dirname $(which $0)); pwd))

if [[ $# -ge 3 && $3 = "--disable-style" ]]; then
	export DISABLE_STYLE=1
fi

source "${serverPath}/script/utils.sh"
source "${serverPath}/script/errinfo.sh"

if [[ $# -lt 2 ]]; then
	mineshErr "To few args to startup the network interface."
	exit 1
fi

if [[ -z $1 || -z $2 ]]; then
	mineshErr "networkInterfase.sh: Invalid args."
fi

requestQueue=$1
tempPath=$2

connectionId=0
while [[ -e "${tempPath}/${connectionId}" ]]; do
	((++connectionId))
done



# Build the tunnel to communicate with the server core.

responseQueue="${tempPath}/${connectionId}"
mkfifo $responseQueue
if [[ $? -ne 0 ]]; then
	mineshErr "Failed creating fifo."
	exit 2
fi

# 7: resuest queue.
exec 7<>"${requestQueue}"

# 8: response queue.
exec 8<>"${responseQueue}"

declare pushPid




# onExit [-s]
# -s: Disconnected by server.
onExit()
{
	if [[ $exited = 1 ]]; then
		return 0
	fi
	exited=1
	# If no -s
	if [[ $# -eq 0 || $1 != "-s" ]]; then
		kill $pushPid
		echo "${connectionId} Disconnect" >&7
	fi
	rm ${responseQueue}
}

trap "onExit" 0 1 2 3


# Start the two loops

# Send responses to client
# pushResponseLoop <main-process-pid>
pushResponseLoop()
{
	local str
	while true; do
		read str <&8
		echo $str
		if [[ $str = "Disconnect" ]]; then
			onExit -s
			kill -9 $1
			return 0
		fi
	done
}

pushResponseLoop $$ &
pushPid=$!


echo "${connectionId} Connected" >&7

while read request; do
	request="${connectionId} ${request}"
	echo $request >&7
done

exit 0

