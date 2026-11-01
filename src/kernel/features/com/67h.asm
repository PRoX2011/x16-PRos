com_67h:
    push bp
    mov bp, sp
    cmp bx, 20
    ja .too_many
    and word [bp+6], 0xFFFE
    pop bp
    iret
.too_many:
    mov ax, 0x0008
    or word [bp+6], 1
    pop bp
    iret
