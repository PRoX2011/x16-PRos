; ==================================================================
; x16-PRos - Simple encryption/decryption functions
; Copyright (C) 2025 PRoX2011
; ==================================================================

; Encryption key (change if u want)
key db 0x5C, 0x44, 0xCF, 0x08, 0x8B, 0x47, 0x1B, 0x33, 0x2C, 0x8E, 0xB9, 0x59, 0xA2, 0x3A, 0x46, 0xAF,
    db 0x0A, 0x9E, 0xC7, 0x3D, 0x63, 0x59, 0x08, 0x5F, 0x89, 0x06, 0x8A, 0x07, 0xB3, 0xF7, 0x96, 0x09,
    db 0x73, 0x03, 0xBB, 0x3F, 0x30, 0x97, 0x63, 0x7C, 0xB7, 0x16, 0xD7, 0xD3, 0xD2, 0x8D, 0x10, 0x36,
    db 0x2D, 0x1E, 0xDF, 0x33, 0x6F, 0x0B, 0x5B, 0x1B, 0x53, 0x42, 0xF9, 0x02, 0x78, 0xB7, 0x53, 0xE1
key_len equ 64

; -----------------------------------------------------------------------------
; encrypt_string -- Encrypt a string using repeating XOR
; IN:  SI = pointer to input string (null-terminated or with length)
;      DI = pointer to output buffer
;      CX = length of string (if 0, assumes null-terminated)
; OUT: Encrypted data in DI, carry clear on success
encrypt_string:
    pusha
    mov bx, 0

.encrypt_loop:
    cmp cx, 0
    je .check_null
    jmp .do_xor

.check_null:
    lodsb
    cmp al, 0
    je .done
    dec si

.do_xor:
    lodsb
    push bx
    and bx, key_len-1
    xor al, [key + bx]
    pop bx
    stosb
    inc bx
    dec cx
    cmp cx, 0
    jg .encrypt_loop
    jnz .done
    jmp .encrypt_loop

.done:
    mov byte [di], 0
    clc
    popa
    ret

; -----------------------------------------------------------------------------
; decrypt_string -- Decrypt a string using repeating XOR (same as encrypt since XOR is involution)
; IN:  SI = pointer to input string (encrypted)
;      DI = pointer to output buffer
;      CX = length of string (if 0, assumes null-terminated)
; OUT: Decrypted data in DI, carry clear on success
decrypt_string:
    jmp encrypt_string