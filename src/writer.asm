[BITS 16]
[ORG 800h]

start:
    mov ax, 0600h
    mov bh, 0x0F
    xor cx, cx
    mov dx, 184Fh
    int 10h
    
    mov ax, 0x03
    int 0x10

    mov ah, 0x01
    mov ch, 0x00
    mov cl, 0x07
    int 0x10

    mov dl, 0
    mov dh, 24
    call set_cursor_pos

    mov bp, msg
    mov cx, 80
    call print_message

    mov dl, 0 
    mov dh, 0
    call set_cursor_pos

    mov bp, helper
    mov cx, 80
    call print_message
    
    
option_loop:
    mov ah, 10h
    int 16h

    cmp ah, 3Bh
    jz load_text
    cmp al, 0Dh
    jz print_text
    jmp option_loop

load_text:
    mov ax, 0000h
    mov es, ax
    mov bx, string
    mov ch, 0
    mov cl, 13
    mov dh, 0
    mov dl, 80h
    mov al, 01h
    mov ah, 02h
    int 13h

    xor dl, dl
    mov dh, 3
    call set_cursor_pos
    mov bp, string
    mov cx, 256
    call print_message2

    mov si, 255
    add dl, 15
    add dh, 3
    call set_cursor_pos
    jmp command_loop

print_text:
    xor dx, dx
    add dh, 3
    call set_cursor_pos
    mov si, 0

command_loop:
    mov ah, 10h
    int 16h

    cmp al, 1Bh
    jz esc_exit
    cmp al, 0Dh
    jz new_line
    cmp ah, 0Eh
    jz delete_symbol
    cmp ah, 3Ch
    jz save_text

    cmp si, 512
    jz command_loop

    mov [string + si], al
    inc si
    mov ah, 09h
    mov bx, 0004h
    mov bl, 0x0F
    mov cx, 1
    int 10h

    add dl, 1
    call set_cursor_pos
    jmp command_loop

new_line:
    add dh, 1
    xor dl, dl
    call set_cursor_pos
    jmp command_loop

save_text:
    mov ax, 0000h
    mov es, ax
    mov ah, 03h
    mov al, 1
    mov ch, 0
    mov cl, 13
    mov dh, 0
    mov dl, 80h
    mov bx, string
    int 13h
    
    mov dl, 0 
    mov dh, 23
    call set_cursor_pos
    
    mov bp, saved_msg
    mov cx, 10
    call print_message3
    
    mov ah, 0x00
    int 0x16
    
    mov dl, 0 
    mov dh, 3
    call set_cursor_pos
    
    jmp command_loop

delete_symbol:
    cmp dl, 0
    jne delete_char
    cmp dh, 3
    jz command_loop
    sub dh, 1
    mov dl, 79
    jmp update_cursor

delete_char:
    sub dl, 1

update_cursor:
    call set_cursor_pos
    mov al, 20h
    mov [string + si], al
    mov ah, 09h
    mov bx, 0004h
    mov bl, 0x0F
    mov cx, 1
    int 10h

    cmp si, 0
    jz command_loop
    dec si
    jmp command_loop

esc_exit:
    ; jmp 500h
    int 0x19

print_message:
    mov bl, 0x1F
    mov ax, 1301h
    int 10h
    ret
    
print_message2:
    mov bl, 0x0F
    mov ax, 1301h
    int 10h
    ret
    
print_message3:
    mov bl, 0x02
    mov ax, 1301h
    int 10h
    ret
    
print_string:
    mov ah, 0Eh
.print_char:
    lodsb
    or al, al
    jz .done
    int 10h
    jmp .print_char
.done:
    ret
    
set_cursor_pos:
    mov ah, 2h
    xor bh, bh
    int 10h
    ret

msg db 'PRos writer v0.1                                                               ', 13, 10, 0
helper db 'ENTER - start typing     F1 - load text     F2 - save text     ESC - quit       ', 13, 10
saved_msg db 'Text saved!', 13, 10, 0
       
string db 512 dup(?)
