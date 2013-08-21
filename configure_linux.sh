#!/bin/sh

T=output/build/linux-ft-sd8787-driver/.config
cp linux.config $T && make linux-menuconfig && cp $T linux.config
