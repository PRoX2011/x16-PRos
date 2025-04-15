GREEN := '\033[32m'
NC := '\033[0m'

SRC_DIR := src
BIN_DIR := bin
DISK_IMG_DIR := disk_img

BOOT_BIN := $(BIN_DIR)/boot.bin
KERNEL_BIN := $(BIN_DIR)/kernel.bin
WRITE_BIN := $(BIN_DIR)/write.bin
BRAINF_BIN := $(BIN_DIR)/brainf.bin
BARCHART_BIN := $(BIN_DIR)/barchart.bin
SNAKE_BIN := $(BIN_DIR)/snake.bin
CALC_BIN := $(BIN_DIR)/calc.bin
DISK_IMG := $(DISK_IMG_DIR)/x16pros.img

ASM_FILES := $(SRC_DIR)/boot.asm $(SRC_DIR)/kernel.asm $(SRC_DIR)/write.asm \
             $(SRC_DIR)/brainf.asm $(SRC_DIR)/barchart.asm $(SRC_DIR)/snake.asm \
             $(SRC_DIR)/calc.asm

all: compile create_image launch

compile: $(BOOT_BIN) $(KERNEL_BIN) $(WRITE_BIN) $(BRAINF_BIN) $(BARCHART_BIN) $(SNAKE_BIN) $(CALC_BIN)

$(BOOT_BIN): $(SRC_DIR)/boot.asm
	@echo -e "$(GREEN)Compiling the bootloader$(NC)"
	nasm -f bin $< -o $@

$(KERNEL_BIN): $(SRC_DIR)/kernel.asm
	@echo -e "$(GREEN)Compiling the kernel$(NC)"
	nasm -f bin $< -o $@

$(WRITE_BIN): $(SRC_DIR)/write.asm
	@echo -e "$(GREEN)Compiling write program$(NC)"
	nasm -f bin $< -o $@

$(BRAINF_BIN): $(SRC_DIR)/brainf.asm
	@echo -e "$(GREEN)Compiling brainf program$(NC)"
	nasm -f bin $< -o $@

$(BARCHART_BIN): $(SRC_DIR)/barchart.asm
	@echo -e "$(GREEN)Compiling barchart program$(NC)"
	nasm -f bin $< -o $@

$(SNAKE_BIN): $(SRC_DIR)/snake.asm
	@echo -e "$(GREEN)Compiling snake program$(NC)"
	nasm -f bin $< -o $@

$(CALC_BIN): $(SRC_DIR)/calc.asm
	@echo -e "$(GREEN)Compiling calc program$(NC)"
	nasm -f bin $< -o $@

create_image: $(BOOT_BIN) $(KERNEL_BIN) $(WRITE_BIN) $(BRAINF_BIN) $(BARCHART_BIN) $(SNAKE_BIN) $(CALC_BIN)
	@echo -e "$(GREEN)Creating a disk image$(NC)"
	@mkdir -p $(DISK_IMG_DIR)
	dd if=/dev/zero of=$(DISK_IMG) bs=512 count=25
	dd if=$(BOOT_BIN) of=$(DISK_IMG) conv=notrunc
	dd if=$(KERNEL_BIN) of=$(DISK_IMG) bs=512 seek=1 conv=notrunc
	dd if=$(WRITE_BIN) of=$(DISK_IMG) bs=512 seek=8 conv=notrunc
	dd if=$(BRAINF_BIN) of=$(DISK_IMG) bs=512 seek=11 conv=notrunc
	dd if=$(BARCHART_BIN) of=$(DISK_IMG) bs=512 seek=14 conv=notrunc
	dd if=$(SNAKE_BIN) of=$(DISK_IMG) bs=512 seek=15 conv=notrunc
	dd if=$(CALC_BIN) of=$(DISK_IMG) bs=512 seek=17 conv=notrunc
	@echo -e "$(GREEN)Done.$(NC)"

launch:
	@echo -e "$(GREEN)Launching QEMU...$(NC)"
	qemu-system-i386 -hda $(DISK_IMG)

clean:
	rm -f $(BIN_DIR)/* $(DISK_IMG)

.PHONY: all compile create_image launch clean