com_42h:
    push bp
    mov bp, sp
    push bx
    push cx
    push si
    push ds

    mov [cs:dosf_seek_origin], al
    mov [cs:dosf_seek_lo], dx
    mov [cs:dosf_seek_hi], cx

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    call dosfile_slot
    jc .fail

    mov al, [cs:dosf_seek_origin]
    cmp al, 1
    je .from_cur
    cmp al, 2
    je .from_end
    xor bx, bx
    xor cx, cx
    jmp .apply

.from_cur:
    mov bx, [si + DF_POS]
    mov cx, [si + DF_POS + 2]
    jmp .apply

.from_end:
    mov bx, [si + DF_SIZE]
    mov cx, [si + DF_SIZE + 2]

.apply:
    add bx, [cs:dosf_seek_lo]
    adc cx, [cs:dosf_seek_hi]

    test ch, 0x80
    jz .in_range
    xor bx, bx
    xor cx, cx

.in_range:

.store:
    mov [si + DF_POS], bx
    mov [si + DF_POS + 2], cx
    call dosvars_sync_sft
    mov ax, bx
    mov dx, cx

    and word [bp+6], 0xFFFE
    pop ds
    pop si
    pop cx
    pop bx
    pop bp
    iret

.fail:
    or word [bp+6], 1
    pop ds
    pop si
    pop cx
    pop bx
    pop bp
    mov ax, 0x0006
    iret
