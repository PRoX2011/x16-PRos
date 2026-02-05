log_okay:
    push si
    mov si, okay_message
    call print_string_green
    pop si
    call print_string
    call log_newline
    call log_delay
    ret

log_warn:
    push si
    mov si, warn_message
    call print_string_yellow
    pop si
    call print_string
    call log_newline
    call log_delay
    ret

log_error:
    push si
    mov si, error_message
    call print_string_red
    pop si
    call print_string
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

; Log messages
error_message    db '[ ERROR ] ', 0
okay_message     db '[ OKAY ]  ', 0
warn_message     db '[ WARN ]  ', 0