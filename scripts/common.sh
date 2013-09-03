#!/bin/bash

D=$(readlink -f $(dirname $BASH_SOURCE))

source $D/spinner.sh

function realpath() {
    python -c "import os,sys; print os.path.realpath(sys.argv[1])" $1
}

ROOT=`realpath $D/..`
CONF=$ROOT/config
OUT=$ROOT/out
SCRIPTS=$ROOT/scripts
BUILDROOT=$OUT/buildroot
HOST_OVERLAY=$ROOT/overlay/host
TARGET_OVERLAY=$ROOT/overlay/target

CFG=$D/../install.cfg

if [[ -f $CFG ]]; then
    source $CFG
else
    echo "Could not find install.cfg, please see install.cfg.example"
    exit 1
fi

# print message and exit the script
# usage: die <message>
function die () {

    cecho "ERROR: " $red -n 1>&2
    echo "${@}" 1>&2

    if [[ -z $DONTDIE ]]; then
        exit 1
    fi
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
    shift

    local color=${1:-$black}
    shift

    local args=${@}

    echo -ne "$color"
    echo $args "$message"

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

download() {

    local url=$1
    local output=$2

    Q echo Downloading $url to $output
    [[ -e $output ]] && return 0

    start_spinner "Downloading $url..."

    (
        local evalme="echo \$${url}_URL"

        trap "rm $output" EXIT
        Q wget `eval $evalme` -O $output
        trap - EXIT

        stop_spinner $?
    )
}

h1()
{
    echo -n ">>> "
    echo "${*}"
}

h2()
{
    echo -n "... "
    echo "${*}"
}

Qorerr() {

    output=`tempfile --prefix o11spandadev- --suffix .log`
    trap "rm -f $output" EXIT

    if [[ -n $VERBOSE ]] ; then
        ${*}; ret=$?
    else
        ${*} &>$output; ret=$?
    fi

    [[ $ret -ne 0 ]] && { \
        echo -e "\n\n<<<<ERROR:\n";
        cat $output;
        echo -e "\n>>>>\n"; 
    }

    return $ret
}

install_pkg() {
    local pkgname=$1
    local failmsg=$2

    start_spinner "Installing host support package: $pkgname..."

    (
        if [[ -z $FORCE ]]; then
            local option="--trivial-only"
        else
            local option="--assume-yes"
        fi

        Qorerr sudo apt-get install $pkgname $option
        stop_spinner $? $failmsg
    )
}

start_service() {
    local svcname=$1
    start_spinner "Starting $svcname"
    (
        { Qorerr sudo service $svcname restart \
            || stop_spinner $? "Failed to start service: $svcname"; } \
        && stop_spinner 0

    )
}

stop_service() {
    local svcname=$1
    start_spinner "Stopping $svcname"
    (
        { Qorerr sudo service $svcname stop \
            || stop_spinner $? "Failed to start service: $svcname"; } \
        && stop_spinner 0
    )
}

find_usb_dev() {
    local desc=$1
    local dev_line=$(lsusb | grep "$desc")
    if [[ -z $dev_line ]]; then
        die "Expected to find a USB ethernet device matching this description: $desc (found via 'lsusb' tool)."
    fi
    local pattern='Bus \([0-9][0-9]*\) Device \([0-9][0-9]*\):.*$'
    local bus=$(echo $dev_line | sed "s#$pattern#\1#" | sed 's#^00*##')
    local dev=$(echo $dev_line | sed "s#$pattern#\2#" | sed 's#^00*##')
    local devfile=$(
        ls /sys/bus/usb/devices/*/busnum \
            | xargs fgrep -x -l $bus \
            | sed 's#/busnum$#/devnum#' \
            | xargs fgrep -x -l $dev \
            | sed 's#/devnum$##'
        )
    echo $devfile
}

find_usb_serial() {

    local devfile=$(find_usb_dev "$USBSERIAL_DESC")

    if [[ -z $devfile ]]; then
        exit 1
    fi

    local ttyusb=$(ls -d -1 $devfile:*/tty*)
    local count=$(echo $ttyusb | wc -l)

    if [[ $count -gt 1 ]]; then
        die "Expected to find only one usb serial device."
    fi

    echo /dev/`basename $ttyusb`
}

find_asix_eth() {

    local devfile=$(find_usb_dev "$USB_ETH_DESC")

    if [[ -z $devfile ]]; then
        return 1
    fi

    local eth_dev=$(ls -1 $devfile:*/net/)
    local mac_addr=$(cat $devfile:*/net/*/address)
    local count=$(echo $mac_addr | wc -l)

    if [[ $count -gt 1 ]]; then
        die "Expected to find only one usb ethernet device."
    fi

    echo $eth_dev $mac_addr
}

add_config_lines() {

    local src_file=$1
    local dst_file=$2

    local lines_present=$(
        grep --fixed-strings --file=$src_file --line-regexp $dst_file \
            | wc -l
        );

    local lines_needed=$(cat $src_file | wc -l)

    if [[ $lines_present -eq 0 ]] ; then
        sudo sh -c "cat $src_file >>$dst_file"
    elif [[ $lines_present -ne $lines_needed ]] ; then
        die "File '$dst_file' in an unknown state (lines present: $lines_present, lines needed: $lines_needed), bailing..."
    else
        h2 "File '$dst_file' already contains needed entries"
    fi
}

sub_cfg_vars() {
    local inp=$1
    local out=$inp.sub_cfg_vars
    sed \
        -e "s#@DEV_HOST@#${DEV_HOST}#g" \
        -e "s#@MRVL_FIRMWARE@#${MRVL_FIRMWARE}#g" \
        -e "s#@NFS_ROOT@#${NFS_ROOT}#g" \
        -e "s#@TEST_HOME@#${TEST_HOME}#g" \
        -e "s#@DEV_TARGET@#${DEV_TARGET}#g" \
        -e "s#@TFTP_ROOT@#${TFTP_ROOT}#g" \
        -e "s#@GIT_VERSION@#${GIT_VERSION}#g" \
        -e "s#@GIT_URL@#${GIT_URL}#g" \
        -e "s#@TARGET_IP@#${TARGET_IP}#g" \
        -e "s#@SERVER_IP@#${SERVER_IP}#g" \
        -e "s#@USB_ETH@#${USB_ETH}#g" \
        -e "s#@USB_MAC@#${USB_ETH}#g" \
        -e "s#@USB_ETH_DESC@#${USB_ETH_DESC}#g" \
        -e "s#@USBSERIAL_DESC@#${USBSERIAL_DESC}#g" \
        -e "s#@WIRESHARK_VER@#${WIRESHARK_VER}#g" \
        -e "s#@SCAPY_URL@#${SCAPY_URL}#g" \
        -e "s#@SCAPY_VERSION@#${SCAPY_VERSION}#g" \
        -e "s#@BUILDROOT_VER@#${BUILDROOT_VER}#g" \
        -e "s#@BUILDROOT_URL@#${BUILDROOT_URL}#g" \
        -e "s#@USBBOOT_URL@#${USBBOOT_URL}#g" \
        <$inp >$out
    echo $out
}

item_at() {
    if [[ -z "${*}" ]]; then
        return 1
    fi
    awk "{ print \$$1}"
}

ask_for_panda_reset() {
    echo
    echo "*** Please reset the pandaboard then press enter ***"
    echo
    read 
}

whose_on_usbserial() {
    local usb_serial=$1
    sudo lsof $usb_serial 2>/dev/null | tail -n +2 | awk '{print $2}'
}

find_pxe_mac_addr() {

    local usb_serial=$1

    local output_file=`tempfile -s .log -p pxe`
    local pattern="Retrieving file: pxelinux.cfg/"

    if [[ $(whose_on_usbserial $usb_serial | wc -l) -gt 0 ]]; then
        die "Someone is using the usb serial device ($usb_serial)..."
    fi

    touch $output_file

    sudo dd if=$usb_serial bs=1 of=$output_file &
    local pid=$!

    if [[ -n $DISPLAY ]]; then
        xterm -e "tail -f \"$output_file\"" &
        local xterm_pid=$!
    fi

    poll 60 "grep -c '$pattern' $output_file &>/dev/null"

    Q sudo kill $pid
    [[ -n $xterm_pid ]] && Q sudo kill $xterm_pid

    grep --text "$pattern" $output_file \
        | head -1 \
        | sed 's#.*pxelinux.cfg/\(.*\)#\1#'

    Q sudo rm -rf $output_file
}

generate_pxe_config() {

    local pxecfg="$PXE_ROOT/$1"
    local config=$(sub_cfg_vars $CONF/pxelinux.cfg)

    h2 "Generating pxeconfig: $pxecfg"

    Q sudo cp -v "$config" "$pxecfg"
}

is_empty_dir() {
    local dir=$1
    [[ -n $dir ]] || die "is_empty_dir <directory>"
    if [[ ! -e $dir ]]; then
        return 0
    fi
    if [[ ! -d $dir ]]; then
        return 0
    fi
    [[ $(ls -A "$dir" -1 | wc -l) -le 0 ]]
}

Q echo "ROOT: $ROOT"
Q echo "OUT: $OUT"
Q echo "BUILDROOT: $BUILDROOT"
