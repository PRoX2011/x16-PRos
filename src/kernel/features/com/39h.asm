com_39h:
    push bp
    mov bp, sp

    call com_copy_path_from_caller

    push dx
    push si
    push ds
    push es
    mov dx, KERNEL_DATA_SEG
    mov ds, dx
    mov es, dx
    call path_split
    jc .gone
    call dos_exact_dirname
    mov ax, si
    call fs_create_directory
.gone:
    pushf
    call path_restore
    popf
    pop es
    pop ds
    pop si
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
