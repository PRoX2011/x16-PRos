; ==================================================================
; x16-PRos -- MEMORY. Memory viewer.
; Copyright (C) 2025 PRoX2011
;
; Made by ??? and PRoX-dev 
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    call clear_screen
    call draw_interface
    call initialize_memory_view
    jmp main_loop

clear_screen:
    mov ax, 0x12
    int 0x10
    ret

draw_interface:
    mov si, title_msg
    call print_string
    mov si, help_msg
    call print_string
    mov si, address_msg
    call print_string
    ret

initialize_memory_view:
    mov word [current_address], 0x0000
    ret

main_loop:
    call display_memory
    call get_user_input
    jmp main_loop

display_memory:
    push es
    mov ax, [current_address]
    shr ax, 4
    mov es, ax
    
    ; Display address
    mov si, current_address_display
    mov ax, [current_address]
    call word_to_hex
    mov si, current_address_display
    call print_string
    
    ; Display 16 lines of 16 bytes each
    mov cx, 16
    mov di, 0
    mov bx, 0
    
.display_line:
    ; Display 16 bytes as hex with colors
    mov cx, 16
    push di
    
.hex_loop:
    mov al, [es:di]
    push cx
    call byte_to_hex_temp  ; Convert to hex in temp buffer
    
    ; Calculate and set color
    mov al, [es:di]
    call calculate_color
    mov bl, al
    
    ; Print first hex digit
    mov ah, 0x0E
    mov bh, 0x00
    mov al, [hex_byte_temp]
    int 0x10
    
    ; Print second hex digit
    mov ah, 0x0E
    mov al, [hex_byte_temp+1]
    int 0x10
    
    ; Print space (in default color)
    mov bl, 0x0F
    mov ah, 0x0E
    mov al, ' '
    int 0x10
    
    pop cx
    inc di
    loop .hex_loop
    
    ; Display ASCII representation
    mov bl, 0x0F
    mov ah, 0x0E
    mov al, '|'
    int 0x10
    mov al, ' '
    int 0x10
    
    pop di
    push di
    mov cx, 16
    
.ascii_loop:
    mov al, [es:di]
    cmp al, 32
    jb .non_printable
    cmp al, 126
    ja .non_printable
    jmp .print_ascii
    
.non_printable:
    mov al, '.'    ; Replace non-printable with dot
    
.print_ascii:
    int 0x10
    inc di
    loop .ascii_loop
    
    call print_newline
    pop di
    add di, 16
    inc bx
    cmp bx, 16
    jb .display_line
    
    pop es
    ret

; Convert AL to hex and store in temp buffer
byte_to_hex_temp:
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov [hex_byte_temp], al
    mov al, ah
    and al, 0x0F
    call nibble_to_hex
    mov [hex_byte_temp+1], al
    ret

calculate_color:
    push bx
    mov bl, al
    
    mov bh, bl
    and bh, 0xC0        ; Bits 7-6
    shr bh, 6
    mov al, bh
    add al, 1            ; Background (1-4)
    
    mov bh, bl
    and bh, 0x38        ; Bits 5-3
    shr bh, 3
    add bh, 4            ; Foreground (4-11)
    
    ; Combine
    shl al, 4
    or al, bh
    pop bx
    ret

get_user_input:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x1B        ; ESC
    je exit_program
    cmp al, 'f'
    je move_start
    cmp al, 'w'
    je move_up
    cmp al, 's'
    je move_down
    jmp get_user_input

move_start:
    mov word [current_address], 0x0000
    ret

move_up:
    sub word [current_address], 0x0010
    ret

move_down:
    add word [current_address], 0x0010
    ret

exit_program:
    int 0x19

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

print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

byte_to_hex:
    push ax
    mov ah, al
    shr al, 4
    call nibble_to_hex
    mov [si], al
    mov al, ah
    and al, 0x0F
    call nibble_to_hex
    mov [si+1], al
    pop ax
    ret

word_to_hex:
    push ax
    xchg ah, al
    call byte_to_hex
    xchg ah, al
    add si, 2
    call byte_to_hex
    sub si, 2
    pop ax
    ret

nibble_to_hex:
    add al, '0'
    cmp al, '9'
    jbe .done
    add al, 7
.done:
    ret

title_msg db '-PRos Memory Viewer v0.1-', 0x0D, 0x0A, 0
help_msg db 'Keys: W/S-navigate (-0010; +0010), F-jump 0000, ESC-exit', 0x0D, 0x0A, 0
address_msg db 'Current address: ', 0

current_address dw 0x0000
current_address_display db '0000: ', 0
hex_byte_temp db '00', 0  ; Temporary buffer for byte conversion

times 510-($-$$) db 0
dw 0xAA55