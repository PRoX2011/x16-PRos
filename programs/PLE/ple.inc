; ========================================================================
; ple.inc -- PLE (PRos Large Executable) header generator for x16-PRos
; ========================================================================
; Usage:
;   %include "ple.inc"
;
;   PLE_HEADER entry, "My program", "Author"
;   PLE_HEADER entry, "My program", "Author", PLE_FLAG_NO_SPLASH
;   PLE_HEADER entry, "My program", "Author", 0, 16384   ; 16 KiB stack
;   PLE_LOGO   "logo.raw"             ; 4096 bytes (64x64, 1bpp-byte)
;
;   entry:                            ; segment 0 opens here
;       mov ah, 0x01
;       mov si, hello
;       int 0x21
;       retf
;
;   hello db 'Hello from PLE!', 13, 10, 0
;
;   PLE_SEGMENT tables                ; a second segment, up to 64 KiB
;   big_table times 40000 db 0
;
;   PLE_END
;
; Header flags (4th PLE_HEADER argument, default 0 = splash + wait for key):
;   PLE_FLAG_NO_SPLASH (0x01) - skip the splash screen entirely
;   PLE_FLAG_NO_WAIT   (0x02) - show splash but do not wait for a key
; Background launches (BG / INT 0x23 AH=0x11) always skip the splash
; regardless of these flags.
; ========================================================================

[BITS 16]

PLE_FLAG_NO_SPLASH equ 0x01
PLE_FLAG_NO_WAIT   equ 0x02

%define PLE_DEFAULT_STACK 8192
%define PLE_FULL_SEGMENT  0xFFFF

; ----- PLE_SEG(name) -----
; Paragraphs from segment 0 to the named segment, known at assembly time.
;   mov ax, cs
;   add ax, PLE_SEG(tables)
;   mov es, ax
%define PLE_SEG(name) (__ple_par_ %+ name)

; ----- PLE_LOAD_SEG sreg, name -----
; Loads a segment register with the named segment. Clobbers AX.
%macro PLE_LOAD_SEG 2
    mov ax, cs
    add ax, PLE_SEG(%2)
    mov %1, ax
%endmacro

; ----- PLE_HEADER entry_label, "description", "author" [, flags [, stack]] -----
%macro PLE_HEADER 3-5 0, PLE_DEFAULT_STACK
%define __ple_stack_bytes (%5)
SECTION .plehdr progbits start=0
__ple_hdr_start:
    db 'P','L','E',%4                 ; +0x00 magic 'PLE' + flags byte
    dw 1                              ; +0x04 version
    dw 0                              ; +0x06 entry segment (always 0)
    dw %1                             ; +0x08 entry IP
    dw __ple_stack_seg                ; +0x0A stack rel-seg id
    dw __ple_stack_sp                 ; +0x0C stack SP
    dw __ple_seg_count                ; +0x0E load-table entry count
__ple_desc_start:                     ; +0x10 description (32 B)
    db %2, 0
    times 32 - ($ - __ple_desc_start) db 0
__ple_auth_start:                     ; +0x30 author (16 B)
    db %3, 0
    times 16 - ($ - __ple_auth_start) db 0
__ple_logo_at:                        ; +0x40 logo (4096 B)
%endmacro

; ----- PLE_LOGO "filename.raw" -----
; 4096 bytes raw 64x64 image.
%macro PLE_LOGO 1
__ple_logo_start:
    incbin %1
__ple_logo_end:
%if (__ple_logo_end - __ple_logo_start) > 4096
    %error "PLE logo is larger than 4096 bytes"
%endif
    times 4096 - (__ple_logo_end - __ple_logo_start) db 0

    SECTION .pletbl progbits follows=.plehdr
__ple_tbl_start:

    SECTION .pleseg_code progbits follows=.pletbl vstart=0 align=16
__ple_code_start:
%assign __ple_nseg 1
%xdefine __ple_last_sect .pleseg_code
%xdefine __ple_last_name code
__ple_par_code equ 0
%endmacro

; ----- __PLE_CLOSE_SEG -----
; Ends the segment that is open and writes its load-table entry.
%macro __PLE_CLOSE_SEG 0
    align 16
__ple_len %+ __ple_nseg equ ($ - $$)
%if (__ple_len %+ __ple_nseg) > 0x10000
    %error "a PLE segment cannot be larger than 64 KiB"
%endif
    SECTION .pletbl
        dw __ple_nseg - 1                        ; rel-seg id
        dd section. %+ __ple_last_sect %+ .start ; file offset
        dw __ple_len %+ __ple_nseg               ; size in bytes
%endmacro

; ----- PLE_CODE -----
; Kept for older sources. Segment 0 is already open after PLE_LOGO.
%macro PLE_CODE 0
    SECTION .pleseg_code
%endmacro

; ----- PLE_SEGMENT name -----
; Opens another segment. Segments are written one after another, each one
; ends where the next begins.
%macro PLE_SEGMENT 1
    __PLE_CLOSE_SEG
__ple_par_ %+ %1 equ __ple_par_ %+ __ple_last_name + ((__ple_len %+ __ple_nseg) >> 4)
    %assign __ple_nseg __ple_nseg + 1
    SECTION .pleseg_ %+ %1 progbits follows=__ple_last_sect vstart=0 align=16
    %xdefine __ple_last_sect .pleseg_ %+ %1
    %xdefine __ple_last_name %1
%endmacro

; ----- PLE_DATA -----
%macro PLE_DATA 0
    PLE_SEGMENT data
%endmacro

; ----- PLE_END -----
%macro PLE_END 0
    __PLE_CLOSE_SEG

%if __ple_stack_bytes == PLE_FULL_SEGMENT
    %if __ple_nseg != 1
        %error "PLE_FULL_SEGMENT leaves no room for extra segments"
    %endif
__ple_stack_seg equ 0
__ple_stack_sp  equ 0xFFFE
__ple_seg_count equ __ple_nseg
%else
__ple_stack_seg equ __ple_nseg
__ple_stack_sp  equ ((__ple_stack_bytes) + 15) & ~15
    %if __ple_stack_sp > 0xFFFE
        %error "PLE stack does not fit in one 64 KiB segment"
    %endif
    SECTION .pletbl
        dw __ple_nseg
        dd section. %+ __ple_last_sect %+ .start + (__ple_len %+ __ple_nseg)
        dw 0
__ple_seg_count equ __ple_nseg + 1
%endif
%endmacro
