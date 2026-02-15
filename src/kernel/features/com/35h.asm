com_35h:
    push ds
    push ax
    xor bx, bx
    mov ds, bx
    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1
    mov bx, word [ds:bx]
    mov es, word [ds:bx+2]
    pop ax
    pop ds
    iret