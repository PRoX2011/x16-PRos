ZF_BIT equ 0x0040

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
    push bp
    mov bp, sp

    mov ah, 0x01
    int 0x16
    jz .no_char

    mov ah, 0x00
    int 0x16
    and word [bp+6], ~ZF_BIT & 0xFFFF
    pop bp
    iret

.no_char:
    xor al, al
    or word [bp+6], ZF_BIT
    pop bp
    iret