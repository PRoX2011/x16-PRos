AS=nasm
ASFLAGS=-f bin

ECHO=echo -e

IMG=x16pros.img
IMG_DIR=disk_img
SRC_DIR=./src
SRCS=boot.asm kernel.asm write.asm brainf.asm barchart.asm snake.asm \
	calc.asm disk-tools.asm mine.asm memory.asm space.asm piano.asm
BUILD_DIR=./build

OBJS=$(SRCS:%=$(BUILD_DIR)/%.o)
BINS=$(OBJS:.o=.bin)

all: clean_img $(IMG_DIR)/$(IMG)

$(IMG_DIR)/$(IMG): $(BINS)
	touch $@
	cat $@ $(BINS) > $@

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.o
	dd if=$< of=$@ bs=512 conv=notrunc

$(BUILD_DIR)/%.asm.o: $(SRC_DIR)/%.asm
	mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<


run: $(IMG_DIR)/$(IMG)
	qemu-system-i386 -audiodev pa,id=snd0 -machine pcspk-audiodev=snd0 -drive file=$(IMG_DIR)/$(IMG),index=0,format=raw


clean: clean_img clean_bin

clean_img:
	rm -rf disk_img/x16pros.img

clean_bin:
	rm -rf bin
