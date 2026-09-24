com_3Bh:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    mov ax, [current_dir_cluster]
    mov [cd_saved_cluster], ax
    mov si, current_directory
    mov di, cd_saved_path
    mov cx, 64
    cld
    rep movsb

    mov si, com_path_buffer

    cmp byte [si + 1], ':'
    jne .no_drive
    mov al, [si]
    cmp al, 'a'
    jb .letter_ready
    cmp al, 'z'
    ja .letter_ready
    sub al, 'a' - 'A'
.letter_ready:
    cmp al, [current_drive_char]
    jne .fail
    add si, 2

.no_drive:
    cmp byte [si], '\'
    je .from_root
    cmp byte [si], '/'
    jne .walk
.from_root:
    inc si
    mov word [current_dir_cluster], 0
    mov byte [current_directory], 0

.walk:
    cmp byte [si], 0
    je .done

    mov di, cd_component
    mov cx, 12
.copy_component:
    mov al, [si]
    test al, al
    je .component_end
    cmp al, '\'
    je .component_end
    cmp al, '/'
    je .component_end
    mov [di], al
    inc si
    inc di
    loop .copy_component
    jmp .fail

.component_end:
    mov byte [di], 0
    cmp byte [si], 0
    je .have_component
    inc si

.have_component:
    cmp byte [cd_component], 0
    je .walk

    cmp word [cd_component], '.'
    je .walk

    mov ax, cd_component
    call fs_change_directory
    jc .fail
    jmp .walk

.done:
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

.fail:
    mov ax, [cd_saved_cluster]
    mov [current_dir_cluster], ax
    push ds
    pop es
    mov si, cd_saved_path
    mov di, current_directory
    mov cx, 64
    cld
    rep movsb

    mov ax, 0x0003
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

cd_component    times 16 db 0
cd_saved_path   times 64 db 0
cd_saved_cluster dw 0
