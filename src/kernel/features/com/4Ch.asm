com_4Ch:
    push ds
    push ax
    mov ax, 0x2000
    mov ds, ax
    pop ax
    mov [last_return_code], al
    mov byte [last_return_type], 0
    pop ds
    int 0x20
    iret