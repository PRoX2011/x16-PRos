com_38h:
    push bp
    mov bp, sp
    cmp dx, 0xFFFF
    je .done

    push cx
    push si
    push di
    push es
    push ds
    pop es
    mov di, dx
    push cs
    pop ds
    mov si, dos_country_info
    mov cx, 34
    cld
    rep movsb
    push es
    pop ds
    pop es
    pop di
    pop si
    pop cx

.done:
    mov ax, 1
    mov bx, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

dos_case_map:
    retf

dos_country_info:
    dw 0
    db '$', 0, 0, 0, 0
    db ',', 0
    db '.', 0
    db '-', 0
    db ':', 0
    db 0
    db 2
    db 0
    dw dos_case_map, KERNEL_DATA_SEG
    db ',', 0
    times 10 db 0
