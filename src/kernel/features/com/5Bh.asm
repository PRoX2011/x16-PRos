com_5Bh:
    push bp
    mov bp, sp

    mov byte [cs:dosf_access], 2
    mov al, 2
    call dosfile_open
    jc .fail

    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    or word [bp+6], 1
    pop bp
    iret
