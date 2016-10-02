#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"
source "${MINESH_SERVER_PATH}/script/config.sh"
source "${MINESH_SERVER_PATH}/script/data-manager.sh"


onServerStopped()
{
	mineshInfo "Server stopped."
}


runServer()
{
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

	if ! loadMap; then
		mineshErr "Load map file failed."
		onServerStopped
		return 1
	fi

	
}