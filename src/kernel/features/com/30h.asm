com_30h:
    push ds
    push si
    push di

    mov ax, 0x1E03  ; AL=major(3), AH=minor(30)
    mov ds, [cs:dos_current_psp]
    mov si, [0x2C]
    test si, si
    jz .done
    mov ds, si
    xor si, si
    mov cx, 0x8000
.env:
    cmp word [si], 0
    je .env_end
    inc si
    loop .env
    jmp .done
.env_end:
    add si, 4
    mov di, si
.name:
    lodsb
    test al, al
    jz .match
    cmp al, '\'
    je .sep
    cmp al, ':'
    jne .name
.sep:
    mov di, si
    jmp .name

.match:
    mov bx, setver_table
.entry:
    cmp byte [cs:bx], 0
    je .default
    mov si, di
.cmp:
    lodsb
    cmp al, 'a'
    jb .upper
    cmp al, 'z'
    ja .upper
    sub al, 0x20
.upper:
    cmp al, [cs:bx]
    jne .skip
    inc bx
    test al, al
    jnz .cmp
    mov ax, [cs:bx]
    jmp .done
.skip:
    cmp byte [cs:bx], 0
    je .next
    inc bx
    jmp .skip
.next:
    add bx, 3
    jmp .entry

.default:
    mov ax, 0x1E03
.done:
    xor bx, bx
    xor cx, cx
    pop di
    pop si
    pop ds
    iret

setver_table:
    db 'DOS32A.EXE', 0
    dw 0x0005
    db 0
