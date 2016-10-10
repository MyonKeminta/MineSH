#!/bin/bash

source "${MINESH_SERVER_PATH}/script/errinfo.sh"
source "${MINESH_SERVER_PATH}/script/utils.sh"

cleanUpData()
{
	if [[ ! -e ${MINESH_SVR_DATA_DIR} ]]; then
		mineshInfo "No thing to clean."
		return 1
	fi


	safeRmDir "${MINESH_SVR_DATA_DIR}"

	return $?
}

