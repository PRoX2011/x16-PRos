com_3Bh:
    call com_copy_path_from_caller

    push dx
    push ds
    mov dx, ax
    mov ax, 0x2000
    mov ds, ax
    mov ax, dx
    call fs_change_directory
    pop ds
    pop dx
    jc .fail

    xor ax, ax
    clc
    iret

.fail:
    mov ax, 0x0003
    stc
    iret
