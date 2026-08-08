; ==================================================================
; x16-PRos - DUMP.BIN. Hexadecimal file dump utility.
; Usage: DUMP <filename>
; Shows the file contents as hex bytes with offsets.
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov si, 0x7F00
    cmp byte [si], 0
    jne .has_param

    mov ah, 0x01
    mov si, usage_msg
    int 0x21
    ret

.has_param:
    ; Load the file to 0x3000:0x0000 via the PRos FS API.
    mov ah, 0x0D
    mov cx, 0
    mov dx, 0x3000
    int 0x22
    jnc .loaded

    mov ah, 0x04
    mov si, err_msg
    int 0x21
    ret

.loaded:
    ; DX:AX = file size
    mov word [data_size], ax
    mov word [data_size+2], dx

    mov ah, 0x01
    mov si, header_msg
    int 0x21

    mov word [data_offset], 0

.dump_loop:
    mov ax, [data_offset]
    cmp ax, [data_size]
    jae .done

    ; print the offset as 4 hex digits
    mov ax, [data_offset]
    call print_hex4
    mov ah, 0x0E
    mov al, ':'
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    mov al, ' '
    int 0x10

    ; how many bytes in this row (16 or fewer at the end)
    mov ax, [data_size]
    sub ax, [data_offset]
    cmp ax, 16
    jae .full_row
    mov cx, ax
    jmp .row_len_ok
.full_row:
    mov cx, 16
.row_len_ok:

    push es
    mov ax, 0x3000
    mov es, ax
    mov si, [data_offset]
.byte_loop:
    mov al, [es:si]
    call print_hex2
    mov ah, 0x0E
    mov al, ' '
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    inc si
    loop .byte_loop
    pop es

    mov ah, 0x0E
    mov al, 0x0D
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    mov al, 0x0A
    int 0x10

    add word [data_offset], 16
    jmp .dump_loop

.done:
    mov ah, 0x01
    mov si, done_msg
    int 0x21
    ret

; ------------------------------------------------------------------
; PRINT_HEX2 - print AL as two hex digits.
; ------------------------------------------------------------------
print_hex2:
    push ax
    push bx
    mov bl, al
    shr al, 4
    call .nibble
    mov al, bl
    and al, 0x0F
    call .nibble
    pop bx
    pop ax
    ret
.nibble:
    add al, '0'
    cmp al, '9'
    jbe .out
    add al, 7
.out:
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    ret

; ------------------------------------------------------------------
; PRINT_HEX4 - print AX as four hex digits.
; ------------------------------------------------------------------
print_hex4:
    push ax
    push bx
    mov bx, ax
    mov al, bh
    shr al, 4
    call print_hex2.nibble
    mov al, bh
    and al, 0x0F
    call print_hex2.nibble
    mov al, bl
    shr al, 4
    call print_hex2.nibble
    mov al, bl
    and al, 0x0F
    call print_hex2.nibble
    pop bx
    pop ax
    ret

; ---- data ----
usage_msg  db 'Usage: DUMP <filename>', 13, 10, 0
err_msg    db 'Error: cannot load file', 13, 10, 0
header_msg db 'Offset  Bytes', 13, 10, 0
done_msg   db 13, 10, 0

data_size  dd 0
data_offset dw 0
