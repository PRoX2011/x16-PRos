com_46h:
    push bp
    mov bp, sp
    push bx
    push di
    push es
    call dosfile_handle
    jc .bad
    mov al, bl
    mov bx, cx
    call dosfile_jft_entry
    jc .bad
    call dosfile_addref
    xchg al, [es:di]
    call dosfile_release
    xor ax, ax
    pop es
    pop di
    pop bx
    and word [bp+6], 0xFFFE
    pop bp
    iret
.bad:
    mov ax, 0x0006
    pop es
    pop di
    pop bx
    or word [bp+6], 1
    pop bp
    iret
