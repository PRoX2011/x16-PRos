com_4Ah:
    push bp
    mov bp, sp

    mov ax, es
    call dosmem_resize
    jc .fail

    and word [bp+6], 0xFFFE
    pop bp
    iret
.fail:
    mov ax, 0x0008
    test bx, bx
    jnz .report
    mov ax, 0x0009
.report:
    or word [bp+6], 1
    pop bp
    iret