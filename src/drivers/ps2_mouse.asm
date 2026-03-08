; ==================================================================
; x16-PRos - PS/2 mouse driver
; Copyright (C) 2025 PRoX2011
;
; Driver version: 0.1
;
; Compatible with video modes:
;   - 0x12  (VGA, 640x480, 16 colors, planar)
; ==================================================================

%define WCURSOR 8
%define HCURSOR 11

section .text

InitMouse:
    int 0x11
    test ax, 0x04
    jz noMouse
    mov ax, 0xC205
    mov bh, 0x03
    int 0x15
    jc noMouse
    mov ax, 0xC203
    mov bh, 0x03
    int 0x15
    jc noMouse
    ret

EnableMouse:
    call DisableMouse
    mov ax, 0xC207
    mov bx, MouseCallback
    int 0x15
    mov ax, 0xC200
    mov bh, 0x01
    int 0x15
    ret

DisableMouse:
    mov ax, 0xC200
    mov bh, 0x00
    int 0x15
    mov ax, 0xC207
    int 0x15
    ret

MouseCallback:
    push bp
    mov bp, sp
    pusha
    push es
    push ds

    push cs
    pop ds

    call HideCursor

    mov al, [bp + 12]
    mov bl, al
    mov cl, 3
    shl al, cl
    sbb dh, dh
    cbw
    mov dl, [bp + 8]
    mov al, [bp + 10]

    neg dx
    mov cx, [MouseY]
    add dx, cx
    mov cx, [MouseX]
    add ax, cx

    cmp ax, 0
    jge .check_x_max
    xor ax, ax
.check_x_max:
    cmp ax, 639 - WCURSOR
    jle .check_y_min
    mov ax, 639 - WCURSOR
.check_y_min:
    cmp dx, 0
    jge .check_y_max
    xor dx, dx
.check_y_max:
    cmp dx, 479 - HCURSOR
    jle .update_pos
    mov dx, 479 - HCURSOR

.update_pos:
    mov [ButtonStatus], bl
    mov [MouseX], ax
    mov [MouseY], dx

    call SaveBackground

    mov si, mousebmp
    mov al, 0x0F
    call DrawCursor

    pop ds
    pop es
    popa
    pop bp
    retf

SaveBackground:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov si, ax
    mov dx, 0x3CE
    mov al, 4
    out dx, al
    inc dx
    mov di, BackgroundBuffer
    mov bx, 0
.save_plane:
    mov al, bl
    out dx, al
    push si
    mov cx, HCURSOR
.save_row:
    mov al, [es:si]
    mov [di], al
    inc di
    add si, 80
    loop .save_row
    pop si
    inc bx
    cmp bx, 4
    jl .save_plane
    popa
    ret

RestoreBackground:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov si, BackgroundBuffer
    mov bx, 0
.restore_plane:
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    push di
    mov cx, HCURSOR
.restore_row:
    mov al, [si]
    mov [es:di], al
    inc si
    add di, 80
    loop .restore_row
    pop di
    inc bx
    cmp bx, 4
    jl .restore_plane
    popa
    ret

DrawCursor:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov si, mousebmp
    mov bx, 0
.draw_plane:
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    push di
    push si
    mov cx, HCURSOR
.draw_row:
    mov ah, [es:di]
    mov al, [si]
    or ah, al
    mov [es:di], ah
    inc si
    add di, 80
    loop .draw_row
    pop si
    pop di
    inc bx
    cmp bx, 4
    jl .draw_plane
    popa
    ret

HideCursor:
    call RestoreBackground
    ret

noMouse:
    ret

section .data
MOUSEFAIL db "An unexpected error happened!", 0
MOUSEINITOK db "Mouse initialized!", 0x0F, 0
ButtonStatus dw 0
MouseX dw 0
MouseY dw 0
mousebmp:
    db 0b10000000
    db 0b11000000
    db 0b11100000
    db 0b11110000
    db 0b11111000
    db 0b11111100
    db 0b11111110
    db 0b11111000
    db 0b11011100
    db 0b10001110
    db 0b00000110

section .bss
BackgroundBuffer resb 44
