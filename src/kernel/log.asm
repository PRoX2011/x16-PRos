log_buf         times 1024 db 0
log_buf_used    dw 0

log_clear_on_boot:
    pusha
    mov word [log_buf_used], 0
    mov ax, log_filename
    mov bx, log_buf
    xor cx, cx
    call fs_write_file
    popa
    ret

log_okay:
    push si
    mov si, okay_message
    call print_string_green
    pop si
    push si
    call print_string
    pop si
    mov [log_message_ptr], si
    mov byte [log_type_flag], 1
    call log_write_to_file
    call log_newline
    call log_delay
    ret

log_warn:
    push si
    mov si, warn_message
    call print_string_yellow
    pop si
    push si
    call print_string
    pop si
    mov [log_message_ptr], si
    mov byte [log_type_flag], 2
    call log_write_to_file
    call log_newline
    call log_delay
    ret

log_error:
    push si
    mov si, error_message
    call print_string_red
    pop si
    push si
    call print_string
    pop si
    mov [log_message_ptr], si
    mov byte [log_type_flag], 3
    call log_write_to_file
    call log_newline
    call log_delay
    mov ah, 0
    int 16h
    ret

log_newline:
    call print_newline
    ret

log_delay:
    pusha
    mov dx, 100
    call delay_ms
    popa
    ret

log_write_to_file:
    pusha

    mov di, log_buf
    mov ax, [log_buf_used]
    test ax, ax
    jne .buf_ready

    mov ax, log_filename
    call fs_file_exists
    jc .buf_ready

    mov ax, log_filename
    call fs_get_file_size
    jc .buf_ready

    mov ax, bx
    cmp ax, 900
    ja .buf_ready

    mov [log_buf_used], ax
    mov ax, log_filename
    mov cx, log_buf
    call fs_load_file
    jc .reset_buf

    mov ax, [log_buf_used]
    jmp .buf_positioned

.reset_buf:
    mov word [log_buf_used], 0
    xor ax, ax

.buf_ready:
    mov ax, [log_buf_used]

.buf_positioned:
    mov di, log_buf
    add di, ax

    mov al, [log_type_flag]
    cmp al, 1
    je .prefix_okay
    cmp al, 2
    je .prefix_warn
    cmp al, 3
    je .prefix_error
    jmp .write_msg

.prefix_okay:
    mov si, okay_message
    call .append
    jmp .write_msg

.prefix_warn:
    mov si, warn_message
    call .append
    jmp .write_msg

.prefix_error:
    mov si, error_message
    call .append

.write_msg:
    mov si, [log_message_ptr]
    call .append

    mov byte [di], 0x0D
    inc di
    mov byte [di], 0x0A
    inc di

    mov cx, di
    sub cx, log_buf
    mov [log_buf_used], cx

    mov ax, log_filename
    mov bx, log_buf
    call fs_write_file

    popa
    ret

.append:
    push ax
.app_loop:
    lodsb
    cmp al, 0
    je .app_done
    mov [di], al
    inc di
    jmp .app_loop
.app_done:
    pop ax
    ret

error_message   db '[ ERROR ] ', 0
okay_message    db '[ OKAY ]  ', 0
warn_message    db '[ WARN ]  ', 0
log_filename    db 'LOG.TXT', 0
log_type_flag   db 0
log_message_ptr dw 0