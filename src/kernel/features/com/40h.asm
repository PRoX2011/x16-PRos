com_40h:
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

    cmp bx, DOSF_FIRST
    jb .console

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    call dosfile_slot
    jc .fail

    call dosfile_materialise
    jc .to_stream

    test cx, cx
    jz .truncate

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    add ax, cx
    adc dx, 0
    call dosfile_grow
    jnc .have_room

    call dosfile_spill
    jc .full
    jmp .stream

.to_stream:
    test byte [si + DF_FLAGS], DFF_STREAM
    jnz .streaming
    cmp word [si + DF_FIRST], 0
    jne .adopt
    call dosfile_spill
    jc .full
    jmp .streaming
.adopt:
    or byte [si + DF_FLAGS], DFF_STREAM

.streaming:
    cmp word [cs:dosf_count], 0
    je .stream_truncate

.stream:
    mov cx, [cs:dosf_count]
    call dosfile_write_stream
    jmp .ok

.stream_truncate:
    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    mov [si + DF_SIZE], ax
    mov [si + DF_SIZE + 2], dx
    or byte [si + DF_FLAGS], DFF_DIRTY
    xor ax, ax
    jmp .ok

.have_room:
    call dosfile_fill_gap
    mov [cs:dosf_count], cx

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    call dosfile_far
    mov es, dx
    mov di, ax

    add [si + DF_POS], cx
    adc word [si + DF_POS + 2], 0

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    cmp dx, [si + DF_SIZE + 2]
    ja .extend
    jb .no_extend
    cmp ax, [si + DF_SIZE]
    jbe .no_extend
.extend:
    mov [si + DF_SIZE], ax
    mov [si + DF_SIZE + 2], dx
.no_extend:
    or byte [si + DF_FLAGS], DFF_DIRTY

    mov ds, [cs:dosf_caller_ds]
    mov si, [cs:dosf_caller_dx]
    cld

.copy:
    mov bx, di
    neg bx
    jz .copy_rest
    cmp cx, bx
    jbe .copy_rest
    sub cx, bx
    push cx
    mov cx, bx
    rep movsb
    pop cx
    mov bx, es
    add bx, 0x1000
    mov es, bx
    xor di, di
    jmp .copy
.copy_rest:
    rep movsb

    mov ax, [cs:dosf_count]
    jmp .ok

.truncate:
    call dosfile_fill_gap
    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    mov [si + DF_SIZE], ax
    mov [si + DF_SIZE + 2], dx
    or byte [si + DF_FLAGS], DFF_DIRTY
    xor ax, ax
    jmp .ok

.full:
    xor ax, ax
    jmp .ok

.console:
    mov si, dx
    mov cx, [cs:dosf_count]
    test cx, cx
    jz .console_done
.console_loop:
    lodsb
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    loop .console_loop
.console_done:
    mov ax, [cs:dosf_count]

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
