com_23h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x08
    int 0x22

    pop ds
    pop dx

    jc .fail

    push bx

    push ds
    pop es
    mov di, dx

    pop ax
    xor dx, dx
    mov cx, 128
    div cx

    mov [es:di+0x21], ax
    mov word [es:di+0x23], 0

    xor al, al
    clc
    iret

.fail:
    mov al, 0xFF
    stc
    iret