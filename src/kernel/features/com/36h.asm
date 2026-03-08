com_36h:
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
    mov ax, 1           ; sectors per cluster
    mov cx, 512         ; bytes per sector
    mov dx, 2847        ; total clusters (FAT12 1.44MB geometry)
    clc
    jmp .restore

.bad_drive:
    mov ax, 0xFFFF
    xor bx, bx
    xor cx, cx
    xor dx, dx
    stc

.restore:
    call restore_current_dir
    pop ds
    pop si
    iret
