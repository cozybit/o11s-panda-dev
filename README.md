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

The following scripts are important:
