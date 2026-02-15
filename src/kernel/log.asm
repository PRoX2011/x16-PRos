log_buffer_addr resb 1024 

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
    push ds
    push es
    
    mov ax, log_filename
    call fs_file_exists
    jc .create_new_buffer

    mov ax, log_filename
    mov cx, log_buffer_addr
    call fs_load_file
    
    jc .create_new_buffer
    
    mov di, log_buffer_addr
    add di, bx
    jmp .append_current_msg

.create_new_buffer:
    mov di, log_buffer_addr

.append_current_msg:
    mov al, [log_type_flag]
    cmp al, 1
    je .add_okay_prefix
    cmp al, 2
    je .add_warn_prefix
    cmp al, 3
    je .add_error_prefix
    jmp .add_message_text

.add_okay_prefix:
    mov si, okay_message
    call .copy_string_to_buffer
    jmp .add_message_text

.add_warn_prefix:
    mov si, warn_message
    call .copy_string_to_buffer
    jmp .add_message_text

.add_error_prefix:
    mov si, error_message
    call .copy_string_to_buffer

.add_message_text:
    mov si, [log_message_ptr]
    call .copy_string_to_buffer
    
    mov byte [di], 0x0D
    inc di
    mov byte [di], 0x0A
    inc di
    
    mov cx, di
    sub cx, log_buffer_addr
    
    mov ax, log_filename
    mov bx, log_buffer_addr
    call fs_write_file
    
    pop es
    pop ds
    popa
    ret

.copy_string_to_buffer:
    push ax
.copy_loop:
    lodsb
    cmp al, 0
    je .copy_done
    mov [di], al
    inc di
    jmp .copy_loop
.copy_done:
    pop ax
    ret

; ================= Data Section =================

error_message           db '[ ERROR ] ', 0
okay_message            db '[ OKAY ]  ', 0
warn_message            db '[ WARN ]  ', 0

log_filename            db 'LOG.TXT', 0

log_type_flag           db 0
log_message_ptr         dw 0