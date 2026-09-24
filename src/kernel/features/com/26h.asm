com_26h:
    push bp
    mov bp, sp
    pusha
    push ds
    push es

    mov [cs:.newseg], dx
    mov [cs:.func], ah
    mov [cs:.memtop], si

    mov ds, [cs:dos_current_psp]
    mov es, dx
    xor si, si
    xor di, di
    mov cx, 128
    cld
    rep movsw

    mov word [es:0x00], 0x20CD

    cmp byte [cs:.func], 0x55
    jne .keep_top
    mov ax, [cs:.memtop]
    mov [es:0x02], ax
.keep_top:
    xor ax, ax
    mov ds, ax
    mov ax, [0x22 * 4]
    mov [es:0x0A], ax
    mov ax, [0x22 * 4 + 2]
    mov [es:0x0C], ax
    mov ax, [0x23 * 4]
    mov [es:0x0E], ax
    mov ax, [0x23 * 4 + 2]
    mov [es:0x10], ax
    mov ax, [0x24 * 4]
    mov [es:0x12], ax
    mov ax, [0x24 * 4 + 2]
    mov [es:0x14], ax

    mov ax, [cs:dos_current_psp]
    mov [es:0x16], ax

    mov word [es:0x32], 20
    mov word [es:0x34], 0x0018
    mov ax, es
    mov [es:0x36], ax

    mov byte [es:0x50], 0xCD
    mov byte [es:0x51], 0x21
    mov byte [es:0x52], 0xCB
    cmp byte [cs:.func], 0x55
    jne .no_switch
    mov ax, [cs:.newseg]
    mov [cs:dos_current_psp], ax
    call dosvars_stamp_psp
.no_switch:

    pop es
    pop ds
    popa
    and word [bp+6], 0xFFFE
    pop bp
    iret

.newseg dw 0
.memtop dw 0
.func   db 0
