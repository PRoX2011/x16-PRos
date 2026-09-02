com_68h:
    push bp
    mov bp, sp
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret
