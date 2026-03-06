com_4Dh:
    push ds
    mov ax, 0x2000
    mov ds, ax

    mov al, [last_return_code]
    mov ah, [last_return_type]
    mov byte [last_return_code], 0
    mov byte [last_return_type], 0

    pop ds
    clc
    iret
