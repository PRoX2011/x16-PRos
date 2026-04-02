# FatBoot Bootloader Documentation

## Overview

The x16-PRos operating system uses the FatBoot bootloader (https://github.com/invin1x/FatBoot).

FatBoot is a 16-bit real-mode program that loads the operating system kernel file from a FAT12-formatted
drive into memory and transfers control to it. It resides in the boot sector (first 512 bytes of the drive)
and is executed by the BIOS upon system startup. The bootloader uses BIOS interrupts to read disk sectors
and navigate the FAT12 file system to locate and load the kernel.

## Purpose

The primary functions of the bootloader are:

1. Initialize the system environment (segment registers and stack).
2. Read the disk and filesystem configuration.
3. Read the FAT12 root directory to locate the kernel.
4. Read the kernel's data clusters into memory, using File Allocation Table (FAT).
5. Transfer control to the loaded kernel.
6. Handle errors, such as a missing kernel file or a bad cluster, by displaying a message and rebooting.

## Operational Principles

The bootloader operates in the following stages:

### 1. Initialization

- **Segment Setup**: The bootloader sets the data segment (`DS`), extra segment (`ES`), and stack segment (`SS`)
  to `0x0000`, and stack pointer (`SP`) to `0x500 + 64`.
- **Boot Sector Relocation**: The bootloader copies itself to `0x500 + 64`, right above IVT, BDA, and stack, and then jumps there.

### 2. Reading the Root Directory

- **Calculation**: After initialization, the bootloader calculates and saves FAT LBA, root directory LBA, and data area LBA,
  using the following formulas:
    - FAT_LBA = `BPB_reserved_sectors` + `BPB_partition_LBA`.
    - Root_directory_LBA = FAT_LBA + `BPB_sectors_per_FAT` * `BPB_num_fats`.
    - Data_area_LBA = Root_directory_LBA + `BPB_root_entries` * 32 / `BPB_bytes_per_sector`.
- **Disk Read**: Then the bootloader reads the root directory sectors into memory at `0x0000:0x1000` using the `read_disk` procedure, which
  calls BIOS interrupt `0x13` (function `0x42` or `0x02` as fallback).

### 3. Locating the Kernel

- **Search**: Scans the root directory (`BPB_root_entries` entries) at `0x0000:0x1000` for the kernel by comparing each
  entry’s 11-byte filename field with the string defined at assembly time (see below).
- **Match**: If found, checks flags (offset 0xB), retrieves the file’s starting cluster from the directory entry (offset 0x1A) and
  starts reading it.

### 4. Loading the Kernel

- **Cluster Chain**: Iteratively loads the kernel’s clusters:
    - Calculates the required FAT sector, and loads it to `FAT_BUFFER` using `read_disk` procedure.
    - Gets the next cluster number and checks if it is correct.
    - Reads one cluster at a time into `LOAD_ADDRESS + READ_SECTORS` (incrementing the `READ_SECTORS` by `BPB_sectors_per_cluster`) using
      `read_disk` procedure.

### 5. Transferring Control

- **Jump**: After loading all clusters, transfers control to the kernel using a far jump.
- **Environment**: The kernel is executed in a 16-bit real-mode environment with all registers expected to
  be set by the kernel itself.

### 6. Error Handling

- If any error occurs, the bootloader displays an error message and reboots after a keypress.

## Key Functions

### `read_disk`

- **Purpose**: Reads the specified number of sectors from the disk to the specified buffer,
  using BIOS interrupt `0x13`, function `0x42`. If an error has occurred, it tries to convert the
  given LBA address to CHS, and read sectors again using legacy function `0x02`.
- **Input**:
    - `DX:AX` = LBA.
    - `CX` = Sectors to read.
    - `ES:BX` = Buffer address.
    - `[DISK]` = Disk number.
- **Output**: `AX`, `BX`, `CX`, `DX`, `SI` and `DI` are not saved, and `DS` is set to 0.

### `error`

- **Purpose**: Displays the error message and waits for a keypress to reboot.

## Configuration

- To configure FatBoot, define these macros during assembling:
    - `FILENAME` - The name of the file to load (8.3 format).
    - `LOAD_SEGMENT` - The segment where the file will be loaded.
    - `LOAD_OFFSET` - The offset at which the file will be loaded.
    - `JMP_SEGMENT` - The segment to jump to after loading.
    - `JMP_OFFSET` - The offset to jump to after loading.

## License

The FatBoot bootloader is licensed under the MIT License.

**Author**: Alexander Zubov <alextop1bb@gmail.com> (https://github.com/invin1x)
