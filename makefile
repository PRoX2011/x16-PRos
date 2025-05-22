AS=nasm
ASFLAGS=-f bin

ECHO=echo -e

SRC_BOOT=boot.asm
SRC_BOOT_DIR=boot
SRC_KERNEL=kernel.asm
SRC_KERNEL_DIR=kernel

SRC_PROGS_DIR=src
SRCS_PROGS=writer.asm brainf.asm barchart.asm snake.asm \
	calc.asm disk_tools.asm mine.asm memory.asm space.asm piano.asm

BUILD_DIR=build

IMG=x16pros.img
IMG_DIR=$(BUILD_DIR)/disk_img
BIN_PROGS_PATH=$(IMG_DIR)/progs_bin
IMG_PATH=$(IMG_DIR)/$(IMG)


#TODO fix and remove
KERNEL_SIZE=10240
BOOT_SIZE=512

FS_POINTS=./fs.inc
CURRENT_POINT=$(shell echo $$(( 512 + $(BOOT_SIZE) + $(KERNEL_SIZE) )))
BLOCK_SIZE=512


OBJ_KERNEL=$(SRC_KERNEL:%.asm=$(BUILD_DIR)/kernel/%.o)
BIN_KERNEL=$(OBJ_KERNEL:.o=.bin)

OBJ_BOOT=$(SRC_BOOT:%.asm=$(BUILD_DIR)/boot/%.o)
BIN_BOOT=$(OBJ_BOOT:.o=.bin)

OBJS_PROGS=$(SRCS_PROGS:%.asm=$(BUILD_DIR)/%.o) $(BUILD_DIR)/ILM.o
BINS_PROGS=$(OBJS_PROGS:.o=.bin) 



all: clean_img $(IMG_PATH) $(BINS_PROGS)

$(IMG_PATH): CREATE_IMG

CREATE_IMG: PRE_CREATE_IMG $(BIN_KERNEL) $(BIN_BOOT)
	cat $(BIN_BOOT) $(BIN_KERNEL) > $(IMG_DIR)/BOOT_KERNEL
	truncate -s $(shell echo $$(( $(BOOT_SIZE) + $(KERNEL_SIZE) ))) $(IMG_DIR)/BOOT_KERNEL
	cat $(IMG_DIR)/BOOT_KERNEL $(BIN_PROGS_PATH) > $(IMG_PATH)


PRE_CREATE_IMG: $(BINS_PROGS)
	mkdir $(IMG_DIR)
	cat $(BINS_PROGS) > $(BIN_PROGS_PATH)

$(BIN_BOOT):$(OBJ_BOOT)
	dd if=$< of=$@ bs=512 conv=notrunc

$(OBJ_BOOT):$(SRC_BOOT_DIR)/$(SRC_BOOT) 
	mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<
	./align-file.sh $@

$(BIN_KERNEL):$(OBJ_KERNEL)
	dd if=$< of=$@ bs=512 conv=notrunc

$(OBJ_KERNEL):$(SRC_KERNEL_DIR)/$(SRC_KERNEL) 
	mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<
	./align-file.sh $@


$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.o | $(FS_POINTS)
	dd if=$< of=$@ bs=512 conv=notrunc
	echo $<
	$(eval SIZE = $(shell stat -c %s "$<"))
	printf "%s\n%%define START_$$(echo $(@:$(BUILD_DIR)/%.bin=%) | tr 'a-z' 'A-Z') $(shell echo $$(($(CURRENT_POINT) / $(BLOCK_SIZE))))" "$$(cat $(FS_POINTS))" > $(FS_POINTS)
	printf "%s\n%%define SIZE_$$(echo $(@:$(BUILD_DIR)/%.bin=%) | tr 'a-z' 'A-Z') $(shell echo $$(($(SIZE) / $(BLOCK_SIZE))))" "$$(cat $(FS_POINTS))" > $(FS_POINTS)
	$(eval CURRENT_POINT = $(shell echo $$(($(SIZE) + $(CURRENT_POINT) ))))


$(BUILD_DIR)/ILM.o: bin/ILM.o | $(BUILD_DIR)
	cp bin/ILM.o $(BUILD_DIR)/ILM.o

$(BUILD_DIR)/%.o: $(SRC_PROGS_DIR)/%.asm | align-file.sh $(BUILD_DIR)
	$(AS) $(ASFLAGS) -o $@ $<
	./align-file.sh $@


$(BUILD_DIR):
	mkdir -p $@


$(FS_POINTS):
	touch $(FS_POINTS)

run: $(IMG_PATH)
	qemu-system-i386 -audiodev pa,id=snd0 -machine pcspk-audiodev=snd0 -hda $(IMG_PATH)
# 	-drive file=$(IMG_PATH),index=0,format=raw


clean: clean_img clean_bin
	rm -f $(FS_POINTS)

clean_img:
	rm -rf disk_img/x16pros.img

clean_bin:
	rm -rf build
