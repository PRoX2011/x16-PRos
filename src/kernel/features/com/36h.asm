com_36h:
    push bp
    mov bp, sp
    push si
    push ds

    mov ax, 0x2000
    mov ds, ax
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
    mov ax, 1
    mov cx, 512
    mov dx, 2847
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
    pop ds
    pop si
    pop bp
    iret
