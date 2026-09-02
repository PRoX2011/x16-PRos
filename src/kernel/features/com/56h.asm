com_56h:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    push ds
    mov ax, es
    mov ds, ax
    mov si, di
    mov ax, KERNEL_DATA_SEG
    mov es, ax
    mov di, rename_new
    mov cx, 79
    call .copy_name
    pop ds

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call path_split
    jc .missing
    mov [cs:.old_name], si

    mov si, rename_new
    call .last_component
    mov bx, si

    mov ax, [cs:.old_name]
    call fs_rename_file
    pushf
    call path_restore
    popf
    jc .refused

    xor ax, ax
    and word [bp+6], 0xFFFE
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

.missing:
    mov ax, 0x0002
    jmp .fail

.refused:
    mov ax, 0x0005

.fail:
    or word [bp+6], 1
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

.copy_name:
    cld
.loop:
    lodsb
    stosb
    test al, al
    jz .copied
    loop .loop
    xor al, al
    stosb
.copied:
    ret

.last_component:
    push ax
    mov [cs:.tail], si
.scan:
    mov al, [si]
    test al, al
    jz .scanned
    cmp al, '\'
    je .after
    cmp al, '/'
    je .after
    cmp al, ':'
    je .after
    inc si
    jmp .scan
.after:
    inc si
    mov [cs:.tail], si
    jmp .scan
.scanned:
    mov si, [cs:.tail]
    pop ax
    ret

.old_name dw 0
.tail     dw 0

rename_new times 80 db 0
