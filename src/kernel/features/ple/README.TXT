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
  | 0x00   |   3  | magic 'P','L','E'                   |
  | 0x03   |   1  | header flags (see below)           |
  | 0x04   |   2  | version                            |
  | 0x06   |   2  | entry rel-seg id                   |
  | 0x08   |   2  | entry IP                           |
  | 0x0A   |   2  | stack rel-seg id                   |
  | 0x0C   |   2  | stack SP (loader sizes the arena   |
  |        |      | from this before allocating)       |
  | 0x0E   |   2  | load-table entry count             |
  | 0x10   |  32  | description                        |
  | 0x30   |  16  | author                             |
  +--------+------+------------------------------------+

  Header flags (byte at offset 0x03):
    bit 0  PLE_FLAG_NO_SPLASH  skip the splash before launch
    bit 1  PLE_FLAG_NO_WAIT    show splash but do not wait for a key
    bits 2..7 reserved, must be 0

  If the flags byte is 0 (3-arg PLE_HEADER), behavior is the legacy
  one: splash is drawn and the loader waits for a keypress.

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
  | BASE:0x0000       | PLE header                    |
  | BASE:0x0040       | logo (used by splash)         |
  | BASE:0x1040       | load table                    |
  | BASE:0x1050+      | segment data, one after       |
  |                   | another, paragraph-aligned    |
  | after the image   | the stack segment             |
  +-------------------+-------------------------------+

============================================================
 Registers on entry
============================================================

  CS = DS = the program's segment 0
  SS:SP   = the program's stack
  ES      = kernel data segment
  SI      = pointer to the command line args, in ES

============================================================
 Segments
============================================================

  Segment 0 holds the code and opens by itself. Extra segments are
  opened with PLE_SEGMENT and each one can be up to 64 KiB.

  Segments are written one after another and each ends where the
  next begins, so do not reopen an earlier one.

      PLE_SEGMENT tables
      big_table   times 40000 db 0

  To reach a segment at run time, add its distance in paragraphs to
  CS. PLE_SEG works that distance out while assembling, there is
  nothing to look up:

      mov ax, cs
      add ax, PLE_SEG(tables)
      mov es, ax

  or the same thing in one line, which clobbers AX:

      PLE_LOAD_SEG es, tables

  PLE_DATA is the old spelling of PLE_SEGMENT data.

  Every byte of every segment sits in the file, so a segment full of
  zeroes costs that many bytes on disk.

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
