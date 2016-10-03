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




# onExit [-n]
# -n: Do not kill the push loop.
onExit()
{
	if [[ $# -eq 0 || $1 != "-n" ]]; then
		kill pushPid
	fi
	rm ${responseQueue}

}

trap "onExit" 0 1 2 3 15


# Start the two loops

# Send responses to client
pushResponseLoop()
{
	local str
	while true; do
		read str <&8
		echo $str
		if [[ $str = "Disconnect" ]]; then
			onExit -n
			return 0
		fi
	done
}

pushResponseLoop &
pushPid=$!


echo "${connectionId} Connected"

while read request; do
	request="${connectionId} ${request}"
	echo $request >&7
done

exit 0

