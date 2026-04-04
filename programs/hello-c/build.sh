OUT_FILE=$1
C_API_LIB=$2
C_API_INCLUDE=$3

set -e # Exit on errors

ia16-elf-gcc -mno-callee-assume-ss-data-segment \
    -mcmodel=tiny \
    -nostdlib \
    -I$C_API_INCLUDE \
    -T programs/hello-c/hello-c.ld \
    -o $OUT_FILE \
    programs/hello-c/hello-c.c \
    $C_API_LIB
