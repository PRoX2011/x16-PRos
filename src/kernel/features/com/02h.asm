com_02h:
    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    pop bx
    pop ax
    iret