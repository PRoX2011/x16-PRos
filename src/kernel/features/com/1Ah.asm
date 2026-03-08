com_1Ah:
    push bx
    push ds
    mov bx, ds
    mov ax, 0x2000
    mov ds, ax
    mov [dta_offset], dx
    mov [dta_segment], bx
    pop ds
    pop bx
    clc
    iret
