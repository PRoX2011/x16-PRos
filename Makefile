# ==================================================================
# x16-PRos — Makefile for build and run
# Copyright (C) 2025 PRoX2011
# ==================================================================

NASM := nasm
DD := dd
MKFS := mkfs.vfat
MCOPY := mcopy
MMD := mmd
MDIR := mdir
QEMU := qemu-system-x86_64

BIN_DIR := bin
IMG_DIR := disk_img
IMG_FILE := $(IMG_DIR)/x16pros.img

BOOT_SRC := src/bootloader/boot.asm
BOOT_BIN := $(BIN_DIR)/BOOT.BIN

KERNEL_SRC := src/kernel/kernel.asm
KERNEL_BIN := $(BIN_DIR)/KERNEL.BIN

ROOT_PROGS := \
	programs/autoexec.asm:AUTOEXEC.BIN \
	programs/setup/setup.asm:SETUP.BIN

BIN_PROGS := \
	programs/help.asm:HELP.BIN \
	programs/grep.asm:GREP.BIN \
	programs/theme.asm:THEME.BIN \
	programs/fetch.asm:FETCH.BIN \
	programs/imfplay.asm:IMFPLAY.BIN \
	programs/wavplay.asm:WAVPLAY.BIN \
	programs/credits.asm:CREDITS.BIN \
	programs/hello.asm:HELLO.BIN \
	programs/write.asm:WRITER.BIN \
	programs/barchart.asm:BCHART.BIN \
	programs/brainf.asm:BRAINF.BIN \
	programs/calc.asm:CALC.BIN \
	programs/memory.asm:MEMORY.BIN \
	programs/mine.asm:MINE.BIN \
	programs/piano.asm:PIANO.BIN \
	programs/snake.asm:SNAKE.BIN \
	programs/space.asm:SPACE.BIN \
	programs/procentc.asm:PROCENTC.BIN \
	programs/paint.asm:PAINT.BIN \
	programs/pong.asm:PONG.BIN \
	programs/hexedit.asm:HEXEDIT.BIN \
	programs/clock.asm:CLOCK.BIN \
	programs/mandel.asm:MANDEL.BIN \
	programs/tetris.asm:TETRIS.BIN \
	programs/chars.asm:CHARS.BIN \
	programs/eye.asm:EYE.BIN \
	programs/ed.asm:ED.BIN \
	programs/game.asm:GAME.BIN

COM_PROGS := \
	programs/COM/hello.asm:HELLO.COM \
	programs/COM/fractal.asm:FRACTAL.COM \
	programs/COM/clock.asm:CLOCK.COM

CONF_FILES := \
	src/kernel/configs/USER.CFG \
	src/kernel/configs/FIRST_B.CFG \
	src/kernel/configs/PASSWORD.CFG \
	src/kernel/configs/TIMEZONE.CFG \
	src/kernel/configs/PROMPT.CFG \
	src/kernel/configs/THEME.CFG

ROOT_TXT := LICENSE.TXT

DOC_TXT := \
	src/txt/README.TXT \
	src/txt/CONFIGS.TXT \
	src/txt/FILESYS.TXT \
	src/txt/LIMITS.TXT \
	src/txt/PROGRAMS.TXT \
	src/txt/QUICKST.TXT \
	src/txt/COMMANDS.TXT \
	src/txt/EDMAN.TXT

IMAGES := \
	assets/images/logo/LOGO.BMP \
	assets/images/PROX.BMP \
	assets/images/PROS.BMP \
	assets/images/PROS_W.BMP \
	assets/images/PROS_A.BMP \
	assets/images/TRAIN.BMP \
	assets/images/CHILL.BMP

MUSIC := \
	assets/IMF/RICK.IMF \
	assets/IMF/SONIC.IMF \
	assets/IMF/HOPES\&D.IMF \
	assets/IMF/RUSSIA.IMF \
	assets/IMF/METRO_E.IMF \
	assets/IMF/METRO_E2.IMF \
	assets/IMF/GTA_VC.IMF \
	assets/IMF/CYBWRLD.IMF \
	assets/IMF/BIGSHOT.IMF \
	assets/IMF/DF.IMF \
	assets/IMF/TRUEHERO.IMF \
	assets/IMF/CORE.IMF \
	assets/WAV/1985.WAV

.PHONY: all
all: build

.PHONY: build
build: prepare banner boot kernel image filesystem programs assets list done

.PHONY: banner
banner:
	@echo
	@echo "=============================================="
	@echo " x16-PRos build started"
	@echo "=============================================="
	@echo

.PHONY: prepare
prepare:
	@echo "[PREPARE] Creating directories"
	@mkdir -p $(BIN_DIR) $(IMG_DIR)

.PHONY: boot
boot:
	@echo "[BOOT] Assembling bootloader"
	@$(NASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)

.PHONY: kernel
kernel:
	@echo "[KERNEL] Assembling kernel"
	@$(NASM) -f bin $(KERNEL_SRC) -o $(KERNEL_BIN)

.PHONY: image
image:
	@echo "[IMAGE] Creating disk image"
	@$(DD) if=/dev/zero of=$(IMG_FILE) bs=512 count=2880 conv=notrunc status=none
	@$(MKFS) $(IMG_FILE) -n "x16-PROS"
	@$(DD) if=$(BOOT_BIN) of=$(IMG_FILE) conv=notrunc status=none
	@$(MCOPY) -i $(IMG_FILE) $(KERNEL_BIN) ::/

.PHONY: filesystem
filesystem:
	@echo "[FS] Creating directory structure"
	@$(MMD) -i $(IMG_FILE) ::/BIN.DIR
	@$(MMD) -i $(IMG_FILE) ::/COM.DIR
	@$(MMD) -i $(IMG_FILE) ::/BMP.DIR
	@$(MMD) -i $(IMG_FILE) ::/CONF.DIR
	@$(MMD) -i $(IMG_FILE) ::/DOCS.DIR
	@$(MMD) -i $(IMG_FILE) ::/MUSIC.DIR

.PHONY: programs
programs:
	@echo "[PROGRAMS] Building executables"
	@for p in $(ROOT_PROGS); do \
		src=$${p%%:*}; bin=$${p##*:}; \
		echo "  NASM $$src"; \
		$(NASM) -f bin $$src -o $(BIN_DIR)/$$bin; \
		$(MCOPY) -i $(IMG_FILE) $(BIN_DIR)/$$bin ::/; \
	done
	@for p in $(BIN_PROGS); do \
		src=$${p%%:*}; bin=$${p##*:}; \
		echo "  NASM $$src"; \
		$(NASM) -f bin $$src -o $(BIN_DIR)/$$bin; \
		$(MCOPY) -i $(IMG_FILE) $(BIN_DIR)/$$bin ::/BIN.DIR/; \
	done
	@for p in $(COM_PROGS); do \
		src=$${p%%:*}; bin=$${p##*:}; \
		echo "  NASM $$src"; \
		$(NASM) -f bin $$src -o $(BIN_DIR)/$$bin; \
		$(MCOPY) -i $(IMG_FILE) $(BIN_DIR)/$$bin ::/COM.DIR/; \
	done

.PHONY: assets
assets:
	@echo "[ASSETS] Copying data files"
	@$(MCOPY) -i $(IMG_FILE) $(ROOT_TXT) ::/
	@$(MCOPY) -i $(IMG_FILE) $(CONF_FILES) ::/CONF.DIR/
	@$(MCOPY) -i $(IMG_FILE) src/kernel/configs/SYSTEM.CFG ::/
	@$(MCOPY) -i $(IMG_FILE) $(DOC_TXT) ::/DOCS.DIR/
	@$(MCOPY) -i $(IMG_FILE) $(IMAGES) ::/BMP.DIR/
	@$(MCOPY) -i $(IMG_FILE) $(MUSIC) ::/MUSIC.DIR/

.PHONY: list
list:
	@echo
	@echo "[FS] Disk contents"
	@$(MDIR) -i $(IMG_FILE) ::/
	@echo

.PHONY: done
done:
	@echo "=============================================="
	@echo " Build completed successfully"
	@echo "=============================================="
	@echo

.PHONY: run
run:
	@echo "[RUN] Starting emulator"
	@$(QEMU) \
		-display gtk \
		-drive file=$(IMG_FILE),format=raw,if=floppy \
		-machine pcspk-audiodev=snd0 \
		-device adlib,audiodev=snd0 \
		-audiodev pa,id=snd0

.PHONY: clean
clean:
	@echo "[CLEAN] Removing build artifacts"
	@rm -rf $(BIN_DIR) $(IMG_DIR)
