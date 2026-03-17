; ========================================================================
; FCB helper functions for DOS emulation
;
; Provides utilities to convert FCB structures to normal filenames
; and format DOS date/time values
; ========================================================================

; fcb_to_path_buffer: convert FCB at caller DS:DX to ASCIIZ in com_path_buffer
; IN:  DS:DX = pointer to FCB (caller's segment)
; OUT: com_path_buffer filled, DS/ES restored
fcb_to_path_buffer:
    push ax
    push cx
    push si
    push di
    push es
    push ds             ; save caller DS

    mov si, dx
    inc si              ; skip drive byte, SI = filename field

    ; DS = caller segment (for reading FCB)
    ; ES = 0x2000 (for writing com_path_buffer)
    mov ax, 0x2000
    mov es, ax
    mov di, com_path_buffer

    mov cx, 8
.copy_name:
    mov al, [ds:si]     ; read from caller segment
    inc si
    cmp al, ' '
    je .name_done
    stosb
    loop .copy_name
.name_done:
    add si, cx

    mov al, '.'
    stosb

    mov cx, 3
.copy_ext:
    mov al, [ds:si]     ; read from caller segment
    inc si
    cmp al, ' '
    je .ext_done
    stosb
    loop .copy_ext
.ext_done:

    xor al, al
    stosb

    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; fcb_str_to_normal: convert FCB name at caller DS:SI to ASCIIZ in com_path_buffer2
; IN:  DS:SI = pointer to 11-byte FCB name (caller's segment)
; OUT: com_path_buffer2 filled, DS/ES restored
fcb_str_to_normal:
    push ax
    push cx
    push si
    push di
    push es
    push ds             ; save caller DS

    ; DS = caller segment (for reading)
    ; ES = 0x2000 (for writing)
    mov ax, 0x2000
    mov es, ax
    mov di, com_path_buffer2

    mov cx, 8
.copy_name:
    mov al, [ds:si]     ; read from caller segment
    inc si
    cmp al, ' '
    je .name_done
    stosb
    loop .copy_name
.name_done:
    add si, cx

    mov al, '.'
    stosb

    mov cx, 3
.copy_ext:
    mov al, [ds:si]     ; read from caller segment
    inc si
    cmp al, ' '
    je .ext_done
    stosb
    loop .copy_ext
.ext_done:

    xor al, al
    stosb

    pop ds
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; date_to_dos: convert date to DOS packed format
; IN:  CL = year (0-99), DH = month (1-12), DL = day (1-31)
; OUT: AX = packed DOS date ((year-1980)<<9 | month<<5 | day)
date_to_dos:
    push cx
    push dx

    xor ah, ah
    mov al, cl
    add ax, 20          ; century offset: year + 2000 - 1980
    sub ax, 80
    shl ax, 9           ; year in bits 15-9

    xor ch, ch
    mov cl, dh          ; month
    shl cx, 5           ; month in bits 8-5
    or ax, cx

    xor dh, dh          ; day in bits 4-0
    or ax, dx

    pop dx
    pop cx
    ret

; time_to_dos: convert time to DOS packed format
; IN:  CH = hours (0-23), CL = minutes (0-59), DH = seconds (0-59)
; OUT: AX = packed DOS time (hours<<11 | minutes<<5 | seconds/2)
time_to_dos:
    push cx
    push dx

    xor ah, ah
    mov al, ch          ; hours
    shl ax, 11          ; hours in bits 15-11

    push ax
    xor ah, ah
    mov al, cl          ; minutes
    shl ax, 5           ; minutes in bits 10-5
    mov cx, ax
    pop ax
    or ax, cx

    mov cl, dh          ; seconds
    shr cl, 1           ; seconds/2 in bits 4-0
    xor ch, ch
    or ax, cx

    pop dx
    pop cx
    ret
