com_3Eh:
    push bp
    mov bp, sp
    push di
    push es

    call dosfile_jft_entry
    jc .fail
    mov al, 0xFF
    xchg al, [es:di]
    cmp al, 0xFF
    je .fail
    call dosfile_release
    jc .write_error

    xor ax, ax
    and word [bp+6], 0xFFFE
    pop es
    pop di
    pop bp
    iret

.write_error:
    mov ax, 0x001D
    jmp .err
.fail:
    mov ax, 0x0006
.err:
    or word [bp+6], 1
    pop es
    pop di
    pop bp
    iret
