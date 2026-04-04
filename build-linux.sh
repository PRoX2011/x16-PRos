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
FLAG_NO_PROGRAMS_RECOMP=0
FLAG_NO_LOGO_DISPLAY=0
FLAG_NO_SETUP=0
FLAG_DTM=0  # DTM - Dev Tesing Mode

MAX_KERNEL_LOADER_BYTES=32768
KERNEL_SIZE_WARN_BYTES=30720

for arg in $@; do
    if [ $arg == "-quiet" ]; then FLAG_QUIET_MODE=1; continue; fi
    if [ $arg == "-no-music" ]; then FLAG_NO_MUSIC=1; continue; fi
    if [ $arg == "-no-txt" ]; then FLAG_NO_TXT=1; continue; fi
    if [ $arg == "-no-boot-recomp" ]; then FLAG_NO_BOOT_RECOMP=1; continue; fi
    if [ $arg == "-no-kernel-recomp" ]; then FLAG_NO_KERNEL_RECOMP=1; continue; fi
    if [ $arg == "-no-programs-recomp" ]; then FLAG_NO_PROGRAMS_RECOMP=1; continue; fi
    if [ $arg == "-no-logo-display" ]; then FLAG_NO_LOGO_DISPLAY=1; continue; fi
    if [ $arg == "-no-setup" ]; then FLAG_NO_SETUP=1; continue; fi
    if [ $arg == "-dtm" ]; then FLAG_NO_SETUP=1; FLAG_NO_LOGO_DISPLAY=1; FLAG_NO_BOOT_RECOMP=1; continue; fi
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

print_kernel_size() {
    local label="$1"
    local size_bytes
    size_bytes=$(stat -c%s bin/KERNEL.BIN 2>/dev/null)
    if [ -n "$size_bytes" ]; then
        local size_kib
        size_kib=$(( (size_bytes + 1023) / 1024 ))
        print_info "$label kernel size: ${size_bytes} bytes (~${size_kib} KiB)"
    fi
}

check_kernel_size_guard() {
    local size_bytes
    size_bytes=$(stat -c%s bin/KERNEL.BIN 2>/dev/null || echo 0)

    if [ "$size_bytes" -le 0 ]; then
        print_failed "Kernel image missing: bin/KERNEL.BIN"
    fi

    print_info "Loader window limit: ${MAX_KERNEL_LOADER_BYTES} bytes"

    if [ "$size_bytes" -gt "$KERNEL_SIZE_WARN_BYTES" ]; then
        print_info "Kernel size warning: ${size_bytes} bytes is close to loader limit"
    fi

    if [ "$size_bytes" -gt "$MAX_KERNEL_LOADER_BYTES" ]; then
        print_failed "Kernel too large for bootloader window (${size_bytes} > ${MAX_KERNEL_LOADER_BYTES})"
    fi
}

mkdir -p bin
mkdir -p disk_img

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
    addition_flags=""
    if [ $FLAG_NO_LOGO_DISPLAY == 1 ]; then
        addition_flags="-d NO_LOGO_DISPLAY"
    fi
    baseline_kernel_size=$(stat -c%s bin/KERNEL.BIN 2>/dev/null || echo 0)
    print_info "Compiling kernel (kernel.asm => bin/KERNEL.BIN)..."
    nasm -f bin src/kernel/kernel.asm -o bin/KERNEL.BIN $addition_flags
    check_error "Kernel compilation failed"
    print_ok "Kernel compiled successfully"
    current_kernel_size=$(stat -c%s bin/KERNEL.BIN 2>/dev/null || echo 0)
    if [ "$baseline_kernel_size" -gt 0 ]; then
        delta_kernel_size=$((current_kernel_size - baseline_kernel_size))
        delta_sign="+"
        if [ "$delta_kernel_size" -lt 0 ]; then
            delta_sign=""
        fi
        print_info "Kernel size delta: ${delta_sign}${delta_kernel_size} bytes (baseline ${baseline_kernel_size})"
    fi
    print_kernel_size "Current"
fi

check_kernel_size_guard

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

# Create FONTS directory
print_splitline "Creating FONTS directory..."
print_info "Creating FONTS directory..."
mmd -i disk_img/x16pros.img ::/FONTS.DIR
check_error "Failed to create FONTS directory"
print_ok "FONTS directory created successfully"

# Create THEMES directory
print_splitline "Creating THEMES directory..."
print_info "Creating THEMES directory..."
mmd -i disk_img/x16pros.img ::/THEMES.DIR
check_error "Failed to create THEMES directory"
print_ok "THEMES directory created successfully"

# Copy fonts
print_info "Copying DEFAULT.FNT to disk..."
mcopy -i disk_img/x16pros.img assets/fonts/DEFAULT.FNT ::/FONTS.DIR/
check_error "DEFAULT.FNT copy failed"
print_ok "DEFAULT.FNT copied successfully"

print_info "Copying BOLD.FNT to disk..."
mcopy -i disk_img/x16pros.img assets/fonts/BOLD.FNT ::/FONTS.DIR/
check_error "BOLD.FNT copy failed"
print_ok "BOLD.FNT copied successfully"

print_info "Copying THIN.FNT to disk..."
mcopy -i disk_img/x16pros.img assets/fonts/THIN.FNT ::/FONTS.DIR/
check_error "THIN.FNT copy failed"
print_ok "THIN.FNT copied successfully"

print_info "Copying ITALIC.FNT to disk..."
mcopy -i disk_img/x16pros.img assets/fonts/ITALIC.FNT ::/FONTS.DIR/
check_error "ITALIC.FNT copy failed"
print_ok "ITALIC.FNT copied successfully"

# Copy themes
print_info "Copying DEFAULT.THM to disk..."
mcopy -i disk_img/x16pros.img assets/themes/DEFAULT.THM ::/THEMES.DIR/
check_error "DEFAULT.THM copy failed"
print_ok "DEFAULT.THM copied successfully"

print_info "Copying VGA.THM to disk..."
mcopy -i disk_img/x16pros.img assets/themes/VGA.THM ::/THEMES.DIR/
check_error "VGA.THM copy failed"
print_ok "VGA.THM copied successfully"

print_info "Copying UBUNTU.THM to disk..."
mcopy -i disk_img/x16pros.img assets/themes/UBUNTU.THM ::/THEMES.DIR/
check_error "UBUNTU.THM copy failed"
print_ok "UBUNTU.THM copied successfully"

print_info "Copying OCEAN.THM to disk..."
mcopy -i disk_img/x16pros.img assets/themes/OCEAN.THM ::/THEMES.DIR/
check_error "OCEAN.THM copy failed"
print_ok "OCEAN.THM copied successfully"

print_info "Copying MONO.THM to disk..."
mcopy -i disk_img/x16pros.img assets/themes/MONO.THM ::/THEMES.DIR/
check_error "MONO.THM copy failed"
print_ok "MONO.THM copied successfully"

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
mcopy -i disk_img/x16pros.img src/kernel/configs/FONT.CFG ::/CONF.DIR/
check_error "FONT.CFG copy failed"
print_ok "FONT.CFG copied successfully"
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

    addition_flags=""
    if [ $FLAG_NO_SETUP == 1 ]; then
        addition_flags="-d NO_SETUP"
    fi

    if [ $FLAG_NO_PROGRAMS_RECOMP == 0 ]; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name $addition_flags
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
    fi
    
    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done

programs=(
    "programs/help.asm HELP.BIN"
    "programs/grep.asm GREP.BIN"
    "programs/head.asm HEAD.BIN"
    "programs/tail.asm TAIL.BIN"
    "programs/dlist.asm DLIST.BIN"
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
    "programs/ed.asm ED.BIN"
    "programs/fdisk.asm FDISK.BIN"
    "programs/launch.asm LAUNCH.BIN"
    "programs/font.asm FONT.BIN"
    "programs/tree.asm TREE.BIN"
)

for prog in "${programs[@]}"; do
    src=$(echo $prog | cut -d' ' -f1)
    bin_name=$(echo $prog | cut -d' ' -f2)

    if [ $FLAG_NO_PROGRAMS_RECOMP == 0 ]; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
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

    if [ $FLAG_NO_PROGRAMS_RECOMP == 0 ]; then
        print_info "Compiling $src => bin/$bin_name..."
        nasm -f bin $src -o bin/$bin_name
        check_error "Compilation of $src failed"
        print_ok "$bin_name compiled successfully"
    fi
    
    print_info "Copying $bin_name to disk..."
    mcopy -i disk_img/x16pros.img bin/$bin_name ::/COM.DIR/
    check_error "Copy of $bin_name failed"
    print_ok "$bin_name copied successfully"
done

c_api_modules=(
    "c-api/src/pros.c bin/c-api/pros.o"
    "c-api/src/i86.asm bin/c-api/i86.o"
)

c_api_lib="bin/c-api.a"
c_api_headers_dir="c-api/include"

programs_c=()

# Build this only if gcc-ia16 and binutils-ia16 are installed and available
if command -v ia16-elf-gcc >/dev/null 2>&1 && \
   command -v ia16-elf-ld >/dev/null 2>&1 && \
   command -v ia16-elf-ar >/dev/null 2>&1; then
    # Build and link C API modules
    mkdir -p bin/c-api
    rm -f bin/c-api.a # Remove old library
    for module in "${c_api_modules[@]}"; do
        src=$(echo $module | cut -d' ' -f1)
        dist=$(echo $module | cut -d' ' -f2)

        print_info "Compiling $src => $dist..."
        if [[ $src == *.asm ]]; then
            nasm -f elf32 $src -o $dist
        elif [[ $src == *.c ]]; then
            ia16-elf-gcc \
                -mno-callee-assume-ss-data-segment \
                -mcmodel=tiny \
                -I$c_api_headers_dir \
                -o $dist \
                -c $src
        else
            print_failed "$src: unknown source file format"
        fi
        check_error "Compilation of $src failed"
        print_info "Linking $dist => $c_api_lib..."
        ia16-elf-ar r $c_api_lib $dist
        check_error "Linking of $dist failed"
        print_ok "$dist linked to $c_api_lib successfully"
    done

    # Build C programs
    for prog in "${programs_c[@]}"; do
        build_script=$(echo $prog | cut -d' ' -f1)
        bin_path=$(echo $prog | cut -d' ' -f2)

        print_info "Running $build_script to get $bin_path..."
        $build_script $bin_path $c_api_lib $c_api_headers_dir
        check_error "$build_script returned error code"
        print_ok "$build_script finished successfully"

        print_info "Copying $bin_path to disk..."
        mcopy -i disk_img/x16pros.img $bin_path ::/BIN.DIR/
        check_error "Copy of $bin_path failed"
        print_ok "$bin_path copied successfully"
    done
else # If there's no 16-bit C compiler and tools
    print_info "gcc-ia16 and binutils-ia16 are not available."
    print_info "Skipping build of C programs..."
fi

mcopy -i disk_img/x16pros.img bin/prasm.bin ::/BIN.DIR/

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

    print_info "Copying project_philosophy.txt as PROJECT.TXT..."
    mcopy -o -i disk_img/x16pros.img project_philosophy.txt ::/PROJECT.TXT
    check_error "Copy of PROJECT.TXT failed"
    print_ok "PROJECT.TXT copied successfully"

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
