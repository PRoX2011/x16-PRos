[BITS 16]
[ORG 800h]

start:
    mov ax, 0x12
    int 0x10
    
    mov si, wmsg
    call print_string
    
    mov si, help_message
    call print_string
    
    call shell
    
shell:
    mov si, prompt
    call print_string

    call read_command
    call print_newline

    call execute_command
    jmp shell
    
read_command:
    mov di, command_buffer
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, 255
    jge .done_read
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp di, command_buffer
    je .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0
    ret

execute_command:
    mov si, command_buffer
    mov di, help_str
    call compare_strings
    je do_help

    mov si, command_buffer
    mov di, cls_str
    call compare_strings
    je do_cls
    
    mov si, command_buffer
    mov di, back_str
    call compare_strings
    je do_back
    
    mov si, command_buffer
    mov di, fsec_str
    call compare_strings
    je do_fsec
    
    call unknown_command
    ret

compare_strings:
    xor cx, cx
.next_char:
    lodsb
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal
    inc di
    jmp .next_char
.not_equal:
    ret
.equal:
    ret

do_help:
    mov si, help_message
    call print_string
    ret

do_cls:
    call clear_screen
    ret
 
do_back:
    int 0x19
    ret

do_fsec:
    mov si, sector_prompt
    call print_string
    call read_number
    mov [sector_num], cl
    
    mov di, buffer
    mov cx, 512
    mov al, 0x00
    rep stosb
    
    mov dl, 0x80
    mov cx, 3
.write_attempt:
    push cx
    mov ah, 0x03
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, [sector_num]
    mov bx, buffer
    int 0x13
    jnc .write_ok
    pop cx
    loop .write_attempt
    jmp .write_error
    
.write_ok:
    pop cx
    mov si, success_msg
    call print_string_green
    ret
    
.write_error:
    call convert_ah_to_hex
    mov si, error_msg
    call print_string_red
    ret

convert_ah_to_hex:
    push ax
    push bx
    mov bx, hex_nums

    ; Convert high nibble
    mov al, ah
    shr al, 4
    xlatb
    mov [error_code_hex], al

    ; Convert low nibble
    mov al, ah
    and al, 0x0F
    xlatb
    mov [error_code_hex+1], al

    pop bx
    pop ax
    ret

read_number:
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp al, '0'
    jb .read_loop
    cmp al, '9'
    ja .read_loop
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    sub al, '0'
    mov ch, cl
    mov cl, al
    mov al, ch
    mov ah, 0
    mov dx, 10
    mul dx
    add al, cl
    mov cl, al
    jmp .read_loop

.handle_backspace:
    cmp cx, 0
    je .read_loop
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    mov al, cl
    mov ah, 0
    mov dl, 10
    div dl
    mov cl, al
    jmp .read_loop

.done_read:
    call print_newline
    ret

unknown_command:
    mov si, unknown_msg
    call print_string_red
    call print_newline
    ret
        
print_string:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
print_string_green:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0A
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
       
print_string_red:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0C
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret
    
clear_screen:
    mov ax, 0x12
    int 0x10
    ret

wmsg db '============================= [ Disk tools ] ===================================', 13, 10, 0
prompt db '[DISK TOOLS] > ', 0
help_str db 'help', 0
cls_str db 'cls', 0
back_str db 'back', 0
fsec_str db 'FSEC', 0
command_buffer db 25 dup(0)
help_message db 13, 10, "+-------------------------------------+", 13, 10
             db "| Comands:                            |", 13, 10
             db "|     help - print the help menu      |", 13, 10
             db "|     cls - clear screen              |", 13, 10
             db "|     back - back to the terminal     |", 13, 10
             db "|     FSEC - format disk sector       |", 13, 10
             db "+-------------------------------------+", 13, 10, 13, 10, 0
unknown_msg db 'Unknown operation.', 0
sector_prompt db 'Sector number: ', 0
sector_num db 0
buffer times 512 db 0
success_msg db 'Sector formatted', 13, 10, 0
error_msg db 'Format error! Code: 0x'
error_code_hex db '00', 13, 10, 0
hex_nums db "0123456789ABCDEF"
