; ==================================================================
; x16-PRos -- CLOCK. Background clock application 
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Background clock application ", "PRoX-dev"
PLE_LOGO          "logo/clock.raw"

start:
    push cs
    pop ds
    push cs
    pop es

.loop:
    mov ah, 0x0A
    int 0x21
    ; CH=hour, CL=min, DH=sec

    mov di, time_buf
    mov al, ch
    call bin_emit
    mov al, ':'
    stosb
    mov al, cl
    call bin_emit
    mov al, ':'
    stosb
    mov al, dh
    call bin_emit
    xor al, al
    stosb

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov [saved_row], dh
    mov [saved_col], dl

    mov ah, 0x02
    xor bh, bh
    mov dh, 0
    mov dl, 72
    int 0x10

    ; HH:MM:SS
    mov si, time_buf
    mov ah, 0x01
    int 0x21

    mov ah, 0x02
    xor bh, bh
    mov dh, [saved_row]
    mov dl, [saved_col]
    int 0x10

    mov ah, 0x14
    mov cx, 9
    int 0x23
    jmp .loop

bin_emit:
    xor ah, ah
    mov bl, 10
    div bl
    add al, '0'
    stosb
    mov al, ah
    add al, '0'
    stosb
    ret

time_buf   times 9 db 0
saved_row  db 0
saved_col  db 0

PLE_END