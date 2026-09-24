com_4Ch:
    push ds
    push ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    pop ax
    mov [last_return_code], al
    mov byte [last_return_type], 0
    pop ds

    jmp dos_terminate
