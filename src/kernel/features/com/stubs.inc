com_2Bh:
    xor al, al
    iret

com_2Dh:
    xor al, al
    iret

com_33h:
    cmp al, 0x00
    je .get
    cmp al, 0x05
    je .boot_drive
    iret
.get:
    xor dl, dl
    iret
.boot_drive:
    mov dl, 1
    iret

com_43h:
    push bp
    mov bp, sp

    cmp al, 0x00
    jne .set_ok

    call com_copy_path_from_caller
    push ds
    push dx
    mov dx, ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov ax, dx
    call fs_file_exists
    pop dx
    pop ds
    jc .missing

    mov cx, 0x0020
    xor ax, ax
    jmp .ok

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

com_44h:
    push bp
    mov bp, sp

    test al, al
    jnz .unsupported

    cmp bx, DOSF_FIRST
    jae .is_file
    mov dx, 0x80D3
    jmp .ok
.is_file:
    xor dx, dx
.ok:
    mov ax, dx
    and word [bp+6], 0xFFFE
    pop bp
    iret

.unsupported:
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret

com_45h:
    push bp
    mov bp, sp
    cmp bx, DOSF_FIRST
    jae .unsupported
    mov ax, bx
    and word [bp+6], 0xFFFE
    pop bp
    iret
.unsupported:
    mov ax, 0x0006
    or word [bp+6], 1
    pop bp
    iret

com_46h:
    push bp
    mov bp, sp
    cmp bx, DOSF_FIRST
    jae .unsupported
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret
.unsupported:
    mov ax, 0x0006
    or word [bp+6], 1
    pop bp
    iret

com_57h:
    push bp
    mov bp, sp
    xor cx, cx
    xor dx, dx
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

com_59h:
    xor ax, ax
    xor bx, bx
    xor cx, cx
    iret

com_62h:
    mov bx, EXE_PSP_SEG
    iret

com_68h:
    push bp
    mov bp, sp
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop bp
    iret

com_unsupported:
    push bp
    mov bp, sp
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret