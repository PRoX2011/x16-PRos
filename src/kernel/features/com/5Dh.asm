com_5Dh:
    push bp
    mov bp, sp

    cmp al, 0x06
    jne .unsupported

    push es
    call dosvars_seg
    mov ax, es
    pop es
    mov ds, ax
    mov si, DOSVARS_SDA
    mov cx, 0x0080
    mov dx, 0x0020

    and word [bp+6], 0xFFFE
    pop bp
    iret

.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret
