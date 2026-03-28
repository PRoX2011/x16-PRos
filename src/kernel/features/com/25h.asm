com_25h:
    push es
    push bx
    push ax
    xor bx, bx
    mov es, bx
    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1
    cli
    mov word [es:bx], dx
    mov word [es:bx+2], ds
    sti
    pop ax
    pop bx
    pop es
    iret