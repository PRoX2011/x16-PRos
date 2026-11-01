com_57h:
    push bp
    mov bp, sp
    push si
    push ds

    cmp al, 0x01
    ja .unsupported

    push ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    pop ax

    cmp bx, DOSF_FIRST
    jb .device
    call dosfile_slot
    jc .bad_handle

    cmp al, 0x01
    je .store

    mov cx, [si + DF_TIME]
    mov dx, [si + DF_DATE]
    jmp .ok

.store:
    mov [si + DF_TIME], cx
    mov [si + DF_DATE], dx
    jmp .ok

.device:
    cmp al, 0x01
    je .ok
    xor cx, cx
    mov dx, 0x0021

.ok:
    and word [bp+6], 0xFFFE
    pop ds
    pop si
    pop bp
    iret

.bad_handle:
    mov ax, 0x0006
    jmp .fail

.unsupported:
    mov ax, 0x0001

.fail:
    or word [bp+6], 1
    pop ds
    pop si
    pop bp
    iret
