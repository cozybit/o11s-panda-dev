#!/bin/sh

T=output/build/busybox-1.21.0/.config
cp busybox.config $T && make busybox-menuconfig && cp $T busybox.config
