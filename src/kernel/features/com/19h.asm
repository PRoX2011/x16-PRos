com_19h:
    push ds
    mov ax, 0x2000
    mov ds, ax
    mov al, [current_drive_char]
    sub al, 'A'
    pop ds
    iret
