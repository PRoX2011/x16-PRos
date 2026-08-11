com_3Eh:
    push bp
    mov bp, sp
    push si
    push ds

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    cmp bx, DOSF_FIRST
    jb .device

    call dosfile_slot
    jc .fail
    call dosfile_close_slot
    jc .write_error

.device:
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop ds
    pop si
    pop bp
    iret

.write_error:
    mov ax, 0x001D
    or word [bp+6], 1
    pop ds
    pop si
    pop bp
    iret

.fail:
    mov ax, 0x0006
    or word [bp+6], 1
    pop ds
    pop si
    pop bp
    iret
