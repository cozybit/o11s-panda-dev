#!/bin/sh

LOG=/tmp/hotplug.log
echo "$@"  >$LOG
set       >>$LOG

FIRMWARE_DIR=/lib/firmware

if [ "$1" != "firmware" ]; then
    exit 0;
fi

if [ -f $FIRMWARE_DIR/$FIRMWARE ]; then
     echo 1 > $SYSFS/$DEVPATH/loading
     cp $FIRMWARE_DIR/$FIRMWARE $SYSFS/$DEVPATH/data
     echo 0 > $SYSFS/$DEVPATH/loading
 else
     echo -1 > $SYSFS/$DEVPATH/loading
fi
