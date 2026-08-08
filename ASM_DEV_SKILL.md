# x16-PRos — Assembly Development Guide & Session Retrospective

Authoritative developer guide for writing x86 (16-bit real mode) NASM code for
x16-PRos. Replaces the former `.kilo/skills/x86-nasm-real-mode/SKILL.md` and is
kept in the repository root so it is versioned with the code.

---

## 1. Golden rules (do this)

1. **Use NASM labels, never hand-computed offsets.** NASM resolves every
   `mov ax, my_var` / `call my_func` for you. Hand-picking binary offsets for
   debugging is slow and error-prone (see Retrospective #4).
2. **Debug variables go in kernel `.data`/`.bss`, never in working buffers.**
   `disk_buffer` (0x2000:0xE000), `dirlist` (0x2000:0xA800) and `command_history`
   (0x2000:0xD000) are overwritten by disk I/O — a counter written there reads
   back as garbage and wastes hours (Retrospective #3).
3. **Respect the real-mode vector map.** Vectors `0x08..0x0F` are hardware IRQs:
   0x08=timer, 0x09=keyboard, 0x0E=floppy. Never install "exception" handlers
   there — #PF/#GP only exist in protected mode. Only `0x00` (#DE) and `0x06`
   (#UD) are pure real-mode exceptions (Retrospective #2).
4. **Chain BIOS hooks with `pushf; call far [old_vector]`.** This is the standard
   TSR pattern and it works (INT 0x16 layout translation uses it). After the old
   handler returns, DS/ES may be clobbered — restore `DS=0x2000` before touching
   any kernel variable.
5. **Return CF/ZF through `iret` by patching the saved flags on the stack.**
   `iret` restores the caller's flags, so `clc; iret` is a no-op for CF. Use
   `mov bp, sp` then `or/and word [bp + 4 + 2*N], 0x0001/0xFFFE` where `N` is the
   number of pushes in the handler (see `com/handles.asm` macros).
6. **Always EOI the PIC when doing work from a hardware-interrupt context.**
   The INT 0x1C timer hook aborts from inside the BIOS INT 8; without
   `out 0x20, al` (EOI, AL=0x20) the timer IRQ stays pending and the clock stops.
7. **Bound every buffer.** Strings copied from callers are capped at 63 bytes
   (`api_output.asm`/`api_fs.asm`). DOS file handles cap writes to the 16 KiB
   buffer (`com_40h`). Path components are capped at 14 (`cd_command`). Check
   every new copy/write against its destination size.
8. **Load big files into `0x3000` (DATA_LOAD_SEG), never into 0x2000/0x1000.**
   Files > 32 KiB loaded at `0x1000:0x8000` wrap into the kernel segment and the
   `FS_CHECK_DEST` guard rejects them; `cat`/`copy` already use `0x3000`.
9. **Test after full boot.** QEMU boot takes ~18 s; sending keys earlier means
   they sit in the BIOS buffer and make input look broken (Retrospective #12).
10. **Verify the floppy image first** when the bootloader "cannot find
    KERNEL.BIN" — check the FAT12 builder (root directory, FAT chain, boot
    sector) before suspecting the bootloader or QEMU (Retrospective #1).
11. **Follow CONTRIBUTING.md**: lowercase function names, UPPERCASE constants,
    lowercase variables, 4-space indent, function doc headers `; ===…===`,
    English comments. The only accepted non-English exception is the Cyrillic
    characters in `ru_layout_table` (they document the mapped characters).

## 2. Never do this

1. `mov ss, sp` style stack setup without a stack segment (tbasic bug) —
   `SS=0` + deep stack grows into the IVT/BDA. Set `SS` explicitly.
2. `int 0x19` to exit a program — that reboots the machine. BIN programs exit
   with a near `ret` (trampoline returns to the shell).
3. Direct port reads like `in al, 0x60` for the keyboard — they steal scan codes
   from the BIOS buffer and desync IRQ1. Use `INT 0x16`.
4. `jmp $` busy-waits / infinite loops in programs (tetris `game_over`).
5. Unbalanced pushes before a jump out of scope (mine `DetectWin`).
6. `mov ax, 4C00h; int 21h` to exit a BIN program — AH=4Ch is not a PRos BIN
   function; execution falls into garbage. Use `ret`.
7. Overwrite a file silently when it exceeds a buffer (hexedit/write) — fail
   with a message instead.
8. Scale 16-bit addresses (`[bx*2]`, `[sp+16]`, `[dx+label]`): 16-bit addressing
   allows only BX/BP/SI/DI without scaling, and SP cannot be a base register.
9. Use `Ctrl+Alt+Del` as a custom hotkey — the BIOS intercepts it for reboot.
   `Ctrl+Shift+F1` is the safe choice.
10. Store local data labels at the end of a file — `.size` etc. bind to the last
    non-local label (`print_char.size`) and break references from earlier code.
    Use global names for module-level data.
11. Assume QEMU screenshots are reliable — `screendump` on QEMU 11 is flaky and
    hangs intermittently. Use QMP `pmemsave`/`xp` for deterministic checks.
12. Write a caller buffer using the caller's DS without saving it — handlers
    entered via INT have the program's DS; always `push ds` and restore.

## 3. Memory map (kernel constants)

| Segment:Offset | Purpose |
|---|---|
| 0x0000:0x0000 | IVT (int20/int21/int22 hooks; fault hooks on 0x00/0x06) |
| 0x1000:0x0000 | CP866 font / CFG scratch (CFG_SCRATCH_OFF = 0x1000) |
| 0x1000:0x8000 | BIN program entry (PROGRAM_LOAD_SEG:PROGRAM_LOAD_OFF); thunk at 0x7FF0; params at 0x7F00 |
| 0x2000:0x0000 | Kernel code+data+bss (must end below 0xA800) |
| 0x2000:0xA800 | dirlist / 0xD000 history / 0xE000 disk_buffer |
| 0x2FC0:0x0100 | COM programs (stack 0x2FC0:0xFFFE, exit via INT 0x20) |
| 0x3000:0x0000 | DATA_LOAD / BMP / IMF (safe big-file area) |
| 0x3010:0x0000 | EXE load segment (image ≤ 0xC000) |
| 0x4000:0x0000 | DOS file-handle buffers (4 × 16 KiB) |
| SS=0, SP=0xFFFF | Kernel stack (keep recursion shallow) |

`current_program_type`: 0 = shell, 1 = BIN/PLE, 2 = COM/EXE. Used by the
Ctrl+Shift+F1 abort (INT 0x16 hook + INT 0x1C backup).

## 4. ABI for programs

- **BIN** (0x1000:0x8000): must end with a balanced near `ret`. Params at
  `0x1000:0x7F00` (SI points there on entry).
- **COM** (0x2FC0:0x0100): exit with `INT 0x20` (offset 0 contains `CD 20`) or
  `int 21h ah=4Ch`. PS/2 mouse is disabled for programs.
- **EXE** (0x3010): MZ header validated; relocations bounded to the image.
- **PLE**: custom format, must call `api_dos_init` before INT 0x21.
- Kernel API: `INT 0x21` = output (PRos), `INT 0x22` = filesystem. During
  COM/EXE the DOS `INT 0x21` handler is active (file handles 3Ch..42h, 2Eh, 43h,
  56h).
- `Ctrl+Shift+F1` aborts any running program back to the shell; `Ctrl+Shift`
  toggles the RU/EN layout.

## 5. Workflow

1. Read the affected file first; note which segment DS/ES/SS point to at the
   edit point (kernel = 0x2000; after `mov ds, <prog_seg>` everything is
   relative).
2. Follow the flag convention: CF=0 success / CF=1 error; results in AX/BX/DX.
   Document IN/OUT in the doc header.
3. Bound every length read from disk/config/user input.
4. Never trust file-derived pointers (FAT chains, MZ reloc table, PLE segments).
5. Build/test on Windows with `tools/build_test.ps1` + `tools/qemu_test.py`
   (QMP). Wait ~18 s for full boot before sending keys.
6. Keep `kernel_end` below 0xA800; the kernel was ~37 KB of a 43 KB budget.

## 6. Session retrospective — mistakes made and lessons learned

1. **Broken FAT12 builder caused hours of "bootloader debugging".** The
   `build_image.py` placed root files into a nonexistent `""` directory, so the
   bootloader never found KERNEL.BIN. The mistake was assuming the bootloader/
   QEMU was wrong instead of verifying the image first. Lesson: validate the
   image (root dir, FAT, boot sector) before anything else.
2. **Overwrote vector 0x0E (IRQ6 / floppy) with a "#PF" handler.** In real mode
   vectors 0x08..0x0F are hardware IRQs; the floppy read hung. Lesson: only
   0x00 (#DE) and 0x06 (#UD) are safe to hook in real mode.
3. **Debug counters placed inside `disk_buffer`** (0x2000:0xF000) read back as
   zeros because disk I/O overwrites them — led to false conclusions that the
   BIOS "did not preserve DS". Lesson: debug state lives in `.data`/`.bss`.
4. **Hand-derived variable offsets were repeatedly wrong.** `current_program_type`
   vs `autocomplete_enabled` confusion; kernel size changes shifted offsets
   between builds. Lesson: use NASM labels; find addresses via the disassembly
   of the *specific* instruction, not guessing.
5. **Rewrote a working INT 0x16 hook (pushf/call far) into a BDA reader** based
   on the bad debug data, which broke multi-key input and crashed into the video
   BIOS. Reverting to `pushf; call far` + restoring DS fixed it. Lesson: don't
   replace a working mechanism on shaky evidence.
6. **Ctrl+Alt+Del is intercepted by the BIOS** (warm reboot); the abort hotkey
   had to become Ctrl+Shift+F1. Lesson: check BIOS-intercepted keys.
7. **16-bit addressing pitfalls repeated:** `[sp+16]`, `[bx*2]`, `[dx+label]`
   are invalid; only BX/BP/SI/DI without scaling, SP not a base.
8. **Local data labels at EOF** (`.size`, `.seconds`) bound to the last function
   and produced `symbol not defined`. Lesson: global names for module data.
9. **CF via `clc; iret` is a no-op** — the flags must be patched on the saved
   stack word. Discovered while implementing the DOS file-handle layer.
10. **QEMU 11 `screendump` is flaky** and hangs after repeated calls; switching
    to QMP (`pmemsave`, `xp`, `screendump` via QMP) made verification
    deterministic.
11. **Boot is slow (~18 s)**; tests typed commands before the shell was ready and
    misread the result as broken input. Lesson: wait for full boot.
12. **The EOI gap:** the timer hook aborted from inside INT 8 without
    acknowledging the PIC, which would stop the system clock. Fixed with
    `out 0x20, al`.
13. **The DOS write path lacked a size cap** (com_40h could overflow a handle
    buffer); fixed to cap at the free space.

## 7. Key reference points

- OSDev Wiki: real mode, FAT12, MZ format — https://wiki.osdev.org
- NASM manual: https://nasm.us/doc/
- Repo docs: `docs/API.md`, `docs/CONFIGURATION.md`, `CONTRIBUTING.md`,
  `src/kernel/MEM_MAP.TXT`
- Test tooling: `tools/build_test.ps1`, `tools/qemu_test.py`,
  `tools/qemu_debug.py`, `tools/build_image.py`
