com_3Dh:
    push bp
    mov bp, sp

    mov [cs:dosf_access], al
    xor al, al
    call dosfile_open
    jc .fail

    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    or word [bp+6], 1
    pop bp
    iret
