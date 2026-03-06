com_2Fh:
    push ds
    mov ax, 0x2000
    mov ds, ax
    mov bx, [dta_offset]
    mov ax, [dta_segment]
    mov es, ax
    pop ds
    iret
