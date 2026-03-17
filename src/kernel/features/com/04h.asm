com_04h:
    mov al, dl
    xor dx, dx
    mov ah, 01h
    int 14h

    test ah, 80h
    jnz .aux_write_timeout
    clc
    iret

.aux_write_timeout:
    stc
    iret
