com_41h:
    call com_copy_path_from_caller

    push dx
    push ds
    mov dx, ax
    mov ax, 0x2000
    mov ds, ax
    mov ax, dx
    call fs_remove_file
    pop ds
    pop dx
    jc .fail

    xor ax, ax
    clc
    iret

.fail:
    mov ax, 0x0002
    stc
    iret
