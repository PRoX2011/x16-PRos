com_05h:
    push ax
    push dx
    mov ah, 0x00
    mov al, dl
    xor dx, dx
    int 0x17
    pop dx
    pop ax
    iret
