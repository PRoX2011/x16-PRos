com_35h:
    push ds
    push ax
    xor bx, bx
    mov ds, bx
    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1
    mov es, word [ds:bx+2]
    mov bx, word [ds:bx]
    pop ax
    pop ds
    iret