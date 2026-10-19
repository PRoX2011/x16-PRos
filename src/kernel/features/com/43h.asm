com_43h:
    push bp
    mov bp, sp

    cmp al, 0x00
    jne .set_ok

    call com_copy_path_from_caller
    push bx
    push ds
    push es
    push si
    push dx
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call path_split
    jc .missing_pop

    mov cx, 0x0010
    cmp byte [si], 0
    je .have_attr
    mov [cs:.name], si
    mov ax, si
    call fs_file_exists
    jc .looked
    mov cx, 0x0020
    mov ax, [cs:.name]
    call fs_is_directory
    jc .have_attr
    xor ah, ah
    mov cx, ax
.have_attr:
    clc
.looked:
    pushf
    call path_restore
    popf
    jc .missing_pop

    pop dx
    pop si
    pop es
    pop ds
    pop bx

    mov ax, cx
    jmp .ok

.missing_pop:
    pop dx
    pop si
    pop es
    pop ds
    pop bx
    jmp .missing

.set_ok:
    xor ax, ax
.ok:
    and word [bp+6], 0xFFFE
    pop bp
    iret

.missing:
    mov ax, 0x0002
    or word [bp+6], 1
    pop bp
    iret

.name dw 0
