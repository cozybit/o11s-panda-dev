# Open 802.11s PandaBoard Development Target

## Overview

This is an environment to allow develops to utilize a PandaBoard as a
development target for 80211s.

It is useful to use a pandaboard for kernel (or wifi driver) development, since
it gives you an sdio slot, 2 usb ports, a serial console, and the ability to
load a kernel and rootfs over the network. Also, if you hit a kernel panic, a
reboot is quick and painless.

### Prerequisites ###

The following hardware is required:
  - PandaBoard ES REV B1
  - USB hub
  - USB Ethernet adapter (ASIX Electronics Corp. AX88772)
  - USB serial adapter (Prolific Technology, Inc. PL2303 Serial Port)
  - USB wifi monitor device the ath9k\_htc
  - Mini-usb cable (for connecting to PandaBoard USB OTG port)
  
Environment configuration diagram:
```
 +----------+           +-------------+
 | USB HUB  >----+      |   LAPTOP    |
 +--+-------+    |      |             |
    |   ^ ^ ^    +------>USB          |
    |   | | |           +-------------+
    |   | | |
    |   | | |           +-------------+
    |   | | |           |  PANDABOARD |
    v   | | |           |             |
  +---+ | | +-----------<SERIAL    USB>-->ATH_9K_HTC
  | P | | +-------------<USB-MINI     |
  | W | +---------------<ETHERNET     |
  | R |<----------------<5V           |
  +---+                 +-------------+
```

## Automatic Install and Setup

Currently the `install.sh` script is the primary entry point to perform the
following tasks:

  - Download buildroot, scapy (with mesh support), usbboot and the open80211s
    kernel

  - Patch buildroot to download open80211s and install required packages to run
    the o11s tests (scapy, bash, etc).

  - Install required support package for the host system (udhcpd, nfs, atftpd,
    xinetd, usbboot).

  - Generate configs required to network boot the pandaboard:
    - NFS : `/etc/exports`
    - DHCP: `/etc/udhcpd.conf`
    - TFTP: `/etc/inetd.conf`
    - PXE : `<TFTP_ROOT>/pxelinux.cfg/<MAC_ADDR>`

  - Build the buildroot and populate the root filesystem

  - Start services required for a network boot

  - Boot the panda board

The configure how this process happens, there are two entry points:

  - The config file install.cfg (with is just a bash script), which will allow
    you to configure things like:

    - `DEV_HOST`: The development directory to mount within the pandaboard from
      the host computer.

    - `MRVL_FIRMWARE`: The Marvell firmware to install in the target.

  - The command line options for the `install.sh` script:
    ```
    usage: ./install.sh [<OPTIONS>]

    Installs and sets up buildroot for developing o11s with a pandaboard.

    OPTIONS:
    -c         Make a clean build.
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
    -h         Show this message.
    ```

The following scripts are important (in the `scripts` folder):

 - `conf_buildroot`: configures the buildroot, which, in particular, allows
      for additional package selection on the target.

 - `conf_linux`: configures linux for buildroot

 - `conf_uclibc`: configures the uclibc for buildroot

 - `conf_busybox`: configures BusyBox for the buildroot environment.
    BusyBox implements almost everything needed for a minimal Linux system
    (i.e. init system, shell, userlands utils).  The exception being that
    certain "full blown" utilities needed to be installed to enable the o11s
    sd8787 tests to be run, like: bash, udev, and other userland utils.

 - `patch_buildroot`: pushes the configuration scripts into the buildroot
   (built with the above commands).

 - `build_buildroot`: builds the buildroot and pushes the generate kernel
   image and root filesystem to TFTP and NFS, respectively.

 - `boot_pandaboard`: Uses usbboot to boot the pandaboard, use this script
   to quickly reboot the pandboard.

 - `attach_console`: Allows the user to attach the pandaboards main console
   (usually on /dev/ttyUSB0)-- uses screen to attach to the console.
   **WARNING: this leaves screen running on /dev/ttyUSB0 unless screen is
   killed (with CTRL-A K)-- this will prevent the install.sh from succeeding
   (again) since it requires access to the serial console**.

After logging in the `dev` directory should point at whatever development
directory it was pointed at (which is `~/dev/sd8787-test` by default).

``` sh
Welcome to Buildroot
192.168.99.2 login: test
Password: 
[test@192 ~]$ ls
dev/
[test@192 ~]$ ls dev
2-1-test_drv_load*   genetlink.py      test_fw_bcn*       test_tx_feedback*
```

# Manual Setup

This section describs how to set up the PandaBoard development environment
manually... this is (hopefully) the hard way to setup the PandaBoard
development environment.

## Prerequisites

msgfmt & makeinfo:
`sudo apt-get install gettext build-essential texinfo`

## Buildroot
Download buildroot: http://buildroot.uclibc.org/downloads/buildroot-2013.05.tar.bz2

- Put [this buildroot config](config/buildroot.config) in `$buildroot/.config`
- Put [this kernel config](config/linux.config) in `$buildroot/linux.config`
- Put [this uclib config](config/uclibc.config) in `$buildroot/uclibc.config`
- Put [this busybox config](config/busybox.config) in `$buildroot/busybox.config`

**NOTE**: In all of the above files you'll need to manually replace any
@SUBSTITUTION@ variables.

### Patch buildroot for Scapy

- Add a new scapy config at [package/python-scapy/Config.in](config/scapy_Config.in).

- Add a makefile for scapy at [package/python-scapy/python.scapy.mk](config/python-scapy.mk).

- Add the following line to `package/Config.in` in `$buildroot`:
```
source "package/python-scapy/Config.in"
```

## Buildroot (continued)

The `$buildroot/gen_rootfs` (located in
[o11s-panda-dev/scripts/gen_rootfs](scripts/gen_rootfs), otherwise, it looks
something like this:

``` sh
#!/bin/bash
mkdir -p /srv/nfs/pandaroot
sudo tar -C /srv/nfs/pandaroot/ -xf output/images/rootfs.tar
```

Then, build buildroot, i.e. run `make`.

### Using a custom kernel

In general, you must use a custom kernel to boot the pandaboard. By default the
buildroot config that is used will checkout linux from our open80211s branch
that works on the pandaboard.

To replace the default pandaboard kernel with a branch you're working on, you
can take these manual steps:

``` bash
rm -rf output/build/linux-<branchname>
git clone git@github.com:cozybit/open80211s.git --reference ~/dev/distro11s/src/kernel/ output/build/linux-<branchname>/
touch output/build/linux-<branchname>/.stamp_downloaded
touch output/build/linux-<branchname>/.stamp_extracted
sudo mkdir /srv/tftp
```

**NOTE:** This directory will be blown away on a global `make clean`!  Unless you've changed buildroot to use a custom git tree for the kernel (make menuconfig at the root of buildroot).

### Make buildroot use a custom git tree for the kernel

In the $buildroot/.config the follow variables control where build looks for a
kernel using git:

``` config
BR2_LINUX_KERNEL_CUSTOM_GIT=y
BR2_LINUX_KERNEL_CUSTOM_GIT_REPO_URL="@GIT_URL@"
BR2_LINUX_KERNEL_CUSTOM_GIT_VERSION="@GIT_VERSION@"
BR2_LINUX_KERNEL_VERSION="@GIT_VERSION@"
BR2_LINUX_KERNEL_PATCH=""
```

### Configure the kernel

To configure the kernel:
``` bash
cd <output/build/linux-my-linux-branch>
cp ../../../linux.config .config
ARCH=arm make menuconfig
## Make changes to .config
```

**NOTE**: The **ARCH=arm** prefixing the above "make menuconfig" command is VERY IMPORTANT, without it your .config will look completely different and will not work (because the config generated is for X86 by default).

### Building the kernel

A build_kernel script:

``` bash
#!/bin/bash
rm output/build/linux-*/.stamp_{configured,built,images_installed,target_installed}
make linux
sudo cp output/images/uImage /srv/tftp
```

## USB Boot for the PandaBoard

``` bash
git clone git://git.linaro.org/people/fboudra/linaro-boot-utils.git
cd linaro-boot-utils
make
sudo make install
cd ~/tmp
wget 'https://code.launchpad.net/~linaro-maintainers/+archive/staging-overlay/+files/u-boot-linaro-omap4-panda-splusb_2012.08.2%2B6697%2B48%2B201211212230%7Eprecise1_armhf.deb'
dpkg -x u-boot-linaro-omap4-panda-splusb_2012.08.2+6697+48+201211212230~precise1_armhf.deb uboot
cd uboot/usr/lib/u-boot/omap4_panda_splusb
sudo usbboot MLO u-boot.bin
```

Then hit the reset button on your pandaboard.

## DHCP (udhcpd), NFS root, and TFTP (atftpd)

Install the appropriate servers:
```
apt-get install nfs-kernel-server atftpd udhcpd xinetd
```

Configure NFS `/etc/exports` (nfsroot):
```
/srv/nfs/pandaroot  *(rw,no_root_squash,no_all_squash,no_subtree_check,sync)
```

Configure TFTP through /etc/inetd.conf (on Ubuntu xinetd will read this to be
backwards compatible with inetd):
```
tftp		dgram	udp	wait	nobody	/usr/sbin/in.tftpd -s /srv/tftp/
```

Here is a working dhcp config found in /etc/udhcpd.conf, notice the subnet
being used is `192.168.2.0/24`:
```
start		192.168.2.152	#default: 192.168.0.20
end		192.168.2.163	#default: 192.168.0.254
interface	eth1		#default: eth0
siaddr		192.168.2.151		#default: 0.0.0.0
boot_file	pxelinux.0		#default: (none)
option	subnet	255.255.255.0
option	domain	local
option	lease	864000		# 10 days of seconds
```

The start and end are the range. I changed interface to eth1 so it wouldn't
interfere with any routing.  The `siaddr` is the address of the tftp server
(the computer's eth1). The `boot_file` needs to be pxelinux.0. Everything else
is the defaults already in udhcpd.conf after installing it.

## PXE setup

At this point running `sudo screen /dev/ttyUSB0 115200` or `minicom -s USB0`
(might not be 0) and in another window `sudo usbboot MLO u-boot.bin`(your must
be in the correct folder for the usbboot command).

This should get to a point where it says it's looking in the folder
`pxelinux.cfg/...`, e.g:

```
scanning bus for devices... 3 USB Device(s) found
       scanning bus for storage devices... 0 Storage Device(s) found
       scanning bus for ethernet devices... 1 Ethernet Device(s) found
Waiting for Ethernet connection... done.
BOOTP broadcast 1
DHCP client bound to address 192.168.99.2
missing environment variable: pxeuuid
missing environment variable: ethaddr
Retrieving file: pxelinux.cfg/01-0e-60-eb-a6-46-01  # *** <<< THIS IS THE LINE ***
Waiting for Ethernet connection... done.
```

Copy the mac address and make a folder:

```bash
# mkdir -p /srv/tftp/pxelinux.cfg
```

...then `touch /srv/tftp/pxelinux.cfg/<mac address>` and edit to look like this:

```
timeout 60
label single
  kernel uImage
  append elevator=noop vram=12M root=/dev/nfs rw nfsroot=192.168.2.151:/srv/nfs/pandaroot rootdelay=2 ip=dhcp fixrtc console=ttyO2,115200n8 kernel.sysrq=1
```

## References

- http://delog.wordpress.com/2011/09/04/custom-embedded-linux-system-for-pandaboard-with-buildroot/
- http://elinux.org/PandaBoard
- http://pandaboard.org/content/usb-downloader-and-usb-second-stage-bootloader-omap4
