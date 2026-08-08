<<<<<<< HEAD
com_13h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x06
    int 0x22

    pop ds
    pop dx
    
    jc .fail

    xor al, al
    clc
    iret

.fail:
    mov al, 0xFF
    stc

=======
com_13h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x06
    int 0x22

    pop ds
    pop dx
    
    jc .fail

    xor al, al
    clc
    iret

.fail:
    mov al, 0xFF
    stc

>>>>>>> 88a7da6 (Первый коммит)
    iret