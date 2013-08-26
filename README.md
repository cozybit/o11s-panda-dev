# Open 802.11s PandaBoard Development Target

## Overview

This is an environment to allow develops to utilize a PandaBoard as a
development target for 80211s.

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
   killed (with CTRL-A K)-- this will prevent the install.sh from succeeded
   since it requires access to the console**.

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

