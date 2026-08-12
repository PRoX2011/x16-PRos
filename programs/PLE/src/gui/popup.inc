popup_set_rect:
    pusha
    mov ax, cx
    shr ax, 3
    mov [popup_col], ax

    mov ax, cx
    and ax, 7
    add ax, si
    add ax, 7
    shr ax, 3
    cmp ax, POPUP_MAX_BPR
    jbe .bpr_ok
    mov ax, POPUP_MAX_BPR
.bpr_ok:
    mov [popup_bpr], ax

    mov ax, di
    cmp ax, POPUP_MAX_ROWS
    jbe .rows_ok
    mov ax, POPUP_MAX_ROWS
.rows_ok:
    mov [popup_rows], ax

    mov ax, dx
    mov bx, 80
    mul bx
    add ax, [popup_col]
    mov [popup_org], ax
    popa
    ret

popup_arm_vga:
    push ax
    push dx
    mov dx, 0x3CE
    mov al, 0x01
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x05
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    pop dx
    pop ax
    ret

popup_save:
    pusha
    push es
    cmp word [popup_rows], 0
    je .nothing
    cmp word [popup_bpr], 0
    je .nothing
    call popup_arm_vga

    mov ax, 0xA000
    mov es, ax
    mov di, POPUP_BUF_OFF
    xor bp, bp

.plane:
    mov dx, 0x3CE
    mov al, 4
    out dx, al
    inc dx
    mov ax, bp
    out dx, al

    mov si, [popup_org]
    mov cx, [popup_rows]
.row:
    push cx
    push si
    mov cx, [popup_bpr]
.byte:
    mov al, [es:si]
    mov [di], al
    inc si
    inc di
    loop .byte
    pop si
    add si, 80
    pop cx
    loop .row

    inc bp
    cmp bp, 4
    jl .plane

.nothing:
    pop es
    popa
    ret

popup_restore:
    pusha
    push es
    cmp word [popup_rows], 0
    je .nothing
    cmp word [popup_bpr], 0
    je .nothing
    call popup_arm_vga

    mov ax, 0xA000
    mov es, ax
    mov si, POPUP_BUF_OFF
    xor bp, bp

.plane:
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov ax, bp
    mov cl, al
    mov al, 1
    shl al, cl
    out dx, al

    mov di, [popup_org]
    mov cx, [popup_rows]
.row:
    push cx
    push di
    mov cx, [popup_bpr]
.byte:
    mov al, [si]
    mov [es:di], al
    inc si
    inc di
    loop .byte
    pop di
    add di, 80
    pop cx
    loop .row

    inc bp
    cmp bp, 4
    jl .plane

    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

.nothing:
    pop es
    popa
    ret

popup_col   dw 0
popup_bpr   dw 0
popup_rows  dw 0
popup_org   dw 0
