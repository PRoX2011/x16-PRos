#!/bin/bash

# ==================================================================
# x16-PRos -- The x16-PRos build script for Linux
# Copyright (C) 2025 PRoX2011
# ==================================================================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

print_info() {
    local message="$1"
    echo -e "${CYAN}[ INFO ]${NC} ${message}"
}

print_ok() {
    local message="$1"
    echo -e "${GREEN}[  OK  ]${NC} ${message}"
}

print_failed() {
    local message="$1"
    echo -e "${RED}[ FAILED ]${NC} ${message}"
    exit 1
}

check_error() {
    if [ $? -ne 0 ]; then
        print_failed "$1"
    fi
}

mkdir -p bin
mkdir -p disk_img

echo -e "$NC"

echo -e "$GREEN========== Starting x16-PRos build... ==========$NC"

echo -e "$NC"

# Compile bootloader
print_info "Compiling bootloader (boot.asm => bin/BOOT.BIN)..."
nasm -f bin src/bootloader/boot.asm -o bin/BOOT.BIN
check_error "Bootloader compilation failed"
print_ok "Bootloader compiled successfully"

# Compile kernel
print_info "Compiling kernel (kernel.asm => bin/KERNEL.BIN)..."
nasm -f bin src/kernel/kernel.asm -o bin/KERNEL.BIN
check_error "Kernel compilation failed"
print_ok "Kernel compiled successfully"

# Create and format disk image
print_info "Creating disk image (disk_img/x16pros.img)..."
dd if=/dev/zero of=disk_img/x16pros.img bs=512 count=2880 conv=notrunc status=none
check_error "Disk image creation failed"
print_ok "Disk image created successfully"

print_info "Formatting disk image..."
mkfs.vfat disk_img/x16pros.img -n "x16-PROS"
check_error "Disk formatting failed"
print_ok "Disk image formatted successfully"

# Write bootloader
print_info "Writing bootloader to disk..."
dd status=none if=bin/BOOT.BIN of=disk_img/x16pros.img conv=notrunc
check_error "Bootloader writing failed"
print_ok "Bootloader written successfully"

# Copy kernel
print_info "Copying kernel to disk (bin/KERNEL.BIN => disk_img/x16pros.img)..."
mcopy -i disk_img/x16pros.img bin/KERNEL.BIN ::/
check_error "Kernel copy failed"
print_ok "Kernel copied successfully"

# Copy config files
print_info "Copying kernelconfig files..."
mcopy -i disk_img/x16pros.img src/kernel/configs/USER.CFG ::/
check_error "USER.CFG copy failed"
print_ok "USER.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/FIRST_B.CFG ::/
check_error "FIRST_B.CFG copy failed"
print_ok "FIRST_B.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/PASSWORD.CFG ::/
check_error "PASSWORD.CFG copy failed"
print_ok "PASSWORD.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/TIMEZONE.CFG ::/
check_error "TIMEZONE.CFG copy failed"
print_ok "TIMEZONE.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/PROMPT.CFG ::/
check_error "PROMPT.CFG copy failed"
print_ok "PROMPT.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/THEME.CFG ::/
check_error "THEME.CFG copy failed"
print_ok "THEME.CFG copied successfully"


echo -e "$NC"

# Create DOCS directory
echo -e "$GREEN========== Creating DOCS directory... ==========$NC"
print_info "Creating DOCS directory..."
mmd -i disk_img/x16pros.img ::/DOCS.DIR
check_error "Failed to create DOCS directory"
print_ok "DOCS directory created successfully"

echo -e "$NC"

# Compile and copy programs
echo -e "$GREEN========== Compiling and copying programs... ==========$NC"

# Define programs as an array of tuples: source, output_name
programs=(
    "programs/autoexec.asm AUTOEXEC.BIN"
    "programs/setup/setup.asm SETUP.BIN"
    "programs/fetch.asm FETCH.BIN"
    "programs/credits.asm CREDITS.BIN"
    "programs/hello.asm HELLO.BIN"
    "programs/write.asm WRITER.BIN"
    "programs/barchart.asm BCHART.BIN"
    "programs/brainf.asm BRAINF.BIN"
    "programs/calc.asm CALC.BIN"
    "programs/memory.asm MEMORY.BIN"
    "programs/mine.asm MINE.BIN"
    "programs/piano.asm PIANO.BIN"
    "programs/snake.asm SNAKE.BIN"
    "programs/space.asm SPACE.BIN"
    "programs/procentc.asm PROCENTC.BIN"
    "programs/paint.asm PAINT.BIN"
    "programs/pong.asm PONG.BIN"
    "programs/hexedit.asm HEXEDIT.BIN"
    "programs/clock.asm CLOCK.BIN"
    "programs/imfplay.asm IMFPLAY.BIN"
    "programs/fnt_test.asm FNT_TEST.BIN"
)

for prog in "${programs[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    bin_name=$(echo $prog | cut -d' ' -f2)
    
    print_info "Compiling $src => bin/$bin_name..."
    nasm -f bin $src -o bin/$bin_name
    check_error "Compilation of $src failed"
    print_ok "$bin_name compiled successfully"
    
    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done

echo -e "$NC"

# Copy text files
echo -e "$GREEN========== Copying text files... ==========$NC"
text_files=(
    "LICENSE.TXT"
    "src/txt/ABOUT.TXT"
)

for file in "${text_files[@]}"; do
    print_info "Copying $file..."
    mcopy -i disk_img/x16pros.img $file ::/
    check_error "Copy of $file failed"
    print_ok "$file copied successfully"
done

text_files_doc=(
    "src/txt/FILESYS.TXT"
    "src/txt/PROGPACK.TXT"
    "src/txt/CONFIGS.TXT"
)


for file in "${text_files_doc[@]}"; do
    print_info "Copying $file..."
    mcopy -i disk_img/x16pros.img $file ::/DOCS.DIR/
    check_error "Copy of $file failed"
    print_ok "$file copied successfully"
done

# Copy image files
echo -e "$GREEN========== Copying image files... ==========$NC"
image_files=(
    "src/images/logo/LOGO.BMP"
    "src/images/PROX.BMP"
    "src/images/PROS.BMP"
    "src/images/TRAIN.BMP"
)

for file in "${image_files[@]}"; do
    print_info "Copying $file..."
    mcopy -i disk_img/x16pros.img $file ::/
    check_error "Copy of $file failed"
    print_ok "$file copied successfully"
done

# Copy music files
echo -e "$GREEN========== Copying music files... ==========$NC"
music_files=(
    "src/IMF/RICK.IMF"
    "src/IMF/SONIC.IMF"
    "src/IMF/HOPES&D.IMF"
    "src/IMF/RUSSIA.IMF"
    "src/IMF/METRO_E.IMF"
    "src/IMF/METRO_E2.IMF"
    "src/IMF/GTA_VC.IMF"
)

for file in "${music_files[@]}"; do
    print_info "Copying $file..."
    mcopy -i disk_img/x16pros.img $file ::/
    check_error "Copy of $file failed"
    print_ok "$file copied successfully"
done

echo -e "$NC"

# Display disk contents
echo -e "$YELLOW Disk contents:$NC"
mdir -i disk_img/x16pros.img ::/

# Create ISO
rm -f disk_img/x16pros.iso
print_info "Creating ISO image (disk_img/x16pros.iso)..."
mkisofs -quiet -V 'x16-PROS' -input-charset iso8859-1 -o disk_img/x16pros.iso -b x16pros.img disk_img/
check_error "ISO creation failed"
print_ok "ISO image created successfully"


echo -e "$NC"
echo -e "$GREEN========== Build completed successfully! ==========$NC"
