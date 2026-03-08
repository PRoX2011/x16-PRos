com_54h:
    push ds
    mov ax, 0x2000
    mov ds, ax
    mov al, [verify_flag]
    pop ds
    iret
