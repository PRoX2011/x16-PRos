# x16-PRos Bootloader Documentation

## Overview
The x16-PRos bootloader is a 16-bit real-mode program that loads the operating system kernel (`KERNEL.BIN`) from a FAT12-formatted 1.44 MB floppy disk into memory at address `0x2000:0x0000` and transfers control to it. It resides in the boot sector of the floppy disk (first 512 bytes) and is executed by the BIOS upon system startup. The bootloader uses BIOS interrupts to read disk sectors and navigate the FAT12 file system to locate and load the kernel.

## Purpose
The primary functions of the bootloader are:
1. Initialize the system environment (segment registers and stack).
2. Read the FAT12 root directory to locate the `KERNEL.BIN` file.
3. Load the File Allocation Table (FAT) to determine the kernel's disk clusters.
4. Read the kernel's data clusters into memory.
5. Transfer control to the loaded kernel.
6. Handle errors, such as a missing kernel file, by displaying a message and rebooting.

## Operational Principles
The bootloader operates in the following stages:

### 1. Initialization
- **Segment Setup**: The bootloader sets the data segment (`DS`), extra segment (`ES`), file segment (`FS`), and general segment (`GS`) to `0x07C0`, the segment where the boot sector is loaded by the BIOS. The stack segment (`SS`) is set to `0x0000`, with the stack pointer (`SP`) initialized to `0xFFFF` for a descending stack.
- **Interrupts**: Interrupts are disabled (`cli`) during segment setup and re-enabled (`sti`) afterward to allow BIOS interrupt calls.
- **Output**: Displays a "Loading Boot Image" message using BIOS interrupt `0x10` (function `0x0E`) to indicate the start of the boot process.

### 2. Reading the Root Directory
- **Calculation**: Computes the starting sector of the root directory using the FAT12 Boot Parameter Block (BPB):
  - Root directory size = `bpbRootEntries` (224) * 32 bytes per entry / `bpbBytesPerSector` (512) = number of sectors.
  - Start sector = `bpbReservedSectors` (1) + (`bpbNumberOfFATs` (2) * `bpbSectorsPerFAT` (9)).
  - Stores the data sector start (after root directory) in `datasector`.
- **Disk Read**: Reads the root directory sectors into memory at `0x07C0:0x0200` using the `ReadSectors` function, which calls BIOS interrupt `0x13` (function `0x02`).
- **Error Handling**: Retries up to 5 times on disk read failure, resetting the floppy drive (`int 0x13`, `AH = 0x00`) between attempts. If all retries fail, jumps to `FAILURE`.

### 3. Locating the Kernel
- **Search**: Scans the root directory (224 entries) at `0x07C0:0x0200` for the file `KERNEL.BIN` by comparing each entry’s 11-byte filename field with the string `"KERNEL  BIN"`.
- **Match**: If found, retrieves the file’s starting cluster from the directory entry (offset 0x1A) and stores it in `cluster`.
- **Failure**: If no match is found, displays an error message ("KERNEL.BIN not found") and waits for a keypress before rebooting via `int 0x19`.

### 4. Loading the FAT
- **Calculation**: Reads the FAT (9 sectors per copy, 2 copies) starting at `bpbReservedSectors` (1) into `0x07C0:0x0200`.
- **Disk Read**: Uses `ReadSectors` to load the FAT, with retries and error handling as in the root directory read.
- **Purpose**: The FAT is used to determine the chain of clusters containing the kernel’s data.

### 5. Loading the Kernel
- **Cluster Chain**: Iteratively loads the kernel’s clusters:
  - Converts the current cluster number (from `cluster`) to a Logical Block Address (LBA) using `ClusterLBA`, which accounts for the data area’s offset (`datasector`).
  - Converts the LBA to Cylinder-Head-Sector (CHS) format using `LBACHS` for BIOS disk reads.
  - Reads one sector at a time into `0x2000:0x0000` (incrementing the offset by 512 bytes per sector) using `ReadSectors`.
  - Retrieves the next cluster from the FAT:
    - For even-numbered clusters: Takes the low 12 bits of the FAT entry.
    - For odd-numbered clusters: Takes the high 12 bits (shifted right by 4).
  - Continues until a cluster value ≥ `0x0FF0` (end-of-file marker) is encountered.
- **Output**: Displays a progress dot (`.`) for each sector read.

### 6. Transferring Control
- **Jump**: After loading all clusters, displays a newline (`msgCRLF`) and transfers control to the kernel at `0x2000:0x0000` using a far return (`retf`) with the stack set up to point to this address.
- **Environment**: The kernel is executed in a 16-bit real-mode environment with `DS`, `ES`, `FS`, and `GS` expected to be set by the kernel itself.

### 7. Error Handling
- **Disk Errors**: The `ReadSectors` function retries disk reads up to 5 times, resetting the floppy drive on failure. Persistent failures trigger a reboot via `int 0x18`.
- **File Not Found**: If `KERNEL.BIN` is not found, the bootloader displays an error message and reboots after a keypress.
- **Progress Feedback**: Progress dots and messages are displayed to inform the user of the loading process.

## Key Functions
### `Print`
- **Purpose**: Outputs a null-terminated string to the screen using BIOS interrupt `0x10` (function `0x0E`).
- **Input**: `SI` = Pointer to string.
- **Output**: Characters displayed on the screen.

### `ClusterLBA`
- **Purpose**: Converts a FAT12 cluster number to an LBA.
- **Input**: `AX` = Cluster number.
- **Output**: `AX` = LBA of the cluster’s first sector.
- **Formula**: LBA = (cluster - 2) * `bpbSectorsPerCluster` + `datasector`.

### `LBACHS`
- **Purpose**: Converts an LBA to CHS format for BIOS disk reads.
- **Input**: `AX` = LBA.
- **Output**: 
  - `absoluteSector` = Sector number (1-based).
  - `absoluteHead` = Head number.
  - `absoluteTrack` = Cylinder number.
- **Formula**:
  - Sector = (LBA % `bpbSectorsPerTrack`) + 1.
  - Cylinder = (LBA / `bpbSectorsPerTrack`) / `bpbHeadsPerCylinder`.
  - Head = (LBA / `bpbSectorsPerTrack`) % `bpbHeadsPerCylinder`.

### `ReadSectors`
- **Purpose**: Reads one or more sectors from the disk into memory.
- **Input**:
  - `AX` = Starting LBA.
  - `BX` = Memory offset to load data (in `ES`).
  - `CX` = Number of sectors to read.
- **Output**: Data loaded into `ES:BX`, with `BX` incremented by 512 bytes per sector.
- **Error Handling**: Retries up to 5 times on failure, resetting the drive. Triggers `int 0x18` on persistent failure.

## BPB (Boot Parameter Block)
The BPB defines the FAT12 file system parameters:
- **OEM Identifier**: `"x16-PRos"`
- **Bytes per Sector**: 512
- **Sectors per Cluster**: 1
- **Reserved Sectors**: 1 (boot sector)
- **Number of FATs**: 2
- **Root Entries**: 224
- **Total Sectors**: 2880 (1.44 MB floppy)
- **Media Descriptor**: `0xF0` (removable)
- **Sectors per FAT**: 9
- **Sectors per Track**: 18
- **Heads per Cylinder**: 2
- **Drive Number**: 0 (auto-detected)
- **Extended Boot Signature**: `0x29`
- **Serial Number**: `0xa0a1a2a3`
- **Volume Label**: `"FLOPPY "`
- **File System Type**: `"FAT12   "`

## Memory Layout
- **Boot Sector**: Loaded at `0x07C0:0x0000` (physical address `0x7C00`).
- **Root Directory and FAT**: Loaded at `0x07C0:0x0200`.
- **Kernel**: Loaded at `0x2000:0x0000`.
- **Stack**: Grows downward from `0x0000:0xFFFF`.

## Limitations
- **File Name**: Hardcoded to `KERNEL.BIN` (11-byte FAT12 format).
- **Disk Size**: Assumes a 1.44 MB floppy disk (2880 sectors).
- **Error Handling**: Limited to retrying disk reads and rebooting on failure.
- **Memory**: Kernel must fit within the memory starting at `0x2000:0x0000` and handle its own segment setup.

## Example Flow
1. BIOS loads the boot sector at `0x7C00`.
2. Bootloader initializes segments and stack, displays "Loading Boot Image".
3. Reads the root directory (sectors 19–32) into `0x07C0:0x0200`.
4. Searches for `KERNEL.BIN` and retrieves its starting cluster.
5. Reads the FAT (sectors 1–18) into `0x07C0:0x0200`.
6. Loads the kernel’s clusters into `0x2000:0x0000`, following the FAT chain.
7. Jumps to `0x2000:0x0000` to execute the kernel.
8. On failure, displays an error and reboots.

## License
The x16-PRos bootloader is licensed under the MIT License. See the LICENSE.TXT for details.

**Author**: PRoX (https://github.com/PRoX2011)  
**Version**: 0.4  