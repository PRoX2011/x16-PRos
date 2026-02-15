com_2Ah:
    push bx
    push ax
    mov ah, 0x04
    int 0x1A
    mov al, cl
    call bcd_to_bin
    mov cl, al
    mov al, ch
    call bcd_to_bin
    mov ch, al
    mov al, dh
    call bcd_to_bin
    mov dh, al
    mov al, dl
    call bcd_to_bin
    mov dl, al
    mov al, 0
    pop ax
    pop bx
    iret