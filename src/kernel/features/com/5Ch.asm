com_5Ch:
    push bp
    mov bp, sp
    cmp al, 0x01
    ja .unsupported
    and word [bp+6], 0xFFFE
    pop bp
    iret
.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret
