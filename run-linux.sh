#!/bin/bash

# ==================================================================
# x16-PRos -- The x16-PRos run script for Linux
# Copyright (C) 2025 PRoX2011
# ==================================================================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

print_msg() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

print_msg "$NC" ""
print_msg "$GREEN" "Starting emulator..."
qemu-system-x86_64 \
    -display gtk \
    -fda disk_img/x16pros.img \
    -machine pcspk-audiodev=snd0 \
    -device adlib,audiodev=snd0 \
    -audiodev pa,id=snd0 