; ==================================================================
; x16-PRos -- PAINT. Very simple paint program.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ax, 0x12
    int 0x10

    mov byte [CurrentColor], 0x0F
    mov byte [BrushSize], 1

    call InitMouse
    call EnableMouse

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

programLoop:
    mov ah, 0x01
    int 0x16
    jz check_mouse

    mov ah, 0x00
    int 0x16

    cmp al, '0'
    jb check_other_keys
    cmp al, '9'
    ja check_other_keys

    sub al, '0'
    mov bx, ColorTable
    xlatb
    mov [CurrentColor], al
    jmp check_mouse

check_other_keys:
    cmp al, 'w'
    je increase_size
    cmp al, 'W'
    je increase_size

    cmp al, 's'
    je decrease_size
    cmp al, 'S'
    je decrease_size

    cmp al, 0x1B
    je exit

    jmp check_mouse

increase_size:
    cmp byte [BrushSize], 9
    jae check_mouse
    inc byte [BrushSize]
    jmp check_mouse

decrease_size:
    cmp byte [BrushSize], 1
    jbe check_mouse
    dec byte [BrushSize]
    jmp check_mouse

check_mouse:
    cmp word [ButtonStatus], 0x09
    je paint

    jmp programLoop

paint:
    mov cx, [MouseX]
    mov dx, [MouseY]
    sub dx, 2

    mov al, [BrushSize]
    shr al, 1
    xor ah, ah
    sub cx, ax
    sub dx, ax

    mov si, [BrushSize]
    mov bh, 0

draw_row:
    mov di, [BrushSize]
    push cx

draw_column:
    mov ah, 0x0C
    mov al, [CurrentColor]
    int 0x10

    inc cx
    dec di
    jnz draw_column

    pop cx
    inc dx
    dec si
    jnz draw_row

    jmp programLoop

exit:
    mov ax, 0x12
    int 0x10

    ret

CurrentColor db 0
BrushSize db 1

; Table of correspondence of numbers to colors:
; 0 - black (0x00)
; 1 - white (0x0F)
; 2 - blue (0x01)
; 3 - cyan (0x03)
; 4 - green (0x02)
; 5 - red (0x04)
; 6 - purple (0x05)
; 7 - yellow (0x0E)
; 8 - light gray (0x07)
; 9 - dark gray (0x08)
ColorTable db 0x00, 0x0F, 0x01, 0x03, 0x02, 0x04, 0x05, 0x0E, 0x07, 0x08

welcome_msg    db '                             - PRos Paint v0.1 -', 13, 10,
               db '         Use 1-9 buttons to change colors and W, S to change brush size', 13, 10,
               db '                          Press ESC to exit program', 0

%include "src/drivers/ps2_mouse.asm"