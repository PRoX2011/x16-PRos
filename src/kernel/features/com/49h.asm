com_49h:
    push bp
    mov bp, sp

    mov ax, es
    call dosmem_free
    jc .fail

    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    mov ax, 0x0009
    or word [bp+6], 1
    pop bp
    iret
