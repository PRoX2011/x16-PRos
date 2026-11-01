com_56h:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    push ds
    mov ax, es
    mov ds, ax
    mov si, di
    mov ax, KERNEL_DATA_SEG
    mov es, ax
    mov di, rename_new
    mov cx, 79
    call .copy_name
    pop ds

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call path_split
    jc .missing
    cmp byte [si], 0
    je .missing_split
    mov di, .old_copy
    mov cx, 12
    call .copy_name
    mov ax, .old_copy
    call fs_is_directory
    setnc [cs:.old_is_dir]
    mov ax, .old_copy
    call fs_get_file_size
    jc .missing_split
    mov [cs:.first], cx
    mov [cs:.size_lo], bx
    mov [cs:.size_hi], dx
    mov ax, [current_dir_cluster]
    mov [cs:.old_dir], ax
    mov al, [current_drive_char]
    mov [cs:.old_drive], al
    call path_restore

    mov si, rename_new
    mov di, com_path_buffer
    mov cx, 79
    call .copy_name
    call path_split
    jc .no_path
    cmp byte [si], 0
    je .no_path_split
    mov [cs:.new_name], si

    mov al, [current_drive_char]
    cmp al, [cs:.old_drive]
    jne .other_drive
    mov ax, si
    call fs_file_exists
    jnc .refused_split

    mov ax, [current_dir_cluster]
    cmp ax, [cs:.old_dir]
    jne .move

    mov ax, .old_copy
    mov bx, [cs:.new_name]
    call fs_rename_file
    jc .refused_split
    jmp .ok_split

.move:
    cmp byte [cs:.old_is_dir], 0
    jne .refused_split
    mov ax, [cs:.new_name]
    call fs_create_file
    jc .refused_split
    mov ax, [cs:.new_name]
    mov bx, [cs:.first]
    mov cx, [cs:.size_lo]
    mov dx, [cs:.size_hi]
    call fs_set_file_info
    jc .refused_split

    push word [current_dir_cluster]
    mov ax, [cs:.old_dir]
    mov [current_dir_cluster], ax
    mov ax, .old_copy
    xor bx, bx
    xor cx, cx
    xor dx, dx
    call fs_set_file_info
    mov ax, .old_copy
    call fs_remove_file
    pop word [current_dir_cluster]

.ok_split:
    call path_restore
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

.missing_split:
    call path_restore
.missing:
    mov ax, 0x0002
    jmp .fail

.no_path_split:
    call path_restore
.no_path:
    mov ax, 0x0003
    jmp .fail

.other_drive:
    call path_restore
    mov ax, 0x0011
    jmp .fail

.refused_split:
    call path_restore
    mov ax, 0x0005

.fail:
    or word [bp+6], 1
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

.copy_name:
    cld
.loop:
    lodsb
    stosb
    test al, al
    jz .copied
    loop .loop
    xor al, al
    stosb
.copied:
    ret

.old_copy   times 13 db 0
.new_name   dw 0
.first      dw 0
.size_lo    dw 0
.size_hi    dw 0
.old_dir    dw 0
.old_drive  db 0
.old_is_dir db 0

rename_new times 80 db 0
