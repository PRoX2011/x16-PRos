# x16-PRos API Documentation

## Overview

The x16-PRos operating system provides a set of interrupt-driven APIs for developers to interact with the system. These
APIs are organized into three categories, each accessible via a specific interrupt:

- **INT 0x21**: Output API for screen output and video mode initialization.
- **INT 0x22**: File System API for managing files on a FAT12 file system.
- **INT 0x23**: System API for memory allocation, PLE launch, cooperative multitasking, and mouse control.

Each interrupt handler uses the `AH` register to specify the function code, with other registers used for input and
output parameters as described below. Unless specified, all functions preserve registers not used for output and set the
carry flag (CF) on error.

---

## INT 0x21 - Output API

The Output API provides functions for displaying text on the screen in various colors and managing the video mode. It
uses interrupt `0x21` and is initialized by setting up the interrupt vector table (IVT) and configuring the VGA video
mode (640x480, 16 colors).

### Function 0x00: Initialize Output System

- **Description**: Initializes the output system by setting the VGA video mode to 640x480 with 16 colors.
- **Input**:
    - `AH` = 0x00
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: No errors reported (no carry flag set)
- **Notes**: Uses BIOS interrupt `0x10` with `AX = 0x12` to set the video mode. Called during kernel initialization.

### Function 0x01: Print String (White)

- **Description**: Prints a null-terminated string to the screen in white.
- **Input**:
    - `AH` = 0x01
    - `SI` = Pointer to null-terminated string
- **Output**: None
- **Preserves**: All registers except `SI` (advanced to the end of the string)
- **Error Handling**: No errors reported
- **Notes**: Uses BIOS interrupt `0x10` with `AH = 0x0E` and `BL = 0x0F` (white color). Supports newline (`0x0A`) by
  inserting a carriage return (`0x0D`) and line feed.

### Function 0x02: Print String (Green)

- **Description**: Prints a null-terminated string to the screen in green.
- **Input**:
    - `AH` = 0x02
    - `SI` = Pointer to null-terminated string
- **Output**: None
- **Preserves**: All registers except `SI` (advanced to the end of the string)
- **Error Handling**: No errors reported
- **Notes**: Similar to function 0x01, but uses `BL = 0x0A` (green color).

### Function 0x03: Print String (Cyan)

- **Description**: Prints a null-terminated string to the screen in cyan.
- **Input**:
    - `AH` = 0x03
    - `SI` = Pointer to null-terminated string
- **Output**: None
- **Preserves**: All registers except `SI` (advanced to the end of the string)
- **Error Handling**: No errors reported
- **Notes**: Uses `BL = 0x0B` (cyan color).

### Function 0x04: Print String (Red)

- **Description**: Prints a null-terminated string to the screen in red.
- **Input**:
    - `AH` = 0x04
    - `SI` = Pointer to null-terminated string
- **Output**: None
- **Preserves**: All registers except `SI` (advanced to the end of the string)
- **Error Handling**: No errors reported
- **Notes**: Uses `BL = 0x0C` (red color).

### Function 0x05: Print Newline

- **Description**: Outputs a carriage return (`0x0D`) and line feed (`0x0A`) to move the cursor to the next line.
- **Input**:
    - `AH` = 0x05
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: No errors reported
- **Notes**: Uses BIOS interrupt `0x10` with `AH = 0x0E`.

### Function 0x06: Clear Screen

- **Description**: Clears the screen by resetting the VGA video mode to 640x480 with 16 colors. The current theme is **not** reapplied — the screen is left in default VGA state (black background). Use this when the caller wants the raw VGA defaults (e.g. SETUP).
- **Input**:
    - `AH` = 0x06
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: No errors reported
- **Notes**: Calls BIOS interrupt `0x10` with `AX = 0x12`.

## Function 0x07: Set Text Color

- **Description**: Sets the text color to be used by the `Print String with Current Color` function (0x08).
- **Input**:
    - `AH` = 0x07
    - `BL` = Color code (valid values: 0x00–0x0F, corresponding to VGA 16-color palette)
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: No errors reported. Invalid color codes may result in undefined behavior.
- **Notes**:
    - The color code in `BL` corresponds to the VGA 16-color palette (see [Color Palette](#color-palette)).
    - The color is stored globally and used by subsequent calls to function 0x08 until changed.

## Function 0x08: Print String with Current Color

- **Description**: Prints a null-terminated string to the screen using the color previously set by function 0x07.
- **Input**:
    - `AH` = 0x08
    - `SI` = Pointer to a null-terminated string
- **Output**: None
- **Preserves**: All registers except `SI` (advanced to the end of the string)
- **Error Handling**: No errors reported. Non-null-terminated strings may cause undefined behavior.
- **Notes**:
    - Uses BIOS interrupt `INT 0x10` with `AH = 0x0E` for teletype output.
    - The color is determined by the value set by function 0x07 (stored in `current_color`).
    - Handles newline characters (`0x0A`) by outputting carriage return (`0x0D`) followed by line feed (`0x0A`).

### Function 0x0A: Get System Time

- **Description**: Returns the current system time with timezone offset applied.
- **Input**:
    - `AH` = 0x0A
- **Output**:
    - `CH` = Hours (0–23)
    - `CL` = Minutes (0–59)
    - `DH` = Seconds (0–59)
- **Preserves**: All registers except `CX`, `DX`
- **Error Handling**: No errors reported
- **Notes**: Reads the RTC via BIOS `INT 0x1A` and applies the timezone offset from `CONF.DIR/TIMEZONE.CFG`. Values are returned in binary (not BCD).

### Function 0x0B: Get System Date

- **Description**: Returns the current system date with timezone offset applied.
- **Input**:
    - `AH` = 0x0B
- **Output**:
    - `CH` = Century (e.g., 20)
    - `CL` = Year (0–99, e.g., 26 for 2026)
    - `DH` = Month (1–12)
    - `DL` = Day (1–31)
- **Preserves**: All registers except `CX`, `DX`
- **Error Handling**: No errors reported
- **Notes**: Reads the RTC via BIOS `INT 0x1A` and applies the timezone offset from `CONF.DIR/TIMEZONE.CFG`. Day boundaries are handled correctly (e.g., UTC+5 at 23:00 rolls the date forward). Values are returned in binary (not BCD).

### Function 0x0C: Clear Screen with Theme

- **Description**: Clears the screen and reapplies the user's current theme (background and foreground colors loaded from `CONF.DIR/THEME.CFG`). Use this when the caller wants the screen to look consistent with the rest of the OS.
- **Input**:
    - `AH` = 0x0C
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: No errors reported
- **Notes**: Internally calls `set_video_mode` followed by `load_and_apply_theme`. If the theme file is missing or unreadable, the screen falls back to default VGA colors.

## Color Palette

The following table lists the valid color codes for VGA mode 0x12 (16 colors):

| Code | Color Name   | RGB (0–255)     | HEX     |
|------|--------------|-----------------|---------|
| 0x00 | Black        | (0, 0, 0)       | #000000 |
| 0x01 | Dark Blue    | (0, 0, 170)     | #0000AA |
| 0x02 | Dark Green   | (0, 170, 0)     | #00AA00 |
| 0x03 | Dark Cyan    | (0, 170, 170)   | #00AAAA |
| 0x04 | Dark Red     | (170, 0, 0)     | #AA0000 |
| 0x05 | Dark Magenta | (170, 0, 170)   | #AA00AA |
| 0x06 | Brown        | (170, 85, 0)    | #AA5500 |
| 0x07 | Light Gray   | (170, 170, 170) | #AAAAAA |
| 0x08 | Dark Gray    | (85, 85, 85)    | #555555 |
| 0x09 | Blue         | (85, 85, 255)   | #5555FF |
| 0x0A | Green        | (85, 255, 85)   | #55FF55 |
| 0x0B | Cyan         | (85, 255, 255)  | #55FFFF |
| 0x0C | Red          | (255, 85, 85)   | #FF5555 |
| 0x0D | Magenta      | (255, 85, 255)  | #FF55FF |
| 0x0E | Yellow       | (255, 255, 85)  | #FFFF55 |
| 0x0F | White        | (255, 255, 255) | #FFFFFF |

---

## INT 0x22 - File System API

The File System API provides functions for managing files on a FAT12 file system, typically on a 1.44 MB floppy disk. It
uses interrupt `0x22` and handles file operations such as listing, loading, writing, and deleting files. The API assumes
filenames are in 8.3 format (e.g., `FILENAME.EXT`) and converts them to uppercase internally.

### Function 0x00: Initialize File System

- **Description**: Initializes the file system by resetting the floppy disk controller.
- **Input**:
    - `AH` = 0x00
- **Output**: None
- **Preserves**: All registers
- **Error Handling**: Sets carry flag (CF) on floppy reset failure
- **Notes**: Calls `fs_reset_floppy` to reset the floppy drive using BIOS interrupt `0x13` with `AH = 0x00`.

### Function 0x01: Get File List

- **Description**: Retrieves a comma-separated list of filenames from the root directory, along with the total size and
  file count.
- **Input**:
    - `AH` = 0x01
    - `AX` = Pointer to buffer for storing the file list (comma-separated, null-terminated)
- **Output**:
    - `BX` = Low word of total file size (in bytes)
    - `CX` = High word of total file size (32-bit size)
    - `DX` = Number of files
    - Carry flag (CF) set on error
- **Preserves**: All registers except `BX`, `CX`, `DX`
- **Error Handling**: Sets CF on disk read errors
- **Notes**: Reads the root directory (sectors 19–32) and formats filenames in 8.3 format (e.g., `FILENAME.EXT`). Skips
  deleted entries, long filename entries, and directories.

### Function 0x02: Load File

- **Description**: Loads a file from the disk into memory at a specified address.
- **Input**:
    - `AH` = 0x02
    - `SI` = Pointer to null-terminated filename (8.3 format)
    - `CX` = Memory address to load the file
- **Output**:
    - `BX` = File size (in bytes)
    - Carry flag set on error (e.g., file not found, disk error)
- **Preserves**: All registers except `BX`
- **Error Handling**: Sets CF if the file is not found or disk read fails
- **Notes**: Converts the filename to uppercase and FAT12’s 11-character format. Reads the root directory and FAT to
  locate and load file sectors.

### Function 0x03: Write File

- **Description**: Writes data from a memory buffer to a file, creating it if it doesn’t exist.
- **Input**:
    - `AH` = 0x03
    - `SI` = Pointer to null-terminated filename (8.3 format)
    - `BX` = Pointer to data buffer
    - `CX` = Size of data to write (in bytes)
- **Output**: Carry flag set on error
- **Preserves**: All registers
- **Error Handling**: Sets CF on invalid filename, disk full, or write errors
- **Notes**: Deletes the file if it exists before writing. Allocates clusters in the FAT and updates the root directory.

### Function 0x04: Check if File Exists

- **Description**: Checks if a file exists in the root directory.
- **Input**:
    - `AH` = 0x04
    - `SI` = Pointer to null-terminated filename (8.3 format)
- **Output**: Carry flag cleared if file exists, set if not found
- **Preserves**: All registers
- **Error Handling**: Sets CF if the file is not found or the filename is invalid
- **Notes**: Converts the filename to uppercase and FAT12 format before searching the root directory.

### Function 0x05: Create Empty File

- **Description**: Creates an empty file in the root directory.
- **Input**:
    - `AH` = 0x05
    - `SI` = Pointer to null-terminated filename (8.3 format)
- **Output**: Carry flag set on error
- **Preserves**: All registers
- **Error Handling**: Sets CF if the filename is invalid, the file already exists, or the root directory is full
- **Notes**: Allocates a directory entry with zero size and no clusters.

### Function 0x06: Remove File

- **Description**: Deletes a file by marking its directory entry as deleted and freeing its clusters.
- **Input**:
    - `AH` = 0x06
    - `SI` = Pointer to null-terminated filename (8.3 format)
- **Output**: Carry flag set on error
- **Preserves**: All registers
- **Error Handling**: Sets CF if the file is not found or disk write fails
- **Notes**: Marks the directory entry with `0xE5` and clears the corresponding FAT entries.

### Function 0x07: Rename File

- **Description**: Renames a file by updating its directory entry.
- **Input**:
    - `AH` = 0x07
    - `SI` = Pointer to null-terminated old filename (8.3 format)
    - `BX` = Pointer to null-terminated new filename (8.3 format)
- **Output**: Carry flag set on error
- **Preserves**: All registers
- **Error Handling**: Sets CF if the old file is not found, the new filename is invalid, or disk write fails
- **Notes**: Both filenames are converted to uppercase and FAT12 format.

### Function 0x08: Get File Size

- **Description**: Retrieves the size of a file from its directory entry.
- **Input**:
    - `AH` = 0x08
    - `SI` = Pointer to null-terminated filename (8.3 format)
- **Output**:
    - `BX` = File size (in bytes)
    - Carry flag set on error
- **Preserves**: All registers except `BX`
- **Error Handling**: Sets CF if the file is not found
- **Notes**: Reads the file size from the directory entry (offset 28).

### Function 0x09: Change Current Directory
- **Description**: Navigates into the specified directory. Supports nested subdirectories.
- **Input**:
  - `AH` = 0x09
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set on error
- **Notes**: Changes into a single directory component relative to the current directory. To navigate a multi-level path (e.g. `CONF.DIR/SUB.DIR`), call this function once per component. All filesystem operations (load, write, list, etc.) operate relative to the current directory.

### Function 0x0A: Go to Parent Directory
- **Description**: Moves the current path up one level to the parent directory using the `..` entry.
- **Input**: `AH` = 0x0A
- **Output**: CF set if already at root

### Function 0x0B: Create Directory
- **Description**: Creates a new directory entry in the current directory.
- **Input**:
  - `AH` = 0x0B
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set on error

### Function 0x0C: Remove Directory
- **Description**: Deletes an empty directory from the current directory.
- **Input**:
  - `AH` = 0x0C
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set on error

### Function 0x0D: Check if Directory
- **Description**: Determines if the specified name is a directory in the current directory.
- **Input**:
  - `AH` = 0x0D
  - `SI` = Pointer to name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set if it is a directory

### Function 0x0E: Save Current Directory
- **Description**: Saves the current directory state (path, cluster, disk, drive) to internal kernel storage.
- **Input**: `AH` = 0x0E
- **Output**: None

### Function 0x0F: Restore Current Directory
- **Description**: Restores the directory state previously saved with function 0x0E.
- **Input**: `AH` = 0x0F
- **Output**: None

### Function 0x10: Load Huge File

- **Description**: Loads a huge (> 32768bytes) file from the disk into memory at a specified address.
- **Input**:
    - `AH` = 0x10
    - `SI` = Pointer to null-terminated filename (8.3 format)
    - `CX` = load offset (position)
    - `DX` = load segment address
- **Output**:
    - Carry flag set on error (e.g., file not found, disk error)
- **Error Handling**: Sets CF if the file is not found or disk read fails
- **Notes**: Converts the filename to uppercase and FAT12’s 11-character format. Reads the root directory and FAT to
  locate and load file sectors.

### Function 0x13: Write Huge File

- **Description**: Writes a large file from an arbitrary segment:offset in memory to the current directory. Supports
  files larger than 64 KB with automatic segment boundary wrapping. If a file with the same name exists, it is
  replaced.
- **Input**:
    - `AH` = 0x13
    - `SI` = Pointer to null-terminated filename (8.3 format)
    - `CX` = source data offset
    - `DX` = source data segment
    - `BX` = file size low word (bits 0-15)
    - `DI` = file size high word (bits 16-31)
- **Output**:
    - Carry flag set on error (e.g., disk full, write error)
- **Error Handling**: Sets CF on filename conversion failure, disk write error, or FAT exhaustion
- **Notes**: Writes data in batches of up to 128 clusters (64 KB) per pass. Automatically advances the source segment
  when the offset wraps past 0xFFFF. Creates the directory entry first, then allocates clusters, builds the FAT chain,
  and writes data sectors. The 32-bit file size is stored in the directory entry (bytes 28-31).

### Function 0x14: Get current drive letter

- **Description**: When called, saves the current drive letter into the AL register.
- **Input**: `AH` = 0x14
- **Output**: `AL` = current drive letter

---

## INT 0x23 - System API

INT 0x23 is where the "operating system" part of x16-PRos lives: a heap allocator,
the hooks for launching PLE programs and steering the cooperative scheduler, and a
handful of mouse calls.

The functions fall into three groups: memory (`0x00`–`0x03`), tasks and PLE
(`0x10`–`0x19` plus `0x34`), and mouse (`0x20`–`0x26`).

### Function 0x00: Get Version

A version probe. Returns the current API version word so a program can check what
it's running against before reaching for a newer function. Right now there's only
one version, `0x0001`.

- **Input**:
    - `AH` = 0x00
- **Output**:
    - `AX` = Version word (currently `0x0001`)

### Function 0x01: Allocate Memory

Grabs a contiguous block from the kernel heap and hands back its segment. The
segment is paragraph-aligned, so offset 0 inside it is the first byte of your
block. The request is in bytes but gets rounded up to the next 16-byte paragraph;
a single block can't be larger than ~64 KiB because of the segment limit, so big
working sets need several allocations.

- **Input**:
    - `AH` = 0x01
    - `BX` = Size in bytes (1..65520)
- **Output**:
    - `AX` = Segment of the block, or 0 on failure
    - `CF` = 1 if the request couldn't be satisfied — out of memory, the descriptor
      table is full, or `BX` is outside the supported range

### Function 0x02: Free Memory

Returns a block from `0x01` to the heap. Neighbouring free blocks are coalesced, so
fragmentation doesn't pile up over an alloc/free cycle. Once freed, any pointer into
the block is dead; the memory itself is left as-is (not zeroed). A double-free is
caught and reported instead of corrupting the table.

- **Input**:
    - `AH` = 0x02
    - `AX` = Segment returned by an earlier `0x01`
- **Output**:
    - `CF` = 1 if the segment doesn't match a currently allocated block

### Function 0x03: Get Free Bytes

Reports how much room is left in the heap, as a 32-bit byte count summed over every
free block. Keep in mind this is the total, not the largest contiguous run - the
biggest allocation you can actually make may be smaller once the heap is fragmented.

- **Input**:
    - `AH` = 0x03
- **Output**:
    - `DX:AX` = Free bytes (`DX` high word, `AX` low word)

### Function 0x10: Execute PLE Program

Loads and runs a PLE (PRos Large Executable) by name. The kernel carves a fresh load
arena out of the heap, parses the header and segment table, shows the usual splash
screen, switches to the program's stack, and jumps to its entry point. When the PLE
exits, control comes back here and the arena is freed for you. The filename is copied
into a kernel scratch buffer first, so you can pass it from any data segment. The
mouse driver is held disabled while the program runs and re-enabled on the way out.
This is the supported way for one program to launch another — the foundation the
cooperative multitasking is built on.

- **Input**:
    - `AH` = 0x10
    - `DS:SI` = Pointer to a null-terminated 8.3 filename (e.g. `PAINT.PLE`)
- **Output**:
    - `CF` = 1 on a load failure — file not found, bad signature, unsupported
      version, malformed load table, or a segment that isn't paragraph-aligned.
      The kernel prints a red diagnostic in those cases.

### Function 0x11: Execute PLE Program in Background

Same loader as `0x10`, but instead of running the program inline it registers it as a
background task in the scheduler and returns straight away. The new task runs
alongside the caller, and its memory is freed automatically when it exits (via `0x12`
or by `retf`). The splash screen is skipped here. Background tasks are expected to yield
often (`0x13`, `0x14`, `0x16`); a task that never yields will starve everything else.

- **Input**:
    - `AH` = 0x11
    - `DS:SI` = Pointer to a null-terminated 8.3 filename
- **Output**:
    - `AX` = Id of the new task (1..3) on success
    - `CF` = 1 if the program couldn't be loaded, the header is invalid, or no
      background slot is free (red diagnostic on load failure)

### Function 0x12: Terminate Current Task

Ends the calling task: frees its memory, returns its slot, and switches to the next
ready task (falling back to the kernel slot if nothing else is ready). It does not
return. You can also just `retf` off the end of the program to the legacy landing
pad, but calling this explicitly is the cleaner option for new PLE programs.

- **Input**:
    - `AH` = 0x12
- **Output**: Does not return.

### Function 0x13: Cooperative Yield

Hands the CPU to the next ready task. Your full context - registers, stack pointer,
flags - is saved and restored intact when you're scheduled again.

- **Input**:
    - `AH` = 0x13
- **Output**: None (everything preserved across the yield)

### Function 0x14: Sleep N Ticks

Puts the current task to sleep until at least `CX` BIOS ticks have gone by - one tick
is about 55 ms at the usual 18.2 Hz PIT rate. Control passes to the next ready task
right away, and the sleeper is made ready again the first time the scheduler runs
after its wake tick. Wake times are computed from the 32-bit tick counter at
`0040:006C`, so midnight wraparound is handled. Called from the kernel slot it
quietly becomes a plain yield, so the kernel never blocks on its own timer.

- **Input**:
    - `AH` = 0x14
    - `CX` = Ticks to wait (0 acts like a yield)
- **Output**: None (everything preserved)

### Function 0x15: Get Current Task ID

Tells you which scheduler slot you're running in.

- **Input**:
    - `AH` = 0x15
- **Output**:
    - `AL` = Task id (0 = kernel context, 1..3 = user tasks)
    - `AH` = 0

### Function 0x16: Blocking Key Read with Yield

Waits for a keystroke, but yields to the other tasks while the keyboard buffer is
empty instead of spinning. Once a key shows up it's consumed and returned exactly as
`INT 16h`/`AH=0` would. Foreground programs should reach for this rather than a raw
`INT 16h` so background tasks keep ticking while you sit on an input prompt.

- **Input**:
    - `AH` = 0x16
- **Output**:
    - `AX` = Scan code (high) / ASCII (low), as from `INT 16h`/`AH=0`

### Function 0x17: Query Task Slot

Looks up the state, flags, and arena segment of a given slot - handy for a task
manager or a `ps`-style listing.

- **Input**:
    - `AH` = 0x17
    - `BL` = Task id (0..3)
- **Output**:
    - `AL` = State: 0 = free, 1 = ready, 2 = running, 3 = sleeping
    - `AH` = Flags: bit 0 = background, bit 7 = kernel slot
    - `CX` = Base segment of the task's arena (kernel `CS` for slot 0, 0 for a free slot)
    - `DL` = Parent task id, or `0xFF` when the task has no parent
    - `CF` = 1 if `BL` is out of range

### Function 0x18: Kill Task by Id

Terminates another task by id, freeing its arena and releasing the slot. To end
*yourself*, use `0x12` or `retf` instead - this call deliberately refuses to kill the kernel
slot, the caller, or a slot that's already free.

- **Input**:
    - `AH` = 0x18
    - `BL` = Task id (0..3)
- **Output**:
    - `CF` = 0 on success
    - `CF` = 1 on failure (kernel slot, self, or a free slot)

### Function 0x19: Get Task Name

Copies a task's executable filename —-the one it was launched with - into a buffer
you supply. The name is written into your own data segment, NUL-terminated, and
truncated to 15 characters plus the terminator, so the buffer needs to be at least
16 bytes. Slot 0 reports back as `KERNEL`.

- **Input**:
    - `AH` = 0x19
    - `BL` = Task id (0..3)
    - `DI` = Offset of the destination buffer in your `DS` (≥ 16 bytes)
- **Output**:
    - Buffer at `DS:DI` filled with the NUL-terminated name
    - `CF` = 1 if `BL` is out of range

### Function 0x20: Mouse Get State

Reads the mouse in one shot: pixel position, which buttons are down, and whether the
cursor is currently drawn. Coordinates stay clamped to the visible area of VGA mode
0x12 (640x480, 16 colors).

- **Input**:
    - `AH` = 0x20
- **Output**:
    - `AX` = X (0..631)
    - `BX` = Y (0..468)
    - `CL` = Button mask (bit 0 = LMB, bit 1 = RMB, bit 2 = MMB)
    - `CH` = Cursor visibility (0 = hidden, 1 = visible)

### Function 0x21: Mouse Get Text Cell

The same position as `0x20`, but snapped to the 8x16 text grid (80 columns by 30
rows). This is the convenient form for hit-testing a text-mode UI.

- **Input**:
    - `AH` = 0x21
- **Output**:
    - `AX` = Column (0..79)
    - `BX` = Row (0..29)

### Function 0x22: Mouse Hide Cursor

Hides the cursor sprite and restores the pixels it was covering. Mouse motion stops
drawing the cursor until you call `0x23`. Calling it when the cursor is already hidden
does nothing.

- **Input**:
    - `AH` = 0x22
- **Output**: None

### Function 0x23: Mouse Show Cursor

Brings the cursor back at its current position. A no-op if it's already showing.

- **Input**:
    - `AH` = 0x23
- **Output**: None

### Function 0x24: Mouse Enable / Disable

Turns the whole PS/2 mouse callback on or off. While it's disabled, no motion or
button events are delivered at all. A program that wants to talk to the mouse with its
own protocol usually disables the kernel handler on entry and switches it back on
when it exits.

- **Input**:
    - `AH` = 0x24
    - `AL` = 1 to enable, 0 to disable
- **Output**: None

### Function 0x25: Mouse Drag-Select Enable / Disable

Toggles the kernel's built-in drag-select rectangle — the XOR-inverted box it draws
while the left button is held. Graphical programs that want to interpret drags
themselves can switch this off so the selection overlay stays out of their way.

- **Input**:
    - `AH` = 0x25
    - `AL` = 1 to enable, 0 to disable
- **Output**: None

### Function 0x26: Set Cursor Shape

Swaps the sprite the driver draws for the mouse pointer.

- **Input**:
    - `AH` = 0x26
    - `AL` = 0 for the arrow, non-zero for the resize shape
- **Output**: None

### Function 0x34: Reparent a Task

Points a task's parent link at a different slot.

Only the parent field is touched; state, flags and arena are left alone.

- **Input**:
    - `AH` = 0x34
    - `BL` = Task id to reparent (0..3)
    - `BH` = New parent task id (`0xFF` for none)
- **Output**:
    - `CF` = 1 if `BL` is out of range or names a free slot

---

## License

The x16-PRos operating system and its API are licensed under the MIT License. See the LICENSE.TXT for details.

**Author**: PRoX (https://github.com/PRoX2011)
**Version**: 0.4, 0.5, 0.6, 0.7, 0.8, 0.9