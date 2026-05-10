; ========================================================================
; ple.inc -- PLE (PRos Large Executable) header generator for x16-PRos
; ========================================================================
; Usage:
;   %include "ple.inc"
;
;   PLE_HEADER entry, "My program", "Author"
;   PLE_LOGO   "logo.raw"             ; 4096 bytes (64x64, 1bpp-byte)
;
;   PLE_CODE                          ; opens relative segment 0 (code+data)
;   entry:
;       mov ah, 0x09
;       mov dx, hello
;       int 0x21
;       retf
;
;   hello db 'Hello from PLE!', 13, 10, '$'
;
;   PLE_END
; ========================================================================

[BITS 16]

; ----- PLE_HEADER entry_label, "description", "author" -----
%macro PLE_HEADER 3
SECTION .plehdr progbits start=0
__ple_hdr_start:
    db 'P','L','E',0                  ; +0x00 magic
    dw 1                              ; +0x04 version
    dw 0                              ; +0x06 entry segment (relative 0)
    dw %1                             ; +0x08 entry IP
    dw 0                              ; +0x0A stack segment (relative 0)
    dw 0xFFFE                         ; +0x0C stack SP
    dw __ple_seg_count                ; +0x0E instruction count
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
%endmacro

; ----- PLE_CODE -----
%macro PLE_CODE 0
    SECTION .pleseg_code
%endmacro

; ----- PLE_DATA -----
%macro PLE_DATA 0
%define __ple_has_data
    SECTION .pleseg_code
__ple_code_end:
    SECTION .pleseg_data progbits follows=.pleseg_code vstart=0 align=16
__ple_data_start:
%endmacro

; ----- PLE_END -----
%macro PLE_END 0
    %ifdef __ple_has_data
        SECTION .pleseg_data
__ple_data_end:
    %else
        SECTION .pleseg_code
__ple_code_end:
    %endif

    ; Fill the load instruction table.
    SECTION .pletbl
        dw 0                                     ; rel seg 0 (code)
        dd section..pleseg_code.start
        dw __ple_code_end - __ple_code_start
    %ifdef __ple_has_data
        dw 1                                     ; rel seg 1 (data)
        dd section..pleseg_data.start
        dw __ple_data_end - __ple_data_start
        __ple_seg_count equ 2
    %else
        __ple_seg_count equ 1
    %endif
%endmacro
