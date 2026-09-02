com_4Fh:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call find_dta_es_di
    call find_step
    jc find_ret_none
    jmp find_ret_ok
