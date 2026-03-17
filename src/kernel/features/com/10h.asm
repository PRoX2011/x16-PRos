com_10h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x04
    int 0x22

    pop ds
    pop dx

    jc .fail

    push ds
    pop es
    mov di, dx

    mov ah, 0x04
    int 0x1A
    call bcd_to_bin_date
    call date_to_dos
    mov [es:di+0x14], ax

    mov ah, 0x02
    int 0x1A
    call bcd_to_bin_time
    call time_to_dos
    mov [es:di+0x16], ax

    xor al, al
    clc
    iret

.fail:
    mov al, 0xFF
    stc

    iret