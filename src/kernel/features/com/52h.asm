com_52h:
    push bp
    mov bp, sp

    call dosvars_seg
    mov bx, DOSVARS_SYSVARS

    and word [bp+6], 0xFFFE
    pop bp
    iret
