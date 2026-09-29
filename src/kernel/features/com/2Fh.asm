com_2Fh:
    push ds
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov bx, [dta_offset]
    mov ax, [dta_segment]
    mov es, ax
    pop ds
    iret
