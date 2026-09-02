com_36h:
    push bp
    mov bp, sp
    push si
    push ds

    mov ax, 0x2000
    mov ds, ax
    push es
    mov es, ax
    call save_current_dir

    cmp dl, 0
    je .measure

    mov al, dl
    dec al
    add al, 'A'
    call fs_change_drive_letter
    jc .bad_drive

.measure:
    call fs_free_space
    mov bx, ax
    mov ax, [fs_spc]
    mov cx, 512
    mov dx, [fs_total_clus]
    and word [bp+6], 0xFFFE
    jmp .restore

.bad_drive:
    mov ax, 0xFFFF
    xor bx, bx
    xor cx, cx
    xor dx, dx
    or word [bp+6], 1

.restore:
    call restore_current_dir
    pop es
    pop ds
    pop si
    pop bp
    iret
