com_48h:
    push bp
    mov bp, sp

    call dosmem_alloc
    jc .fail

    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    mov ax, 0x0008
    or word [bp+6], 1
    pop bp
    iret
