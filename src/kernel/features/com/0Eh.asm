com_0Eh:
    push bx
    push ds

    mov ax, 0x2000
    mov ds, ax

    mov al, dl
    add al, 'A'
    call fs_change_drive_letter
    jc .bad_drive

    xor ah, ah
    mov al, [drive_count]
    clc
    jmp .done

.bad_drive:
    mov ax, 0x000F
    stc

.done:
    pop ds
    pop bx
    iret
