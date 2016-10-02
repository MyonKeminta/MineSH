#!/bin/bash

# This file provides utils to print error info.

source "${MINESH_SERVER_PATH}/script/utils.sh"

svrTipHead="[minesh server] "


mineshErr()
{
	echoc 1 "${svrTipHead}$1" >&2
}

mineshInfo()
{
	echoc 4 "${svrTipHead}$1" >&2
}

mineshUndefinedCommand()
{
	if [[ $# -eq 0 ]]; then
		mineshErr "Invalid command."
	else
		mineshErr "Invalid command: $*"
	fi
}

mineshNoConfig()
{
	mineshErr "Config not found."
}

mineshNoConfigReadPermission()
{
	mineshErr "Permission denied on reading config."
}

mineshNoConfigWritePermission()
{
	mineshErr "Permission denied on	saving config."
}