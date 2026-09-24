com_39h:
    push bp
    mov bp, sp

    call com_copy_path_from_caller

    push dx
    push ds
    push es
    mov dx, ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov ax, dx
    call fs_create_directory
    pop es
    pop ds
    pop dx
    jc .fail

    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    mov ax, 0x0003
    or word [bp+6], 1
    pop bp
    iret
