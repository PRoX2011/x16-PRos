com_19h:
    push bx
    push ds

    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov al, [current_drive_char]
    sub al, 'A'

    pop ds
    pop bx
    iret
