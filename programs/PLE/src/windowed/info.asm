; ==================================================================
; x16-PRos -- INFO. About x16-PRos.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

; TODO: Add buttons to open documentation from 
;       DOCS.DIR/EN(RU.DIR)/* within the VIEW.PLE program (also TODO)

%include "ple.inc"

PLE_HEADER start, "About x16-PRos", "PRoX-dev"
PLE_LOGO          "logo/info.raw"

start:
    push cs
    pop ds
    push cs
    pop es

    call surf_sync
    cmp byte [surf_windowed], 1
    jne .fullscreen

    call redraw
.wloop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .quit
    cmp byte [surf_dirty], 0
    je .sleep
    call redraw
.sleep:
    mov ah, 0x14
    mov cx, 5
    int 0x23
    jmp .wloop
.quit:
    mov ah, 0x12
    int 0x23
    jmp .quit

.fullscreen:
    call paint
.wait:
    xor ah, ah
    int 0x16
    cmp al, 27
    jne .wait
    mov ah, 0x0C
    int 0x21
    retf

redraw:
    mov ah, 0x22
    int 0x23
    call paint
    mov ah, 0x23
    int 0x23
    ret

paint:
    pusha

    mov al, 0
    call surf_clear

    mov si, str_title
    mov bl, 2
    call surf_text_w_scaled
    mov cx, [surf_w]
    sub cx, ax
    shr cx, 1
    mov dx, 16
    mov si, str_title
    mov al, 0x0F
    call surf_print_big

    mov si, str_version
    call surf_text_w
    mov cx, [surf_w]
    sub cx, ax
    shr cx, 1
    mov dx, 58
    mov si, str_version
    mov al, 0x0B
    call surf_print

    mov si, str_author
    call surf_text_w
    mov cx, [surf_w]
    sub cx, ax
    shr cx, 1
    mov dx, 84
    mov si, str_author
    mov al, 0x07
    call surf_print

    popa
    ret

str_title   db 'x16-PRos', 0
str_version db 'version 1.2', 0
str_author  db 'made with ', 0x03 ,' by PRoX', 0

%include "grafx.inc"
%include "surf.inc"

PLE_END
