============================================================
 PLE - PRos Large Executable
============================================================

A multi-segment executable format for x16-PRos. The whole
file is loaded contiguously into PLE_BASE_SEG (0x3000) by
fs_load_huge_file, so it can span more than 64 KiB. 

============================================================
 File layout
============================================================

  +--------+--------+----------------------------------+
  | offset |  size  | content                          |
  +--------+--------+----------------------------------+
  | 0x0000 |    64  | header                           |
  | 0x0040 |  4096  | logo (64x64, 1 byte/pixel, EGA)  |
  | 0x1040 |  N x 8 | load table                       |
  | ...... |    ..  | segment data (paragraph-aligned) |
  +--------+--------+----------------------------------+

============================================================
 Header (64 bytes)
============================================================

  +--------+------+------------------------------------+
  | offset | size | field                              |
  +--------+------+------------------------------------+
  | 0x00   |   4  | magic 'P','L','E',0                |
  | 0x04   |   2  | version                            |
  | 0x06   |   2  | entry rel-seg id                   |
  | 0x08   |   2  | entry IP                           |
  | 0x0A   |   2  | stack rel-seg id                   |
  | 0x0C   |   2  | stack SP                           |
  | 0x0E   |   2  | load-table entry count             |
  | 0x10   |  32  | description                        |
  | 0x30   |  16  | author                             |
  +--------+------+------------------------------------+

============================================================
 Load-table entry (8 bytes)
============================================================

  +--------+------+------------------------------------+
  | offset | size | field                              |
  +--------+------+------------------------------------+
  | +0     |   2  | rel-seg id (identifier, not addr)  |
  | +2     |   4  | file offset of segment data        |
  |        |      | (dword, must be paragraph-aligned) |
  | +6     |   2  | segment size in bytes              |
  +--------+------+------------------------------------+

============================================================
 Memory layout at run time
============================================================

  +-------------------+-------------------------------+
  | segment:offset    | content                       |
  +-------------------+-------------------------------+
  | 0x3000:0x0000     | PLE header                    |
  | 0x3000:0x0040     | logo (used by splash)         |
  | 0x3000:0x1040     | load table                    |
  | 0x3000:0x1050+    | segment data                  |
  +-------------------+-------------------------------+

============================================================
 Building a PLE program
============================================================

  %include "ple.inc"

  PLE_HEADER  start, "Description", "Author"
  PLE_LOGO    "logo/MYPROG.raw"

  start:
      push cs
      pop  ds
      mov  ah, 0x01
      mov  si, msg
      int  0x21
      retf

  msg db 'Hello from PLE!', 10, 13, 0

  PLE_END

  Assemble with:
      nasm -f bin -I programs/PLE/ src/MYPROG.asm -o MYPROG.PLE
