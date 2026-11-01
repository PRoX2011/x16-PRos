com_4Ch:
    push es
    push ds
    push bp
    push di
    push si
    push dx
    push cx
    push bx
    push ax
    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov [last_return_code], al
    mov byte [last_return_type], 0

    jmp dos_terminate
