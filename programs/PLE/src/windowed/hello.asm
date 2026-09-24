%include "ple.inc"

PLE_HEADER start, "Just another hello world :)", "PRoX-dev"
PLE_LOGO          "logo/hello.raw"

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
    mov al, 15
    call surf_clear
    mov ax, [surf_w]
    sub ax, 13 * 8
    shr ax, 1
    mov cx, ax
    mov ax, [surf_h]
    sub ax, 16
    shr ax, 1
    mov dx, ax
    mov si, hello_msg
    mov al, 0
    call surf_print
    popa
    ret

hello_msg db 'Hello, World!', 0

%include "grafx.inc"
%include "surf.inc"

PLE_END