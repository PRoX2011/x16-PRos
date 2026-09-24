; ==================================================================
; x16-PRos -- CLOCK. Digital clock.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Digital clock", "PRoX-dev"
PLE_LOGO          "logo/clock.raw"

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    call surf_sync
    cmp byte [surf_windowed], 1
    je .ready
    mov ah, 0x06
    int 0x21
.ready:
    mov word [last_ox], 0xFFFF

.loop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .exit

    cmp byte [surf_dirty], 0
    jne .full
    mov ax, [surf_ox]
    cmp ax, [last_ox]
    jne .full
    mov ax, [surf_oy]
    cmp ax, [last_oy]
    jne .full
    mov ax, [surf_w]
    cmp ax, [last_w]
    jne .full
    call tick_clock
    jmp .pace
.full:
    mov byte [surf_dirty], 0
    mov ax, [surf_ox]
    mov [last_ox], ax
    mov ax, [surf_oy]
    mov [last_oy], ax
    mov ax, [surf_w]
    mov [last_w], ax
    call draw_clock_full

.pace:
    cmp byte [surf_windowed], 1
    je .wpace
    mov ah, 0x01
    int 0x16
    jz .sdelay
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .exit
.sdelay:
    mov ah, 0x86
    mov cx, 0
    mov dx, 60000
    int 0x15
    jmp .loop
.wpace:
    mov ah, 0x14
    mov cx, 9
    int 0x23
    jmp .loop

.exit:
    cmp byte [surf_windowed], 1
    je .wexit
    mov ah, 0x0C
    int 0x21
    retf
.wexit:
    mov ah, 0x12
    int 0x23
    jmp .wexit


draw_clock_full:
    cmp byte [surf_windowed], 1
    jne .nh
    mov ah, 0x22
    int 0x23
.nh:
    mov ah, 0x0A
    int 0x21
    mov [clk_hr], ch
    mov [clk_min], cl
    mov [clk_sec], dh
    mov [last_sec], dh
    mov al, 0
    call surf_clear
    call draw_clock_digits
    cmp byte [surf_windowed], 1
    jne .ns
    mov ah, 0x23
    int 0x23
.ns:
    ret

tick_clock:
    mov ah, 0x0A
    int 0x21
    cmp dh, [last_sec]
    je .done
    mov [last_sec], dh
    mov [clk_hr], ch
    mov [clk_min], cl
    mov [clk_sec], dh
    call draw_clock_digits
.done:
    ret

draw_clock_digits:
    pusha
    cmp byte [surf_windowed], 1
    jne .nh
    mov ah, 0x22
    int 0x23
.nh:
    mov ax, [surf_w]
    sub ax, 122
    jns .sxok
    xor ax, ax
.sxok:
    shr ax, 1
    mov [clk_sx], ax
    mov ax, [surf_h]
    sub ax, 28
    jns .syok
    xor ax, ax
.syok:
    shr ax, 1
    mov [clk_y], ax

    mov cx, [clk_sx]
    sub cx, 2
    mov dx, [clk_y]
    sub dx, 2
    mov si, 126
    mov di, 32
    mov al, 0
    call surf_fill_rect

    mov al, [clk_hr]
    mov cx, 0
    mov dx, 18
    call draw_2digits
    mov cx, 37
    call draw_colon
    mov al, [clk_min]
    mov cx, 44
    mov dx, 62
    call draw_2digits
    mov cx, 81
    call draw_colon
    mov al, [clk_sec]
    mov cx, 88
    mov dx, 106
    call draw_2digits
    cmp byte [surf_windowed], 1
    jne .ns
    mov ah, 0x23
    int 0x23
.ns:
    popa
    ret

draw_2digits:
    pusha
    mov [.xt], cx
    mov [.xu], dx
    xor ah, ah
    mov bl, 10
    div bl
    mov [.u], ah
    mov cx, [.xt]
    call draw_digit
    mov al, [.u]
    mov cx, [.xu]
    call draw_digit
    popa
    ret
.xt dw 0
.xu dw 0
.u  db 0

draw_digit:
    pusha
    mov [.relx], cx
    xor ah, ah
    mov bx, ax
    mov al, [seg_table + bx]
    mov [.mask], al
    mov ax, [clk_sx]
    add ax, [.relx]
    mov [.rx], ax

    test byte [.mask], 0x01
    jz .nb
    mov cx, [.rx]
    add cx, 3
    mov dx, [clk_y]
    mov si, 10
    mov di, 3
    mov al, 15
    call surf_fill_rect
.nb:
    test byte [.mask], 0x20
    jz .nc
    mov cx, [.rx]
    mov dx, [clk_y]
    add dx, 3
    mov si, 3
    mov di, 9
    mov al, 15
    call surf_fill_rect
.nc:
    test byte [.mask], 0x02
    jz .nd
    mov cx, [.rx]
    add cx, 13
    mov dx, [clk_y]
    add dx, 3
    mov si, 3
    mov di, 9
    mov al, 15
    call surf_fill_rect
.nd:
    test byte [.mask], 0x40
    jz .ne
    mov cx, [.rx]
    add cx, 3
    mov dx, [clk_y]
    add dx, 12
    mov si, 10
    mov di, 3
    mov al, 15
    call surf_fill_rect
.ne:
    test byte [.mask], 0x10
    jz .nf
    mov cx, [.rx]
    mov dx, [clk_y]
    add dx, 15
    mov si, 3
    mov di, 9
    mov al, 15
    call surf_fill_rect
.nf:
    test byte [.mask], 0x04
    jz .ng
    mov cx, [.rx]
    add cx, 13
    mov dx, [clk_y]
    add dx, 15
    mov si, 3
    mov di, 9
    mov al, 15
    call surf_fill_rect
.ng:
    test byte [.mask], 0x08
    jz .gdone
    mov cx, [.rx]
    add cx, 3
    mov dx, [clk_y]
    add dx, 25
    mov si, 10
    mov di, 3
    mov al, 15
    call surf_fill_rect
.gdone:
    popa
    ret
.relx dw 0
.rx   dw 0
.mask db 0

draw_colon:
    pusha
    mov ax, [clk_sx]
    add ax, cx
    mov [.cx], ax
    mov cx, [.cx]
    mov dx, [clk_y]
    add dx, 8
    mov si, 3
    mov di, 3
    mov al, 15
    call surf_fill_rect
    mov cx, [.cx]
    mov dx, [clk_y]
    add dx, 18
    mov si, 3
    mov di, 3
    mov al, 15
    call surf_fill_rect
    popa
    ret
.cx dw 0

clk_hr   db 0
clk_min  db 0
clk_sec  db 0
last_sec db 0xFF
clk_sx   dw 0
clk_y    dw 0
last_ox  dw 0
last_oy  dw 0
last_w   dw 0

seg_table:
    db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

%include "grafx.inc"
%include "surf.inc"

PLE_END