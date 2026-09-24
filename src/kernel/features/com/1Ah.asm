com_1Ah:
    push ax
    push bx
    push ds

    mov bx, ds
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov [dta_offset], dx
    mov [dta_segment], bx

    pop ds
    pop bx
    pop ax
    iret
