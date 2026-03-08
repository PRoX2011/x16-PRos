com_04h:
    xor dx, dx
    mov ah, 01h
    mov al, dl
    int 14h

    test ah, 80h
    jnz .aux_write_timeout
    clc
    iret

.aux_write_timeout:
    stc
    iret