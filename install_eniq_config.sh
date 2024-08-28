#!/bin/bash
#----------------------------------------------------------------------
# Ericsson Network IQ Installer installation script
#
# Usage: install_eniq_config.sh servertype
#
# ---------------------------------------------------------------------
# Copyright (c) 1999 - 2006 AB LM Ericsson Oy  All rights reserved.
# ---------------------------------------------------------------------
. /eniq/home/dcuser/.profile

if [ ! $1 ]; then
	echo "Usage: install_eniq_config.sh servertype"
fi
SERVER_TYPE=$1
echo "server_type=${SERVER_TYPE}"

if [ ! -r "${CONF_DIR}/niq.rc" ] ; then
  echo "ERROR: Source file is not readable at ${CONF_DIR}/niq.rc"
  exit 22
fi

. ${CONF_DIR}/niq.rc

TIMESTAMP=`date +%d.%m.%y_%H:%M:%S`
LOGFILE=${LOG_DIR}/platform_installer/eniq_config_${TIMESTAMP}.log
TEMP_DIR=/var/tmp
STORAGE_TYPE=`cat /eniq/installation/config/san_details | grep STORAGE_TYPE | awk -F"=" '{print $2}'`
COMMON_FUNCTIONS=/eniq/installation/core_install/lib/common_functions.lib

if [ -f ${CONF_DIR}/slot_configuration.ini ] ; then
  rm -f ${CONF_DIR}/slot_configuration.ini | tee -a ${LOGFILE}
fi

if [ -f ${COMMON_FUNCTIONS} ] ; then
	. ${COMMON_FUNCTIONS}
else
	echo "Cant not find file ${COMMON_FUNCTIONS}"
	exit 53
fi

. ${BIN_DIR}/common_variables.lib

$ECHO "Installing eniq_config..." | $TEE -a ${LOGFILE}
$ECHO "server type=${SERVER_TYPE}" | $TEE -a ${LOGFILE}

if [ ! -f slot_configuration.ini ] ; then
	$ECHO "Cant not find file slot_configuration.ini"
        exit 54
fi

$ECHO "[${SERVER_TYPE}]" > ${CONF_DIR}/engine_slot_configuration.ini
iniget ${SERVER_TYPE} -f slot_configuration.ini >> ${CONF_DIR}/engine_slot_configuration.ini | $TEE -a ${LOGFILE}
if [ ${STORAGE_TYPE} == "fs" ]; then
	$CAT ${CONF_DIR}/engine_slot_configuration.ini | $SED 's/slot2.1.formula=0.1n/slot2.1.formula=0.2n/g' > ${TEMP_DIR}/temp_slot
	$RM -f ${CONF_DIR}/engine_slot_configuration.ini
	$MV ${TEMP_DIR}/temp_slot ${CONF_DIR}/engine_slot_configuration.ini
fi
$CHMOD 644 ${CONF_DIR}/engine_slot_configuration.ini | $TEE -a ${LOGFILE}

_version_=version.properties

if [ ! -f ${_version_} ] ; then
        $ECHO "Cant find ${_version_}"
        exit 89
fi

module_name=$($GREP module.name ${_version_} | cut -d= -f 2)
new_version=$($GREP module.version ${_version_} | cut -d= -f 2)
new_build=$($GREP module.build ${_version_} | cut -d= -f 2)

old_label=$(ls -1 ${PLATFORM_DIR} | $GREP ^${module_name}-)
new_label=${module_name}-${new_version}b${new_build}

old_eniq_config_dir=${PLATFORM_DIR}/${old_label}
new_eniq_config_dir=${PLATFORM_DIR}/${new_label}

$ECHO "Updating versiondb"
vdb=${INSTALLER_DIR}/versiondb.properties
VTAG="module.eniq_config=${new_version}b${new_build}"
if [ ! -f ${vdb} ] ; then
        $ECHO "${VTAG}" > ${vdb}
        $CHMOD 640 ${vdb}
else
        OLD=$($GREP module.eniq_config ${vdb})
        if [ -z "${OLD}" ] ; then
                $ECHO "${VTAG}" >> ${vdb}
        else
                $CP ${vdb} ${vdb}.tmp
                $SED -e "/${OLD}/s//${VTAG}/g" ${vdb}.tmp > ${vdb}
                $RM ${vdb}.tmp
        fi
fi
$ECHO "eniq_config installed." | $TEE -a ${LOGFILE}

#delete version.properties after updating.
if [ -f ${_version_} ] ; then
        $RM -f ${_version_}
fi
