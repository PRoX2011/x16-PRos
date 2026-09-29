com_54h:
    push ds
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov al, [verify_flag]
    pop ds
    iret
