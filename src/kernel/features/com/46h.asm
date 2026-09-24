com_46h:
    push bp
    mov bp, sp
    cmp bx, DOSF_FIRST
    jae .unsupported
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret
.unsupported:
    mov ax, 0x0006
    or word [bp+6], 1
    pop bp
    iret
