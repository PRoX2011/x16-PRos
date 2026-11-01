com_0Dh:
    push ax
    push ds
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    push es
    mov es, ax
    call fs_reset_floppy
    pop es
    pop ds
    pop ax
    clc
    iret
