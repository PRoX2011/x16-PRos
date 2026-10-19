com_66h:
    push bp
    mov bp, sp
    cmp al, 0x01
    jne .set
    mov bx, 437
    mov dx, bx
.set:
    and word [bp+6], 0xFFFE
    pop bp
    iret
