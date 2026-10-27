#!/bin/bash

# ==================================================================
# x16-PRos -- The x16-PRos DOSbox run script for Linux
# Copyright (C) 2025 PRoX2011
# ==================================================================

HDD_CYLS=$(( $(stat -c%s /home/prox/x16-PRos/disk_img/HDD.img) / (512 * 63 * 16) ))

dosbox -c "mount d /home/prox/x16-PRos/disk_img" \
       -c "imgmount 0 d:\x16pros.img -t floppy -fs none" \
       -c "imgmount 1 d:\FLOPPY2.img -t floppy -fs none" \
       -c "imgmount 2 d:\HDD.img -t hdd -fs none -size 512,63,16,$HDD_CYLS" \
       -c "boot -l a"