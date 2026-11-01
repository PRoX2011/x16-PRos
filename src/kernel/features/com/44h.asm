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
    cmp al, 0x0D
    je .generic
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
.fail:
    or word [bp+6], 1
    pop ds
    pop cx
    pop bx
    pop bp
    iret

.generic:
    cmp cx, 0x0860
    jne .unsupported
    push es
    push si
    push di
    push dx
    mov di, dx
    push ds
    pop es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    call save_current_dir
    mov al, bl
    add al, 'A' - 1
    test bl, bl
    jnz .have_drive
    mov al, [current_drive_char]
.have_drive:
    call fs_change_drive_letter
    jc .no_drive

    mov word [es:di + 1], 0x0007
    mov byte [es:di + 3], 0
    cmp byte [current_drive_char], 'C'
    jb .removable_disk
    mov word [es:di + 1], 0x0105
.removable_disk:
    mov ax, [SecsPerTrack]
    mul word [Sides]
    xchg ax, cx
    mov ax, [disk_buffer + 0x13]
    xor dx, dx
    div cx
    mov [es:di + 4], ax
    mov byte [es:di + 6], 0
    add di, 7
    mov si, disk_buffer + 0x0B
    mov cx, 31
    cld
    rep movsb
    call restore_current_dir
    pop dx
    pop di
    pop si
    pop es
    jmp .leave_ok

.no_drive:
    call restore_current_dir
    pop dx
    pop di
    pop si
    pop es
    mov ax, 0x000F
    jmp .fail

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
