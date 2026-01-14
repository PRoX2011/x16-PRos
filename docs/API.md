# x16-PRos API Documentation

## Overview

The x16-PRos operating system provides a set of interrupt-driven APIs for developers to interact with the system. These
APIs are organized into three categories, each accessible via a specific interrupt:

- **INT 0x21**: Output API for screen output and video mode initialization.
- **INT 0x22**: File System API for managing files on a FAT12 file system.

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

- **Description**: Clears the screen by resetting the VGA video mode to 640x480 with 16 colors.
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
- **Description**: Navigates into the specified directory.
- **Input**: 
  - `AH` = 0x09
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR) 
- **Output**: CF set on error

### Function 0x0A: Go to Parent Directory
- **Description**: Moves the current path up one level to the parent directory.
- **Input**: `AH` = 0x0A
- **Output**: CF set on error

### Function 0x0B: Create Directory
- **Description**: Creates a new directory entry on the disk.
- **Input**: 
  - `AH` = 0x0B
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set on error

### Function 0x0C: Remove Directory
- **Description**: Deletes an empty directory.
- **Input**: 
  - `AH` = 0x0C
  - `SI` = Pointer to directory name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set on error

### Function 0x0D: Check if Directory
- **Description**: Determines if the specified name is a directory.
- **Input**: 
  - `AH` = 0x0D
  - `SI` = Pointer to name in 8.3 format (e.g TEST.DIR; CONF.DIR; BIN.DIR)
- **Output**: CF set if it is a directory

### Function 0x0E: Save Current Directory
- **Description**: Saves the current directory state to internal kernel storage.
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

---

## Usage Notes

- **Environment**: The x16-PRos API is designed for a 16-bit real-mode x86 environment, running on a 1.44 MB floppy disk
  with a FAT12 file system and VGA video mode (640x480, 16 colors).
- **Filename Format**: File system functions expect filenames in 8.3 format (e.g., `FILENAME.EXT`). Filenames are
  case-insensitive and converted to uppercase internally.
- **Error Handling**: Most functions set the carry flag (CF) to indicate errors. Check the CF after calling file system
  functions to handle errors appropriately.
- **Register Preservation**: Functions preserve registers unless explicitly used for output, using `pusha`/`popa` or
  temporary storage.
- **Interrupts**: Ensure interrupts are enabled (`sti`) before calling API functions, as they rely on BIOS interrupts (
  `0x10`, `0x13`, `0x1A`, etc.).
- **Memory Management**: Buffers for file operations (e.g., `fs_get_file_list`, `fs_load_file`) must be large enough to
  hold the data. The kernel uses fixed buffers like `dirlist` (1024 bytes) and `file_buffer` (32768 bytes).
- **Limitations**:
    - File sizes are limited to 16-bit values (65,535 bytes) in some functions.
    - The root directory is limited to 224 entries (FAT12 limitation).
    - String functions assume null-terminated strings and may have buffer size limits (e.g., 255 characters for keyboard
      input).

---

## License

The x16-PRos operating system and its API are licensed under the MIT License. See the LICENSE.TXT for details.

**Author**: PRoX (https://github.com/PRoX2011)  
**Version**: 0.4, 0.5, 0.6