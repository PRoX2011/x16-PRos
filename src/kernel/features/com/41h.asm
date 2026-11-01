com_41h:
    push bp
    mov bp, sp

    call com_copy_path_from_caller

    push dx
    push ds
    push es
    push si
    mov dx, KERNEL_DATA_SEG
    mov ds, dx
    mov es, dx
    mov word [cs:.code], 0x0002
    call path_split
    jc .gone
    call dos_file_name_ok
    jnc .remove
    cmp ax, 0x0005
    jne .refuse
    mov [cs:.code], ax
.refuse:
    stc
    jmp .gone
.remove:
    mov ax, si
    call fs_remove_file
.gone:
    pushf
    call path_restore
    popf
    pop si
    pop es
    pop ds
    pop dx
    jc .fail

    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

.fail:
    mov ax, [cs:.code]
    or word [bp+6], 1
    pop bp
    iret

.code dw 0
