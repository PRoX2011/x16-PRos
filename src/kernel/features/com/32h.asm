com_32h:
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    call save_current_dir
    mov al, dl
    add al, 'A' - 1
    test dl, dl
    jnz .have_drive
    mov al, [current_drive_char]
.have_drive:
    push ax
    call fs_change_drive_letter
    pop ax
    jc .no_drive
    call dosvars_sync_drives
    call restore_current_dir

    sub al, 'A'
    cmp al, DOSVARS_DRIVES
    jae .none
    mov ah, DPB_LEN
    mul ah
    add ax, DOSVARS_DPB
    mov bx, ax
    push es
    call dosvars_seg
    push es
    pop ds
    pop es
    xor al, al
    iret

.no_drive:
    call restore_current_dir
.none:
    mov al, 0xFF
    iret
