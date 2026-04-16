; ========================================================================
; mz.inc -- MZ EXE header generator for x16-PRos
; ========================================================================
; Usage:
;   %include "mz.inc"
;   MZ_HEADER start         ; pass your entry point label
;
;   start:
;       mov dx, hello_msg   ; offsets are automatic, no corrections needed
;       mov ah, 0x09
;       int 0x21
;       mov ah, 0x4C
;       int 0x21
;
;   hello_msg db 'Hello!$'
;   MZ_END
; ========================================================================

[BITS 16]

%define __MZ_HDR_PARAS 2
%define __MZ_HDR_BYTES (__MZ_HDR_PARAS * 16)

; --- MZ_HEADER entry_point ---
; Emits 32-byte MZ header, then starts code with vstart=0
; so all code/data labels are runtime offsets (no manual subtraction)
%macro MZ_HEADER 1

; We use SECTION with vstart so code labels start at 0.
; The x16-PRos EXE loader ignores page count/last page fields
; (it loads the whole file via fs_load_huge_file),
; so... we hardcode them to safe values :)

SECTION .mzhdr progbits start=0
__mz_hdr:
    dw 0x5A4D                   ; +00h Signature 'MZ'
    dw 0x0000                   ; +02h Bytes on last page (unused by loader)
    dw 0x0000                   ; +04h Total pages (unused by loader)
    dw 0                        ; +06h Relocation entries
    dw __MZ_HDR_PARAS           ; +08h Header size in paragraphs
    dw 0x0010                   ; +0Ah Min extra paragraphs
    dw 0xFFFF                   ; +0Ch Max extra paragraphs
    dw 0x0000                   ; +0Eh Initial SS
    dw 0xFFFE                   ; +10h Initial SP
    dw 0x0000                   ; +12h Checksum
    dw %1                       ; +14h Initial IP (label from vstart=0 section)
    dw 0x0000                   ; +16h Initial CS
    dw __MZ_HDR_BYTES           ; +18h Relocation table offset
    dw 0x0000                   ; +1Ah Overlay number
    times __MZ_HDR_BYTES - ($ - __mz_hdr) db 0

SECTION .text follows=.mzhdr vstart=0

%endmacro

; --- MZ_END ---
; Place at the very end of your source
%macro MZ_END 0

%endmacro