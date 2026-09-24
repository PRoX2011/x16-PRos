com_5Ah:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov di, dx
    push ds
    pop es
    xor al, al
    mov cx, 0x0080
    cld
    repne scasb
    dec di

    push ds
    xor ax, ax
    mov ds, ax
    mov ax, [0x046C]
    pop ds
    add ax, [cs:tmp_serial]
    inc word [cs:tmp_serial]

    mov cx, 4
.digit:
    rol ax, 1
    rol ax, 1
    rol ax, 1
    rol ax, 1
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jbe .store
    add al, 7
.store:
    stosb
    pop ax
    loop .digit

    mov al, 'T'
    stosb
    mov al, 'M'
    stosb
    mov al, 'P'
    stosb
    xor al, al
    stosb

    mov byte [cs:dosf_access], 2
    mov al, 1
    call dosfile_open
    jc .fail

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    or word [bp+6], 1
    pop bp
    iret

tmp_serial dw 0
