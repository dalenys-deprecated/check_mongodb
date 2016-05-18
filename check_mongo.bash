#!/bin/bash

# Copyright (c) 2016, Dalenys
#
# Permission to use, copy, modify, and/or distribute this software for any purpose
# with or without fee is hereby  granted, provided that the above copyright notice
# and this permission notice appear in all copies.
#
# THE SOFTWARE  IS PROVIDED "AS IS"  AND THE AUTHOR DISCLAIMS  ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS.  IN NO  EVENT  SHALL THE  AUTHOR  BE LIABLE  FOR  ANY SPECIAL,  DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
# OF USE, DATA  OR PROFITS, WHETHER IN AN ACTION OF  CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR  IN CONNECTION WITH THE USE OR PERFORMANCE OF
# THIS SOFTWARE.

#set -x

REVISION="0.1"
PROGNAME=`basename $0`
VERBOSE=0

AUTH=0
PORT_MONGO=27017

# output of the mongo_query function
CMD_OUTPUT=""

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

MONGO_STATUS[0]="STARTUP"
MONGO_STATUS[1]="PRIMARY"
MONGO_STATUS[2]="SECONDARY"
MONGO_STATUS[3]="RECOVERING"
MONGO_STATUS[5]="STARTUP2"
MONGO_STATUS[6]="UNKNOWN"
MONGO_STATUS[7]="ARBITER"
MONGO_STATUS[8]="DOWN"
MONGO_STATUS[9]="ROLLBACK"
MONGO_STATUS[10]="REMOVED"

# display verbose is -v specifed
debug_msg() {
    if [ ${VERBOSE} -eq 1 ]
    then
        echo "[*] ${1}"
    fi
}

# check if type is "replicaset"
is_rs() {
    if [ "${TYPE}" != "replicaset" ]
    then
        debug_msg "argument '-t' is not 'replicaset'"
        echo "NOK : argument '-t' has to be 'replicaset' for this check"
        exit ${STATE_UNKNOWN}
    fi
    debug_msg "argument '-t' is 'replicaset'"
}

# check if authentification is specifed
is_auth_given(){
    if [[ ! -z "${USER_MONGO}" && ! -z "${PASSWORD_MONGO}" ]]
    then
        debug_msg "Credentials provided"
        AUTH=1
    else
        debug_msg "Credentials not provided, auth skipped"
    fi
}

# check if a different port is specifed
is_port(){
    if [ ! -z "${PORT_MONGO}" ]
    then
        PORT_MONGO=${PORT_MONGO}
    fi
}

# Resident memory (physical RAM) should be more than 92% used
check_mem_resident() {
    is_auth_given
    is_port
    local LIMIT=92  # Could be set with an argument but 92 seems ok:
    # Assuming that your RAM is smaller than your data size, MongoDB’s resident
    # set size should be a little lower than your total size of RAM (for
    # example, if you have 50 GB of RAM, MongoDB should be using at least
    # 46GB). If it is much lower, then your readahead is probably too high.
    # from "Mongodb the definitive guide", O'Reilly

    mongo_query "db.serverStatus().mem.resident"

    RESIDENT=${CMD_OUTPUT%%.*}
    PHY=$(free -m|grep Mem|awk '{print $2}')
    RESIDENT_USED=$(echo ${RESIDENT} ${PHY}|awk '{print $1 *100 / $2}')
    RESIDENT_USED="${RESIDENT_USED%.*}"

    if [ ${RESIDENT_USED} -lt ${LIMIT} ]
    then
        echo "NOK : Resident memory used : ${RESIDENT_USED}%, readahead probably too high"
	return ${STATE_CRITICAL}
    else
        echo "OK: Resident memory used : ${RESIDENT_USED}%"
	return ${STATE_OK}
    fi
}


# Track replication lag in a replicaset
check_rs_lag() {
    is_rs               # mandatory, rs.status() is specific to replicaset
    is_auth_given
    is_port
    local HOUR=0        # could also be set in arg

    mongo_query "rs.printSlaveReplicationInfo()"
    HOUR=$(echo -ne $CMD_OUTPUT|awk '{print $13}')
    HOUR=${HOUR#(*}

    if [ ${HOUR} -ne 0 ]
    then
        echo "NOK : Lag replication is ${HOUR} hr(s)"
	return ${STATE_CRITICAL}
    else
        echo "OK : Lag replication is ${HOUR} hr(s)"
	return ${STATE_OK}
    fi
}


# count how many member are configured in the replicaset
# For now, we assume 3 is the right value
check_rs_count() {
    is_rs               # mandatory, rs.status() is specific to replicaset
    is_auth_given
    is_port
    local NB_REQUIRED=3 # could be set in arg, but 3 is THE standard value for a replicaset

    mongo_query "rs.status().members"

    MY_STATE=${CMD_OUTPUT}
    NB_MEMBER=$(echo "$MY_STATE"|grep "_id"|wc -l)

    debug_msg "value of rs.count: ${NB_MEMBER}"

    if [ "${NB_MEMBER}" -ne "${NB_REQUIRED}" ]
    then
        echo "NOK : total member should be 3, but is : ${NB_MEMBER}"
	return ${STATE_CRITICAL}
    else
        echo "OK : number of instances should be 3, and is : ${NB_MEMBER}"
	return ${STATE_OK}
    fi

}

# return the state of the node
check_rs_status() {
    is_rs               # mandatory, rs.status() is specific to replicaset
    is_auth_given
    is_port

    mongo_query "rs.status().myState"
    debug_msg "value of myState: ${OUTPUT}"

    MY_STATE=${CMD_OUTPUT}

    if [ ${MY_STATE} -eq 2 ] || [ ${MY_STATE} -eq 1 ] || [ ${MY_STATE} -eq 7 ]
    then
        echo "OK - State is ${MONGO_STATUS[${MY_STATE}]}"
	return ${STATE_OK}
    else
        echo "NOK - State is ${MONGO_STATUS[${MY_STATE}]}"
	return ${STATE_CRITICAL}
    fi
}

# execute a command in mongo shell, pass through an argument
# ${CMD_OUTPUT} is set in the function
mongo_query() {
    local mongo_cmd=$1
    local base_cmd="mongo --host ${HOST} --port ${PORT_MONGO}"
    base_cmd="${base_cmd} --quiet"
    base_cmd="${base_cmd} --authenticationDatabase admin"
    base_cmd="${base_cmd} --eval ""printjson(${mongo_cmd})"" "

    if [ ${AUTH} -eq 1 ]
    then
        debug_msg "Running command with auth: ${base_cmd}"
	base_cmd="${base_cmd} --username ${USER_MONGO} --password ${PASSWORD_MONGO}"
    else
	debug_msg "Running command: ${base_cmd}"
    fi

    CMD_OUTPUT=$(${base_cmd})
    if [ $? -ne 0 ]
    then
	echo "Error running mongo command."
	exit ${STATE_UNKNOWN}
    fi
    debug_msg "result : ${CMD_OUTPUT}"
}

# usage
usage() {
    echo "Usage: $PROGNAME -t [standalone|replicaset] -h [hostname] -c [check_name]"
    echo "Optional :"
    echo "-u [username]"
    echo "-p [password]"
    echo "-w [port]"
    # not implemented yet :)
    #echo "-i [!warning!critical]"
    echo "-v verbose"
    echo
    echo "Any rs.xxx command has to be associated with -t replicaset"
    echo
    echo "check_name :"
    echo "mem.resident  Check resident memory usage (amount of physical memory being used)"
    echo "rs.status     Status of the local node"
    echo "rs.count      Count how many member are in the replicaset"
    echo "rs.lag        Check replication lag"
}

# entrypoint
which mongo > /dev/null
if [ $? -ne 0 ]
then
    echo "mongo binary not found"
    exit ${STATE_UNKNOWN}
fi

while getopts 't:h:u:p:c:vw:' OPTIONS
do
    case ${OPTIONS} in
        t)
            TYPE=${OPTARG}
            ;;
        h)
            HOST=${OPTARG}
            ;;
        u)
            USER_MONGO=${OPTARG}
            ;;
        p)
            PASSWORD_MONGO=${OPTARG}
            ;;
        c)
            CHECK_NAME=${OPTARG}
            ;;
        v)
            VERBOSE=1
            ;;
        w)
            PORT_MONGO=${OPTARG}
            ;;
        *)
            echo "Invalid argument."
            usage
            return 1
            ;;
    esac
done

debug_msg "args: type:${TYPE}, host:${HOST},check_name:${CHECK_NAME},user:${USER_MONGO},password:${PASSWORD_MONGO},port:${PORT_MONGO}"

if [[ -z "${TYPE}" || -z "${HOST}" || -z "${CHECK_NAME}" ]]
then
    echo "HOST, TYPE and CHECK are required"
    usage
    exit $STATE_UNKNOWN
fi


case ${CHECK_NAME} in
    "mem.resident")
        check_mem_resident
        ;;
    "rs.status")
        check_rs_status
        ;;
    "rs.count")
        check_rs_count
        ;;
    "rs.lag")
        check_rs_lag
        ;;
    *)
        echo "Invalid check '${CHECK_NAME}'."
        exit
        ;;
esac

# EOF
