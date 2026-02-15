com_03h:
    xor dx, dx
    mov ah, 02h
    int 14h

    test ah, 80h
    jnz .aux_read_error

    clc
    iret

.aux_read_error:
    xor al, al
    stc
    iret