#!/bin/bash

source `dirname $0`/scripts/common.sh

download() {
    url=$1
    output=$2
    [ -e $output ] && return 0
    start_spinner "Downloading $url..."
    Q wget `cat $url.url` -O $output
    stop_spinner $?
}

usage() {
cat << EOF
usage: $0 [<OPTIONS>]

Installs and sets up buildroot for developing o11s with a pandaboard.

OPTIONS:
   -c   Make a clean build.
   -v   Be verbose.
   -h   Show this message.
EOF
}

Qorerr() {
    [[ -n $VERBOSE ]] && ${*} || err=`${*} 2>&1`; ret=$?
    [[ $ret -ne 0 ]] && echo $err
    return $ret
}

# parse the incoming parameters
while getopts "chv" options; do
    case $options in
	c ) CLEAN=1;;
    v ) VERBOSE=1;;
    h ) usage exit 0;;
    * ) echo unkown option: ${option}
        usage
        exit 1;;
    esac
done

_pushd vendor

download buildroot buildroot.tbz2
download usbboot usbboot.deb

start_spinner "Extracting buildroot..."

[[ -z $CLEAN ]] || Q rm -rvf $BUILDROOT || die "cleaning buildroot failed"

Q mkdir -vp $BUILDROOT

[[ -d $BUILDROOT ]] || \
    Q tar -xj -f buildroot.tbz2 \
        --directory=$BUILDROOT \
        --strip-components=1 || stop_spinner 1

stop_spinner 0

start_spinner "Extracting usbboot..."

T=$OUT/usbboot
[[ -z $CLEAN ]] || Q rm -rvf $T || die "cleaning usbboot failed"

Q mkdir -vp $T

[[ -d $T ]] || \
    Q dpkg -x usbboot.deb $T || stop_spinner 1

stop_spinner 0

_popd

_pushd $BUILDROOT

start_spinner "Patching buildroot..."

Q $ROOT/scripts/patch_busybox

stop_spinner 0

if [[ -n $CLEAN ]]; then

    start_spinner "Cleaning buildroot..."

    Q rm -vrf dl/* || stop_spinner $?
    Q find output/build -name ".stamp_downloaded" | xargs rm -vf \
        || stop_spinner $?

    stop_spinner 0
fi

start_spinner "Downloading buildroot packages..."
Qorerr make source
stop_spinner $?

_popd
