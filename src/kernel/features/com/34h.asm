com_34h:
    push bp
    mov bp, sp
    push ax
    push cx
    push ds

    call dosvars_stamp_psp
    call dosvars_seg
    mov byte [es:DOSVARS_INDOS], 0
    mov byte [es:DOSVARS_SDA_IND], 0

    mov cx, KERNEL_DATA_SEG
    mov ds, cx
    mov al, [current_drive_char]
    sub al, 'A'
    mov [es:DOSVARS_CURDRV], al
    mov [es:DOSVARS_SDA_DRV], al

    pop ds
    pop cx
    pop ax
    mov bx, DOSVARS_INDOS
    and word [bp+6], 0xFFFE
    pop bp
    iret
