com_47h:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si
    push di
    push ds
    push es

    mov [cs:dosf_caller_ds_47], ds
    mov [cs:dosf_caller_si_47], si
    mov ax, ds
    mov es, ax
    mov di, si

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    test dl, dl
    jz .drive_ok

    mov al, dl
    add al, 'A' - 1
    mov si, drives_table
    xor cx, cx
    mov cl, [drive_count]
.scan:
    test cx, cx
    jz .bad_drive
    cmp al, [si]
    je .drive_ok
    add si, 3
    dec cx
    jmp .scan

.drive_ok:
    mov si, current_directory
    mov cx, 63
.copy:
    lodsb
    test al, al
    jz .terminate
    cmp al, '/'
    jne .store
    mov al, '\'
.store:
    stosb
    dec cx
    jnz .copy

.terminate:
    xor al, al
    stosb

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop bx
    pop ax

    mov ax, 0x0100

    and word [bp+6], 0xFFFE
    pop bp
    iret

.bad_drive:

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    mov ax, 0x000F
    or word [bp+6], 1
    pop bp
    iret

dosf_caller_ds_47 dw 0
dosf_caller_si_47 dw 0
