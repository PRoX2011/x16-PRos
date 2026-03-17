com_16h:
    call fcb_to_path_buffer

    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x04
    int 0x22

    pop ds
    pop dx

    jnc .delete_existing

.create:
    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x05
    int 0x22

    pop ds
    pop dx

    jc .fail
    jmp .fill_fcb

.delete_existing:
    push dx
    push ds

    mov si, com_path_buffer
    mov ah, 0x06
    int 0x22

    pop ds
    pop dx

    jmp .create

.fill_fcb:
    push ds
    pop es

    mov di, dx

    mov word [es:di+0x10], 0
    mov word [es:di+0x12], 0

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

    mov word [es:di+0x0E], 128
    mov word [es:di+0x0C], 0
    mov byte [es:di+0x20], 0

    xor al, al
    clc
    iret

.fail:
    mov al, 0xFF
    stc

    iret