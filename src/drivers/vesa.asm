; ========================================================================
; vesa.asm - VESA VBE Bank Switching driver
; Copyright (C) 2026 PRoX2011
; ========================================================================

VBE_INFO_SIZE   equ 512
VBE_MODE_SIZE   equ 256

; ========================================================================
; vesa_init - Initializes VESA and sets a 640x480x8 video mode
; IN:  None
; OUT: CF = clear on success, set on error
; ========================================================================
vesa_init:
    pusha
    push es
    push ds
    push fs

    mov ax, cs
    mov es, ax
    mov di, vbe_info
    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne .error

    cmp dword [vbe_info], 'VESA'
    jne .error

    mov ax, [vbe_info + 14]
    mov si, ax
    mov ax, [vbe_info + 16]
    mov fs, ax

.find_mode:
    mov dx, [fs:si]
    cmp dx, 0xFFFF
    je .error
    add si, 2

    mov ax, cs
    mov es, ax
    mov di, vbe_mode
    mov cx, dx
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne .find_mode

    mov ax, [vbe_mode]
    and ax, 0x0011
    cmp ax, 0x0011
    jne .find_mode

    mov al, [vbe_mode + 2]
    test al, 0x01
    jz .find_mode
    test al, 0x04
    jz .find_mode

    cmp word [vbe_mode + 18], 640
    jne .find_mode
    cmp word [vbe_mode + 20], 480
    jne .find_mode
    cmp byte [vbe_mode + 25], 8
    jne .find_mode

    mov ax, 0x4F02
    mov bx, dx
    int 0x10
    cmp ax, 0x004F
    jne .error

    mov ax, [vbe_mode + 16]
    mov [vesa_pitch], ax
    mov ax, [vbe_mode + 18]
    mov [vesa_width], ax
    mov ax, [vbe_mode + 20]
    mov [vesa_height], ax
    mov ax, [vbe_mode + 8]
    mov [vesa_seg], ax

    push es
    mov ax, cs
    mov es, ax
    mov dx, vesa_palette
    mov cx, 256
    xor bx, bx
    mov ax, 0x1012
    int 0x10
    pop es

    mov word [current_bank], 0xFFFF

    clc
    jmp .done

.error:
    stc

.done:
    pop fs
    pop ds
    pop es
    popa
    ret

; ========================================================================
; vesa_set_bank - Switches the active VESA memory bank
; IN:  DX = bank number
; OUT: None
; ========================================================================
vesa_set_bank:
    pusha
    push ds
    push es
    cmp dx, [current_bank]
    je .done
    mov [current_bank], dx

    mov ax, 0x4F05
    mov bh, 0
    mov bl, 0
    int 0x10

.done:
    pop es
    pop ds
    popa
    ret

; ========================================================================
; vesa_put_pixel - Draws a single pixel in 640x480x8 mode
; IN:  BX = x coordinate
;      CX = y coordinate
;      AL = color
; OUT: None
; ========================================================================
vesa_put_pixel:
    pusha
    push es
    push fs

    mov [vesa_temp_color], al

    movzx ebx, bx
    movzx ecx, cx
    movzx eax, word [vesa_pitch]
    imul eax, ecx
    add eax, ebx

    mov edx, eax
    shr edx, 16
    and eax, 0xFFFF

    push eax
    call vesa_set_bank
    pop eax

    mov cx, [vesa_seg]
    mov es, cx
    mov cl, [vesa_temp_color]
    mov [es:eax], cl

    pop fs
    pop es
    popa
    ret

; ========================================================================
; Data Section
; ========================================================================
vbe_info:       times VBE_INFO_SIZE db 0
vbe_mode:       times VBE_MODE_SIZE db 0
vesa_pitch:     dw 0
vesa_width:     dw 0
vesa_height:    dw 0
vesa_seg:       dw 0
current_bank:   dw 0xFFFF
vesa_temp_color: db 0

vesa_palette:
%assign i 0
%rep 256
    db i / 4, 0, 0
%assign i i+1
%endrep