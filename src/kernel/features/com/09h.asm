com_09h:
    push ax
    push bx
    push si
    mov si, dx
.loop:
    lodsb
    cmp al, '$'
    je .done
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    jmp .loop
.done:
    pop si
    pop bx
    pop ax
    iret