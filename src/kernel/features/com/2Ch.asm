com_2Ch:
    push bx
    push ax
    mov ah, 0x02
    int 0x1A
    mov al, ch
    call bcd_to_bin
    mov ch, al
    mov al, cl
    call bcd_to_bin
    mov cl, al
    mov al, dh
    call bcd_to_bin
    mov dh, al
    push es
    xor bx, bx
    mov es, bx
    mov al, [es:0x046C]
    pop es
    and al, 99
    mov dl, al
    pop ax
    pop bx
    iret