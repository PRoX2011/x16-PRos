com_45h:
    push bp
    mov bp, sp
    push bx
    call dosfile_handle
    jc .bad
    mov al, bl
    call dosfile_jft_alloc
    jc .full
    xchg ax, bx
    call dosfile_addref
    mov ax, bx
    pop bx
    and word [bp+6], 0xFFFE
    pop bp
    iret
.full:
    mov ax, 0x0004
    jmp .err
.bad:
    mov ax, 0x0006
.err:
    pop bx
    or word [bp+6], 1
    pop bp
    iret
