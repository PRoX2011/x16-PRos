com_1Bh:
    xor dl, dl
com_1Ch:
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    call save_current_dir
    mov al, dl
    add al, 'A' - 1
    test dl, dl
    jnz .have_drive
    mov al, [current_drive_char]
.have_drive:
    call fs_change_drive_letter
    jc .no_drive

    mov byte [dos_media_id], 0xF0
    cmp byte [current_disk], 0x80
    jb .removable
    mov byte [dos_media_id], 0xF8
.removable:
    mov al, [fs_spc]
    mov cx, 512
    mov dx, [fs_total_clus]
    mov bx, dos_media_id
    call restore_current_dir
    iret

.no_drive:
    call restore_current_dir
    mov al, 0xFF
    iret

dos_media_id db 0
