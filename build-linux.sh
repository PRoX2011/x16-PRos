#!/bin/bash

# ==================================================================
# x16-PRos -- The x16-PRos build script for Linux
# Copyright (C) 2025 PRoX2011
# ==================================================================

FLAG_QUIET_MODE=0
FLAG_NO_MUSIC=0
FLAG_NO_TXT=0
FLAG_NO_BOOT_RECOMP=0
FLAG_NO_KERNEL_RECOMP=0

for arg in $@; do
    if [ $arg == "-quiet" ]; then FLAG_QUIET_MODE=1; continue; fi
    if [ $arg == "-no-music" ]; then FLAG_NO_MUSIC=1; continue; fi
    if [ $arg == "-no-txt" ]; then FLAG_NO_TXT=1; continue; fi
    if [ $arg == "-no-boot-recomp" ]; then FLAG_NO_BOOT_RECOMP=1; continue; fi
    if [ $arg == "-no-kernel-recomp" ]; then FLAG_NO_KERNEL_RECOMP=1; continue; fi
done

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

print_info() {
    local message="$1"
    if [ $FLAG_QUIET_MODE == 0 ]; then
        echo -e "${CYAN}[ INFO ]${NC} ${message}";
    fi
}

print_ok() {
    local message="$1"
    if [ $FLAG_QUIET_MODE == 0 ]; then
        echo -e "${GREEN}[  OK  ]${NC} ${message}"
    fi
}

print_failed() {
    local message="$1"
    if [ $FLAG_QUIET_MODE == 0 ]; then
        echo -e "${RED}[ FAILED ]${NC} ${message}"
    fi
    exit 1
}

print_splitline() {
    local message="$1"
    if [ $FLAG_QUIET_MODE == 0 ]; then
        echo -e "$NC"
        echo -e "$GREEN========== $message ==========$NC"
    fi
}

check_error() {
    if [ $? -ne 0 ]; then
        print_failed "$1"
    fi
}

mkdir -p bin
mkdir -p disk_img
mkdir -p compcash
mkdir -p compcash/root
mkdir -p compcash/com

print_splitline "Starting x16-PRos build..."

echo -e "$NC"

# Compile bootloader
if [ $FLAG_NO_BOOT_RECOMP == 0 ]; then
    print_info "Compiling bootloader (boot.asm => bin/BOOT.BIN)..."
    nasm -f bin src/bootloader/boot.asm -o bin/BOOT.BIN
    check_error "Bootloader compilation failed"
    print_ok "Bootloader compiled successfully"
fi

# Compile kernel
if [ $FLAG_NO_KERNEL_RECOMP == 0 ]; then
    print_info "Compiling kernel (kernel.asm => bin/KERNEL.BIN)..."
    nasm -f bin src/kernel/kernel.asm -o bin/KERNEL.BIN
    check_error "Kernel compilation failed"
    print_ok "Kernel compiled successfully"
fi

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

# Create BIN directory
print_splitline "Creating BIN directory..."
print_info "Creating BIN directory..."
mmd -i disk_img/x16pros.img ::/BIN.DIR
check_error "Failed to create BIN directory"
print_ok "BIN directory created successfully"

# Create COM directory
print_splitline "Creating COM directory..."
print_info "Creating COM directory..."
mmd -i disk_img/x16pros.img ::/COM.DIR
check_error "Failed to create COM directory"
print_ok "COM directory created successfully"

# Create BMP directory
print_splitline "Creating BMP directory..."
print_info "Creating BMP directory..."
mmd -i disk_img/x16pros.img ::/BMP.DIR
check_error "Failed to create BMP directory"
print_ok "BMP directory created successfully"

# Create CONF directory
print_splitline "Creating CONF directory..."
print_info "Creating CONF directory..."
mmd -i disk_img/x16pros.img ::/CONF.DIR
check_error "Failed to create CONF directory"
print_ok "CONF directory created successfully"

# Create DOCS directory
print_splitline "Creating DOCS directory..."
print_info "Creating DOCS directory..."
mmd -i disk_img/x16pros.img ::/DOCS.DIR
check_error "Failed to create DOCS directory"
print_ok "DOCS directory created successfully"

# Create MUSIC directory
print_splitline "Creating MUSIC directory..."
print_info "Creating MUSIC directory..."
mmd -i disk_img/x16pros.img ::/MUSIC.DIR
check_error "Failed to create MUSIC directory"
print_ok "MUSIC directory created successfully"

echo -e "$NC"

# Copy config files
print_info "Copying kernelconfig files..."
mcopy -i disk_img/x16pros.img src/kernel/configs/USER.CFG ::/CONF.DIR/
check_error "USER.CFG copy failed"
print_ok "USER.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/FIRST_B.CFG ::/CONF.DIR/
check_error "FIRST_B.CFG copy failed"
print_ok "FIRST_B.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/PASSWORD.CFG ::/CONF.DIR/
check_error "PASSWORD.CFG copy failed"
print_ok "PASSWORD.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/TIMEZONE.CFG ::/CONF.DIR/
check_error "TIMEZONE.CFG copy failed"
print_ok "TIMEZONE.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/PROMPT.CFG ::/CONF.DIR/
check_error "PROMPT.CFG copy failed"
print_ok "PROMPT.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/THEME.CFG ::/CONF.DIR/
check_error "THEME.CFG copy failed"
print_ok "THEME.CFG copied successfully"
mcopy -i disk_img/x16pros.img src/kernel/configs/SYSTEM.CFG ::/
check_error "SYSTEM.CFG copy failed"
print_ok "SYSTEM.CFG copied successfully"

# Compile and copy programs
print_splitline "Compiling and copying programs..."

# Define programs as an array of tuples: source, output_name
programs_root=(
    "programs/autoexec.asm AUTOEXEC.BIN"
    "programs/setup/setup.asm SETUP.BIN"
)

for prog in "${programs_root[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    bin_name=$(echo $prog | cut -d' ' -f2)
    cash_file=compcash/root/$(basename $src .asm).cash

    if ! cmp -s $cash_file $src; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
        
        print_info "Cashing $bin_name..."
        cp $src $cash_file
        check_error "Cashing of $bin_name failed"
        print_ok "$bin_name cashed successfully"
    fi
    
    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done

programs=(
    "programs/help.asm HELP.BIN"
    "programs/grep.asm GREP.BIN"
    "programs/theme.asm THEME.BIN"
    "programs/fetch.asm FETCH.BIN"
    "programs/imfplay.asm IMFPLAY.BIN"
    "programs/wavplay.asm WAVPLAY.BIN"
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
    "programs/mandel.asm MANDEL.BIN"
    "programs/tetris.asm TETRIS.BIN"
    "programs/chars.asm CHARS.BIN"
    "programs/eye.asm EYE.BIN"
    "programs/ed.asm ED.BIN programs/ed-comands.asm programs/ed-common.asm"
)

for prog in "${programs[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    bin_name=$(echo $prog | cut -d' ' -f2)
    cash_file=compcash/$(basename $src .asm).cash

    dependency_offset=3
    need_recomp=0
    if ! cmp -s $cash_file $src; then need_recomp=1; fi
    while [ -n $(echo $prog | cut -d' ' -f$dependency_offset) ]; do
        dependency_file=$(echo $prog | cut -d' ' -f$dependency_offset)
        dependency_cash_file=compcash/$(basename $dependency_file .asm).cash
        if ! cmp -s $dependency_cash_file $dependency_file; then
            need_recomp=1
            break
        fi
        ((dependency_offset++))
    done


    if ! cmp -s $cash_file $src || [ $need_recomp == 1 ]; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
        
        print_info "Cashing $bin_name..."
        cp $src $cash_file
        check_error "Cashing of $bin_name failed"
        print_ok "$bin_name cashed successfully"
    fi

    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/BIN.DIR/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done


programs_com=(
    "programs/COM/hello.asm HELLO.COM"
    "programs/COM/fractal.asm FRACTAl.COM"
    "programs/COM/clock.asm CLOCK.COM"
)

for prog in "${programs_com[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    bin_name=$(echo $prog | cut -d' ' -f2)
    cash_file=compcash/com/$(basename $src .asm).cash

    if ! cmp -s $cash_file $src; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
        
        print_info "Cashing $bin_name..."
        cp $src $cash_file
        check_error "Cashing of $bin_name failed"
        print_ok "$bin_name cashed successfully"
    fi
    
    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/COM.DIR/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done


# Copy text files
if [ $FLAG_NO_TXT == 0 ]; then
    print_splitline "Copying text files..."
    text_files=(
        "LICENSE.TXT"
    )

    for file in "${text_files[@]}"; do
        print_info "Copying $file..."
        mcopy -i disk_img/x16pros.img $file ::/
        check_error "Copy of $file failed"
        print_ok "$file copied successfully"
    done

    text_files_doc=(
        "src/txt/README.TXT"
        "src/txt/CONFIGS.TXT"
        "src/txt/FILESYS.TXT"
        "src/txt/LIMITS.TXT"
        "src/txt/PROGRAMS.TXT"
        "src/txt/QUICKST.TXT"
        "src/txt/COMMANDS.TXT"
        "src/txt/EDMAN.TXT"
    )

    for file in "${text_files_doc[@]}"; do
        print_info "Copying $file..."
        mcopy -i disk_img/x16pros.img $file ::/DOCS.DIR/
        check_error "Copy of $file failed"
        print_ok "$file copied successfully"
    done
fi

# Copy image files
print_splitline "Copying image files..."
image_files=(
    "assets/images/logo/LOGO.BMP"
    "assets/images/PROX.BMP"
    "assets/images/PROS.BMP"
    "assets/images/PROS_W.BMP"
    "assets/images/PROS_A.BMP"
    "assets/images/TRAIN.BMP"
    "assets/images/CHILL.BMP"
)

for file in "${image_files[@]}"; do
    print_info "Copying $file..."
    mcopy -i disk_img/x16pros.img $file ::/BMP.DIR/
    check_error "Copy of $file failed"
    print_ok "$file copied successfully"
done

# Copy music files
if [ $FLAG_NO_MUSIC == 0 ]; then
    print_splitline "Copying music files..."
    music_files=(
        "assets/IMF/RICK.IMF"
        "assets/IMF/SONIC.IMF"
        "assets/IMF/HOPES&D.IMF"
        "assets/IMF/RUSSIA.IMF"
        "assets/IMF/METRO_E.IMF"
        "assets/IMF/METRO_E2.IMF"
        "assets/IMF/GTA_VC.IMF"
        "assets/IMF/CYBWRLD.IMF"
        "assets/IMF/BIGSHOT.IMF"
        "assets/IMF/DF.IMF"
        "assets/IMF/TRUEHERO.IMF"
        "assets/IMF/CORE.IMF"
        "assets/WAV/1985.WAV"
    )

    for file in "${music_files[@]}"; do
        print_info "Copying $file..."
        mcopy -i disk_img/x16pros.img $file ::/MUSIC.DIR/
        check_error "Copy of $file failed"
        print_ok "$file copied successfully"
    done
fi

echo -e "$NC"

# Display disk contents
if [ $FLAG_QUIET_MODE == 0 ]; then
    echo -e "$YELLOW Disk contents:$NC"
    mdir -i disk_img/x16pros.img ::/
fi

# Create ISO
# rm -f disk_img/x16pros.iso
# print_info "Creating ISO image (disk_img/x16pros.iso)..."
# mkisofs -quiet -V 'x16-PROS' -input-charset iso8859-1 -o disk_img/x16pros.iso -b x16pros.img disk_img/
# check_error "ISO creation failed"
# print_ok "ISO image created successfully"


print_splitline "Build completed successfully!"
