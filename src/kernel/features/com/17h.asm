com_17h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov cx, 0x3000
    mov ah, 0x02
    int 0x22
    jc .fail

    push bx

    mov si, com_path_buffer
    mov ah, 0x06
    int 0x22

    pop cx
    jc .fail

    mov si, dx
    add si, 16
    call fcb_str_to_normal

    mov si, com_path_buffer2
    mov bx, 0x3000
    mov ah, 0x03
    int 0x22
    jc .fail

    pop ds
    pop dx

    xor al, al
    clc
    
    iret

.fail:
    pop ds
    pop dx
    mov al, 0xFF
    stc

    iret