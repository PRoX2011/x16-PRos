com_24h:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push di

    push ds
    pop es
    mov di, dx

    mov ax, [es:di+0x0C]
    mov bx, 128
    mul bx
    add ax, [es:di+0x0E]
    adc dx, 0

    mov [es:di+0x21], ax
    mov [es:di+0x23], dx

    pop di
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax

    xor al, al
    clc
    iret
