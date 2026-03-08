com_06h:
    cmp dl, 0xFF
    je .input
    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    pop bx
    pop ax
    iret
.input:
    mov ah, 0x01
    int 0x16
    jz .no_char
    mov ah, 0x00
    int 0x16
    clc
    iret
.no_char:
    xor al, al
    or al, al
    iret