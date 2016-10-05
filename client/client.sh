#!/bin/bash


# Descriptor &3, &4: reserved for temporary use
# Descriptor &6: for tcp connection


readonly MINESH_VERSION="v0.1a"
readonly serverConfirmMsg="MineSH-server ${MINESH_VERSION}"
readonly clientConfirmMsg="MineSH-client ${MINESH_VERSION}"

declare -i mapWidth mapHeight
declare -a theMap

declare receiveLoopPid



onStopped()
{
	exec 6<&- 6>&-
}

onStoppedByServer()
{
	onStopped
}

onStoppedByUser()
{
	kill $receiveLoopPid
	onStopped
}


receiveLoop()
{

}

mainLoop()
{

}


connectToServer()
{
	if [[ $# -lt 2 ]]; then
		echo "Too few args given." >&2
		return 1
	fi
	exec 6<>"/dev/tcp/${1}/${2}"
	local result=$?
	if [[ $result -ne 0 ]]; then
		echo "Failed connecting to [${1}:${2}]."
		return $result
	fi
	unset result

	echo "${clientConfirmMsg}" >&6
	read serverInfo <&6
	if [[ $serverInfo != $serverConfirmMsg ]]; then
		exec 6>&- 6<&-
		echo "This is not a MineSH server or version mismatched."
		return 2
	fi
	return 0
}

# runGame <address> <port>
runGame()
{
	# if [[ $# -lt 2 ]]; then
	# 	echo "Too few args given." >&2
	# 	return 1
	# fi
	# exec 6<>"/dev/tcp/${1}/${2}"
	# local result=$?
	# if [[ $result -ne 0 ]]; then
	# 	echo "Failed connecting to [${1}:${2}]."
	# 	return $result
	# fi
	# unset result

	# echo "${clientConfirmMsg}" >&6
	# read serverInfo <&6
	# if [[ $serverInfo != $serverConfirmMsg ]]; then
	# 	exec 6>&- 6<&-
	# 	echo "This is not a MineSH server or version mismatched."
	# 	return 2
	# fi



	receiveLoop &
	receiveLoopPid=$!

	mainLoop
}


interactiveMode()
{
	local tip1="Please enter the server you want to connect to."
	local tip2="(Example: www.abc.com:2333 or 127.0.0.1:2333)"
	local server=$(dialog --title "MineSH ${MINESH_VERSION} " --inputbox "${tip1}\n\n${tip2}" 10 55 3>&1 1>&2 2>&3)
	if [[ $? -ne 0 ]]; then
		clear
		echo "Canceled." >&2
		return 1
	fi
	clear
	connectToServer "$(cut -d ':' -f 1 <<< ${server})" "$(cut -d ':' -f 2 <<< ${server})"
	local result=$?
	if [[ $result -ne ]]; then
		echo "Failed connecting to server." >&2
		return $result
	fi

	
}

runWithArgs()
{
	:
	# TODO: Finish this
}

if [[ $# -eq 0 ]]; then
	interactiveMode
else
	runWithArgs $*
fi


exit $?