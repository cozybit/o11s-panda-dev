#!/bin/bash

D=$(readlink -f $(dirname $BASH_SOURCE))
source $D/spinner.sh

# print message and exit the script
# usage: die <message>
function die () {
    cecho "${*}" $red
    exit -1
}

# perform a command quietly unless debugging is enabled.i
# usage: Q <anything>
function Q () {
        if [ "${VERBOSE}" == "1" ]; then
                "$@"
        else
                "$@" &> /dev/null
        fi
}

black='\E[1;30m'
red='\E[1;31m'
green='\E[1;32m'
yellow='\E[1;33m'
blue='\E[1;34m'
magenta='\E[1;35m'
cyan='\E[1;36m'
white='\E[1;37m'

function cecho ()            # Color-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
    local default_msg="No message passed."

    local message=${1:-$default_msg}
    local color=${2:-$black}

    echo -ne "$color"
    echo "$message"

    tput sgr0
}

function _pushd() {
    pushd $@ 2>&1 >/dev/null
}

function _popd() {
    popd $@ 2>&1 >/dev/null
}

function echo_eval() {
    echo "Running: $@"
    "$@"
}

function realpath() {
    python -c "import os,sys; print os.path.realpath(sys.argv[1])" $1
}

# Provide output facility gated by VERBOSE option
function log {
	[ "$VERBOSE" == "y" ] && echo "`date`: `logger -st ${TEST_NAME} -- $* 2>&1`"
}

# repeat command until it either returns success, or timeout is reached.
# The total execution time in seconds is echoed in either case. Return success
# if command did not time out.
# poll <timeout> <cmd>
poll () {

	_TIMEOUT=${1}
	shift 1
	_CMD=${*}
	_poll ${_TIMEOUT} 0 "${_CMD}"

}

# like poll(), only we check for the false case
poll_false () {

        _TIMEOUT=${1}
        shift 1
        _CMD=${*}
        _poll ${_TIMEOUT} 1 "${_CMD}"

}

_poll () {
	_TIMEOUT=$1
	_EC=$2
	_CMD=${3}
	TIMEFORMAT=%R # have 'time' just print seconds
	_START_TIME=`date +%s.%N`
	_EXE_TIME=$( (time while true; do
			Q eval "${_CMD}"; [ "$?" == "${_EC}" ] && break
			_NOW=`date +%s.%N`
			echo "${_NOW} ${_START_TIME} ${_TIMEOUT}" | \
				awk '{exit $1 > ($2 + $3)}' || break
		done) 3>&2 2>&1 1>&3 )

	echo "${_EXE_TIME} ${_TIMEOUT}" | awk '{exit $1 > $2}' || _TIMED_OUT="y"
	_MSG="finished"
	if [ "${_TIMED_OUT}" == "y" ]; then
		_MSG="timed out"
	fi
	log "${_CMD} ${_MSG} in ${_EXE_TIME}s"
	[ "${_TIMED_OUT}" != "y" ]
}

ROOT=`realpath $D/..`
CONF=$ROOT/config
OUT=$ROOT/out
BUILDROOT=$OUT/buildroot

Q echo "ROOT: $ROOT"
Q echo "OUT: $OUT"
Q echo "BUILDROOT: $BUILDROOT"
