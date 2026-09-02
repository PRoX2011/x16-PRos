com_3Fh:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:dosf_caller_ds], ds
    mov [cs:dosf_caller_dx], dx
    mov [cs:dosf_count], cx

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    test bx, bx
    jz .stdin

    call dosfile_slot
    jc .fail

    test byte [si + DF_FLAGS], DFF_BUF
    jnz .buffered

    mov es, [cs:dosf_caller_ds]
    mov di, [cs:dosf_caller_dx]
    call dosfile_read_stream

    jmp .ok

.buffered:
    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    sub ax, [si + DF_POS]
    sbb dx, [si + DF_POS + 2]
    jb .eof
    test dx, dx
    jnz .have
    cmp ax, cx
    jae .have
    mov cx, ax
.have:
    test cx, cx
    jz .eof

    mov [cs:dosf_count], cx

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    call dosfile_far

    add [si + DF_POS], cx
    adc word [si + DF_POS + 2], 0

    mov es, [cs:dosf_caller_ds]
    mov di, [cs:dosf_caller_dx]
    mov ds, dx
    mov si, ax
    cld

.copy:
    mov bx, si
    neg bx
    jz .copy_rest
    cmp cx, bx
    jbe .copy_rest
    sub cx, bx
    push cx
    mov cx, bx
    rep movsb
    pop cx
    mov bx, ds
    add bx, 0x1000
    mov ds, bx
    xor si, si
    jmp .copy
.copy_rest:
    rep movsb

    mov ax, [cs:dosf_count]
    jmp .ok

.eof:
    xor ax, ax
    jmp .ok

.stdin:
    cmp word [cs:dosf_count], 0
    je .eof

    push ax
    xor ah, ah
    int 0x16
    mov ah, 0x0E
    mov bl, 0x0F
    push ax
    int 0x10
    pop ax
    mov es, [cs:dosf_caller_ds]
    mov di, [cs:dosf_caller_dx]
    mov [es:di], al
    pop ax
    mov ax, 1

.ok:
    call dosvars_sync_sft
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

.fail:
    mov ax, 0x0006
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
