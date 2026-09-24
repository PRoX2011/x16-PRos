com_0Dh:
    push ax
    push ds
    mov ax, 0x2000
    mov ds, ax
    push es
    mov es, ax
    call fs_reset_floppy
    pop es
    pop ds
    pop ax
    clc
    iret
