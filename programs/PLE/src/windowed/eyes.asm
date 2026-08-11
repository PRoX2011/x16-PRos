; ==================================================================
; x16-PRos -- EYES. XEYES copy.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Googly eyes follow the cursor", "PRoX-dev"
PLE_LOGO          "logo/eyes.raw"

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
    mov ah, 0x24
    mov al, 1
    int 0x23
    mov ah, 0x23
    int 0x23
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
    call tick_eyes
    jmp .pace
.full:
    mov byte [surf_dirty], 0
    mov ax, [surf_ox]
    mov [last_ox], ax
    mov ax, [surf_oy]
    mov [last_oy], ax
    mov ax, [surf_w]
    mov [last_w], ax
    call draw_eyes_full

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
    mov dx, 30000
    int 0x15
    jmp .loop
.wpace:
    mov ah, 0x14
    mov cx, 1
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

draw_eyes_full:
    pusha
    cmp byte [surf_windowed], 1
    jne .nh
    mov ah, 0x22
    int 0x23
.nh:
    mov ax, [surf_h]
    shr ax, 2
    cmp ax, 6
    jae .rok
    mov ax, 6
.rok:
    mov [eR], ax
    shr ax, 2
    cmp ax, 2
    jae .pok
    mov ax, 2
.pok:
    mov [ePup], ax
    mov ax, [eR]
    xor dx, dx
    mov bx, 3
    div bx
    mov [eTrav], ax
    mov ax, [eR]
    mov bx, ax
    shr bx, 1
    add ax, bx
    mov [.gap], ax
    mov ax, [surf_h]
    shr ax, 1
    mov [eCy], ax
    mov ax, [surf_w]
    shr ax, 1
    mov bx, ax
    sub ax, [.gap]
    mov [eLx], ax
    mov ax, bx
    add ax, [.gap]
    mov [eRx], ax

    mov al, 0
    call surf_clear

    mov cx, [eLx]
    mov dx, [eCy]
    mov bx, [eR]
    mov al, 15
    call surf_fill_circle
    mov cx, [eRx]
    mov dx, [eCy]
    mov bx, [eR]
    mov al, 15
    call surf_fill_circle

    mov ax, [eLx]
    mov [lpx], ax
    mov ax, [eCy]
    mov [lpy], ax
    mov ax, [eRx]
    mov [rpx], ax
    mov ax, [eCy]
    mov [rpy], ax
    mov cx, [eLx]
    mov dx, [eCy]
    mov bx, [ePup]
    mov al, 0
    call surf_fill_circle
    mov cx, [eRx]
    mov dx, [eCy]
    mov bx, [ePup]
    mov al, 0
    call surf_fill_circle
    cmp byte [surf_windowed], 1
    jne .ns
    mov ah, 0x23
    int 0x23
.ns:
    popa
    ret
.gap dw 0

tick_eyes:
    pusha
    mov ah, 0x20
    int 0x23
    mov [mx], ax
    mov [my], bx

    mov ax, [eLx]
    mov [.ecx], ax
    call .calc
    mov ax, [.npx]
    cmp ax, [lpx]
    jne .lm
    mov ax, [.npy]
    cmp ax, [lpy]
    je .lk
.lm:
    mov cx, [lpx]
    mov dx, [lpy]
    mov bx, [ePup]
    mov al, 15
    call surf_fill_circle
    mov cx, [.npx]
    mov dx, [.npy]
    mov bx, [ePup]
    mov al, 0
    call surf_fill_circle
    mov ax, [.npx]
    mov [lpx], ax
    mov ax, [.npy]
    mov [lpy], ax
.lk:
    mov ax, [eRx]
    mov [.ecx], ax
    call .calc
    mov ax, [.npx]
    cmp ax, [rpx]
    jne .rm
    mov ax, [.npy]
    cmp ax, [rpy]
    je .rk
.rm:
    mov cx, [rpx]
    mov dx, [rpy]
    mov bx, [ePup]
    mov al, 15
    call surf_fill_circle
    mov cx, [.npx]
    mov dx, [.npy]
    mov bx, [ePup]
    mov al, 0
    call surf_fill_circle
    mov ax, [.npx]
    mov [rpx], ax
    mov ax, [.npy]
    mov [rpy], ax
.rk:
    popa
    ret

.calc:
    mov ax, [mx]
    mov cx, [surf_ox]
    add cx, [.ecx]
    sub ax, cx
    mov cx, [eTrav]
    call clamp_s
    add ax, [.ecx]
    mov [.npx], ax
    mov ax, [my]
    mov cx, [surf_oy]
    add cx, [eCy]
    sub ax, cx
    mov cx, [eTrav]
    call clamp_s
    add ax, [eCy]
    mov [.npy], ax
    ret
.ecx dw 0
.npx dw 0
.npy dw 0

clamp_s:
    push cx
    cmp ax, cx
    jle .lo
    mov ax, cx
    jmp .done
.lo:
    neg cx
    cmp ax, cx
    jge .done
    mov ax, cx
.done:
    pop cx
    ret

mx      dw 0
my      dw 0
eR      dw 0
ePup    dw 0
eTrav   dw 0
eLx     dw 0
eRx     dw 0
eCy     dw 0
lpx     dw 0
lpy     dw 0
rpx     dw 0
rpy     dw 0
last_ox dw 0
last_oy dw 0
last_w  dw 0

%include "grafx.inc"
%include "surf.inc"

PLE_END
