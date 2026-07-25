; ==================================================================
; x16-PRos - TESTRAND. Test random number generation API.
; Copyright (C) 2026 Antigravity
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    ; Print Title Message
    mov ah, 0x01
    mov si, title_msg
    int 0x21

    ; Request 16 random bytes from INT 0x21 AH = 0x80
    mov ax, cs
    mov es, ax
    mov di, rand_buf
    mov cx, 16
    mov ah, 0x80
    int 0x21

    ; Print the random bytes in Hex format
    mov cx, 16
    mov si, rand_buf
.hex_loop:
    push cx
    lodsb               ; Load AL from ds:si
    call print_hex_byte
    pop cx
    loop .hex_loop

    ; Print newline
    mov ah, 0x05
    int 0x21

    ret

; ========================================================================
; print_hex_byte - Prints the byte value in AL as two hexadecimal digits
; IN:  AL = byte value to print
; OUT: Nothing (Prints characters to the console)
; ========================================================================
print_hex_byte:
    pusha

    xor dx, dx
    mov dl, al

    ; High nibble
    shr al, 4
    and al, 0x0F
    cmp al, 10
    jb .high_digit
    add al, 'A' - 10 - '0'
.high_digit:
    add al, '0'
    mov [char_buf], al
    mov si, char_buf
    mov ah, 0x01
    int 0x21

    ; Low nibble
    mov al, dl
    and al, 0x0F
    cmp al, 10
    jb .low_digit
    add al, 'A' - 10 - '0'
.low_digit:
    add al, '0'
    mov [char_buf], al
    mov si, char_buf
    mov ah, 0x01
    int 0x21

    ; Space
    mov byte [char_buf], ' '
    mov si, char_buf
    mov ah, 0x01
    int 0x21

    popa
    ret

title_msg db 'Random 16 bytes: ', 0
char_buf  db 0, 0
rand_buf  times 16 db 0
