com_0Eh:
    push bx
    push ds

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    push es
    mov es, ax

    mov al, dl
    add al, 'A'
    call fs_change_drive_letter
    jc .bad_drive

    push cx
    push si
    mov al, 5
    mov si, drives_table
    xor cx, cx
    mov cl, [drive_count]
.top:
    jcxz .counted
    mov ah, [si]
    sub ah, 'A' - 1
    cmp ah, al
    jbe .next
    mov al, ah
.next:
    add si, 3
    dec cx
    jmp .top
.counted:
    pop si
    pop cx
    xor ah, ah
    clc
    jmp .done

.bad_drive:
    mov ax, 0x000F
    stc

.done:
    pop es
    pop ds
    pop bx
    iret
