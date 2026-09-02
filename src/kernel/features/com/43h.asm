com_43h:
    push bp
    mov bp, sp

    cmp al, 0x00
    jne .set_ok

    call com_copy_path_from_caller
    push ds
    push es
    push si
    push dx
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call path_split
    jc .missing_pop

    mov ax, si
    call fs_file_exists
    pushf
    call path_restore
    popf
    jc .missing_pop

    pop dx
    pop si
    pop es
    pop ds

    mov cx, 0x0020
    mov ax, cx
    jmp .ok

.missing_pop:
    pop dx
    pop si
    pop es
    pop ds
    jmp .missing

.set_ok:
    xor ax, ax
.ok:
    and word [bp+6], 0xFFFE
    pop bp
    iret

.missing:
    mov ax, 0x0002
    or word [bp+6], 1
    pop bp
    iret
