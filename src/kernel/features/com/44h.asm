com_44h:
    push bp
    mov bp, sp
    push bx
    push cx
    push ds

    cmp al, 0x00
    je .get_info
    cmp al, 0x01
    je .set_info
    cmp al, 0x08
    je .removable
    cmp al, 0x09
    je .drive_local
    cmp al, 0x0A
    je .handle_local
    cmp al, 0x0B
    je .leave_ok
    cmp al, 0x0E
    je .logical
    jmp .unsupported

.get_info:
    cmp bx, DOSF_FIRST
    jae .info_file
    mov dx, 0x80D3
    jmp .leave_dx
.info_file:
    call .current_drive
    xor dx, dx
    mov dl, al
    jmp .leave_dx

.set_info:
    cmp bx, DOSF_FIRST
    jae .unsupported
    jmp .leave_ok

.removable:
    mov al, bl
    test al, al
    jnz .have_unit
    call .current_drive
    inc al
.have_unit:
    cmp al, 3
    jae .fixed
    xor ax, ax
    jmp .leave_ok
.fixed:
    mov ax, 1
    jmp .leave_ok

.drive_local:
.handle_local:
    xor dx, dx
    jmp .leave_dx

.logical:
    xor al, al

.leave_ok:
    and word [bp+6], 0xFFFE
    pop ds
    pop cx
    pop bx
    pop bp
    iret

.leave_dx:
    mov ax, dx
    and word [bp+6], 0xFFFE
    pop ds
    pop cx
    pop bx
    pop bp
    iret

.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop ds
    pop cx
    pop bx
    pop bp
    iret

.current_drive:
    push ds
    push bx
    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov al, [current_drive_char]
    sub al, 'A'
    pop bx
    pop ds
    ret
