com_58h:
    push bp
    mov bp, sp
    cmp al, 0x03
    ja .unsupported
    test al, 1
    jnz .ok
    xor ax, ax
.ok:
    and word [bp+6], 0xFFFE
    pop bp
    iret
.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret
