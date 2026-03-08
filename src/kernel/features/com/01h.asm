com_01h:
    mov ah, 0x00
    int 0x16
    push ax
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop ax
    iret