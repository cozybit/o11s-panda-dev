#!/bin/bash

[[ -z $DEBUG ]] || set -x
source `dirname $0`/scripts/common.sh

usage() {
cat << EOF
usage: $0 [<OPTIONS>]

Installs and sets up buildroot for developing o11s with a pandaboard.

OPTIONS:
   -c         Make a clean build.
   -C         Clean the target rootfs (THIS IS DANGEROUS)
   -v         Be verbose.
   -f         Force override of package installation and configuration files
              on the host machine.
   -d=<X,...> Disable certain install steps:
               - nodownload: don't download anything
               - noextract: don't extract anything
               - nopackages: don't install support packages
               - noconfig: don't generate configs
               - nobuildroot: don't build buildroot
               - noboot: don't boot the pandaboard
               - noattach: don't attach an xterm to console of the pandaboard
   -h         Show this message.
EOF
}

# parse the incoming parameters
while getopts "ckChvfd:" options; do
    case $options in
	c ) CLEAN=1;;
	C ) CLEAN_TARGET=1;;
    v ) VERBOSE=1;;
    f ) FORCE=1;;
    h ) usage; exit 0;;
    d ) DISABLE=${OPTARG};;
    * ) echo unkown option: ${option}
        usage
        exit 1;;
    esac
done

UNDER_INSTALL_SH=1

h1 "Requesting root... "
sudo echo "...got root."

_pushd vendor

if [[ ! $DISABLE =~ nodownload ]]; then

    download BUILDROOT buildroot.tbz2
    download USBBOOT usbboot.deb

fi

if [[ ! $DISABLE =~ noextract ]]; then

    start_spinner "Extracting buildroot ($BUILDROOT)..."

    [[ -z $CLEAN ]] || Q rm -rvf $BUILDROOT || stop_spinner "cleaning buildroot failed"

    if is_empty_dir $BUILDROOT; then
        Q mkdir -vp $BUILDROOT
        Q tar -xvj -f buildroot.tbz2 \
            --directory=$BUILDROOT \
            --strip-components=1 || stop_spinner 1
    else
        echo "Buildroot dir was not empty"
    fi

    stop_spinner 0

    T=$OUT/usbboot
    start_spinner "Extracting usbboot ($T)..."

    [[ -z $CLEAN ]] || Q rm -rvf $T || die "cleaning usbboot failed"

    if is_empty_dir $T; then
        Q mkdir -vp $T
        Q dpkg -x usbboot.deb $T || stop_spinner 1
    else
        echo "Usbboot dir was not empty"
    fi

    stop_spinner 0
fi

_popd

_pushd $BUILDROOT

h1 "Patching buildroot..."
Q $ROOT/scripts/patch_buildroot || die "Failed to patch buildroot"

if [[ -n $CLEAN ]]; then
    start_spinner "Cleaning buildroot..."
    Q rm -vrf dl/* || stop_spinner $?
    Q find output/build -name ".stamp_downloaded" | xargs rm -vf \
        || stop_spinner $?
    stop_spinner 0
fi

if [[ ! $DISABLE =~ nodownload ]]; then
    start_spinner "Downloading buildroot packages (takes a long time)..."
    Qorerr make source 
    stop_spinner $?
fi

_popd

if [[ ! $DISABLE =~ nopackages ]]; then

    h1 "Installing required host packages..."

    force_msg="(Use -f force override of existing packages)"

    install_pkg screen "Failed to install screen! $force_msg" || exit 1
    install_pkg udhcpd "Failed to install DHCP server: udhcpd! $force_msg" || exit 1
    install_pkg nfs-kernel-server "Failed to install NFS server! $force_msg" || exit 1
    install_pkg atftpd "Failed to install TFTP server: atftpd! $force_msg" || exit 1
    install_pkg xinetd "Failed to install inet server: xinetd! $force_msg" || exit 1
    install_pkg linaro-boot-utils "Failed to install linaro-boot-utils (for usbboot)" || exit 1

fi

if [[ ! $DISABLE =~ noconfig ]]; then

    h1 "Setting up TFTP/NFS directory..."

    sudo mkdir -p $NFS_ROOT
    sudo mkdir -p $DEV_TARGET
    sudo mkdir -p $TFTP_ROOT

    h1 "Installing host config files..."
    USB_ETH=$(find_asix_eth | item_at 1) 
    [[ -n $USB_ETH ]] || exit 1

    nfs_exports=$(sub_cfg_vars $HOST_OVERLAY/nfs_exports)
    udhcpd_conf=$(sub_cfg_vars $HOST_OVERLAY/udhcpd.conf)
    inetd_conf=$(sub_cfg_vars $HOST_OVERLAY/inetd.conf)

    add_config_lines $nfs_exports /etc/exports
    add_config_lines $udhcpd_conf /etc/udhcpd.conf
    add_config_lines $inetd_conf /etc/inetd.conf

    sudo mkdir -p $PXE_ROOT

    usb_serial=$(find_usb_serial)
    [[ -n $usb_serial ]] || exit 1

    $SCRIPTS/boot_pandaboard || exit 1

    h1 "Configuring usb interface for DHCP..."
    Qorerr sudo ifconfig $USB_ETH $SERVER_IP
    start_service udhcpd

    h1 "Trying to figure out MAC addr for PXE (reading from $usb_serial)"
    pxelin=$(find_pxe_mac_addr $usb_serial)
    [[ -n $pxelin ]] || exit 1

    h2 "Discovered PXE mac addr: $pxelin"
    generate_pxe_config $pxelin

fi

if [[ ! $DISABLE =~ nobuildroot ]]; then

    VERBOSE=$VERBOSE $SCRIPTS/build_buildroot

fi

if [[ ! $DISABLE =~ noboot ]]; then

    h1 "Booting the pandaboard..."

    h2 "Starting required services..."

    start_service nfs-kernel-server
    start_service xinetd

    $SCRIPTS/boot_pandaboard || exit 1
fi

if [[ ! $DISABLE =~ noattach ]]; then
    if [[ -n $DISPLAY ]]; then
        xterm -e "$SCRIPTS/attach_console" &
    fi
fi

echo
echo "PandaBoard dev environment should now be availabe..."
echo
echo "- Console : screen -rd ${SCREEN_NAME}"
echo "- SSH     : ssh test@${TARGET_IP}"
echo "- NFS     : ${NFS_ROOT}"
echo "- Kernel  : ${TFTP_ROOT}/uImage"
echo "- Modules : $(echo ${NFS_ROOT}/lib/modules/*/)"
echo
echo "Also see: scripts/attach_console"
