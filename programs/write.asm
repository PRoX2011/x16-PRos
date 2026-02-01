; ==================================================================
; x16-PRos -- WRITER. Simple text editor.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

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

    call draw_hints

    ; Clear editing area (lines 3 to 22)
    mov ax, 0600h
    mov bh, 0x0F
    mov cx, 0300h             ; Start at line 3, column 0
    mov dx, 164Fh             ; End at line 22, column 79
    int 10h

    ; Set cursor to start of text area
    mov dl, 0
    mov dh, 3
    call set_cursor_pos
    mov word [text_size], 0   ; Initialize text size counter

    jmp command_loop

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

    ; Arrow keys
    cmp ah, 48h               ; Up arrow
    jz arrow_up
    cmp ah, 50h               ; Down arrow
    jz arrow_down
    cmp ah, 4Bh               ; Left arrow
    jz arrow_left
    cmp ah, 4Dh               ; Right arrow
    jz arrow_right

    mov si, [text_size]
    cmp si, 510               ; Reserve space for CR+LF
    jge command_loop

    mov [string + si], al
    inc word [text_size]
    mov ah, 09h
    mov bx, 0004h
    mov bl, 0x0F
    mov cx, 1
    int 10h

    add dl, 1
    call set_cursor_pos
    jmp command_loop

arrow_up:
    cmp dh, 3
    jle command_loop
    dec dh
    call set_cursor_pos
    jmp command_loop

arrow_down:
    cmp dh, 22
    jge command_loop
    inc dh
    call set_cursor_pos
    jmp command_loop

arrow_left:
    cmp dl, 0
    je .wrap_left
    dec dl
    call set_cursor_pos
    jmp command_loop
.wrap_left:
    cmp dh, 3
    jle command_loop
    dec dh
    mov dl, 79
    call set_cursor_pos
    jmp command_loop

arrow_right:
    cmp dl, 79
    jge .wrap_right
    inc dl
    call set_cursor_pos
    jmp command_loop
.wrap_right:
    cmp dh, 22
    jge command_loop
    inc dh
    mov dl, 0
    call set_cursor_pos
    jmp command_loop

new_line:
    mov si, [text_size]
    cmp si, 510               ; Reserve space for CR+LF
    jge command_loop
    mov byte [string + si], 0x0D
    inc si
    mov byte [string + si], 0x0A
    inc si
    mov [text_size], si
    add dh, 1
    xor dl, dl
    call set_cursor_pos
    jmp command_loop

save_text:
    ; Clear filename buffer
    mov di, filename
    mov cx, 12
    mov al, 0
    rep stosb

    ; Prompt for filename
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, save_prompt
    call print_string

    ; Get filename input
    mov di, filename
    mov cx, 0
    call get_filename_input
    jc .no_filename

    ; Save file using API with text_size
    mov cx, [text_size]       ; CX = размер текста
    mov si, filename          ; SI = указатель на имя файла
    mov bx, string            ; BX = указатель на данные
    mov ah, 0x03              ; Функция записи
    int 0x22
    jc .save_failed

    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, clear_msg
    call print_string

    ; Display success message
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, saved_msg
    call print_string
    jmp .save_done

.save_failed:
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, save_failed_msg
    call print_string

.save_done:
    mov ah, 00h
    int 16h
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, clear_msg
    call print_string

    mov dl, 0
    mov dh, 3
    call set_cursor_pos
    jmp command_loop

.no_filename:
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, no_filename_msg
    call print_string
    mov ah, 00h
    int 16h
    mov dl, 0
    mov dh, 23
    call set_cursor_pos
    mov si, clear_msg
    call print_string
    mov dl, 0
    mov dh, 3
    call set_cursor_pos
    jmp command_loop

delete_symbol:
    mov si, [text_size]
    cmp si, 0
    je command_loop
    cmp dl, 0
    jne .delete_char
    cmp dh, 3
    jz command_loop
    sub dh, 1
    mov dl, 79
    ; Check if previous character is LF
    mov bx, si
    sub bx, 1
    cmp byte [string + bx], 0x0A
    je .delete_crlf
    jmp .update_cursor

.delete_char:
    sub dl, 1
    ; Check if previous character is LF
    mov bx, si
    sub bx, 1
    cmp byte [string + bx], 0x0A
    je .delete_crlf
    jmp .update_cursor

.delete_crlf:
    cmp si, 1
    je command_loop
    sub si, 1
    cmp byte [string + si - 1], 0x0D
    jne .update_after_delete
    dec si
    sub dl, 1
    cmp dl, 0
    jne .update_after_delete
    cmp dh, 3
    jz command_loop
    sub dh, 1
    mov dl, 79
    jmp .update_after_delete

.update_cursor:
    call set_cursor_pos
    mov al, 20h
    mov [string + si], al
    mov ah, 09h
    mov bx, 0004h
    mov bl, 0x0F
    mov cx, 1
    int 10h
    dec si
.update_after_delete:
    mov [text_size], si
    jmp command_loop

esc_exit:
    mov ax, 0x12
    int 0x10
    ret

draw_hints:
    mov dl, 0
    mov dh, 24
    call set_cursor_pos

    mov si, msg
    call print_string_blue_bg

    mov dl, 0
    mov dh, 0
    call set_cursor_pos

    mov si, helper
    call print_string_blue_bg

    ret

print_message:
    mov bl, 0x1F
    mov ax, 1301h
    int 10h
    ret

print_string_blue_bg:
    pusha
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0A
    je .newline
    cmp al, 0x0D
    je .carriage
    ; print char with attr
    mov ah, 0x09
    mov bl, 0x1F
    mov cx, 1
    int 0x10
    ; move cursor right
    mov ah, 0x03
    xor bh, bh
    int 0x10
    inc dl
    cmp dl, 80
    jb .no_wrap
    mov dl, 0
    inc dh
.no_wrap:
    mov ah, 0x02
    int 0x10
    jmp .loop
.newline:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    inc dh
    mov dl, 0
    mov ah, 0x02
    int 0x10
    jmp .loop
.carriage:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 0
    mov ah, 0x02
    int 0x10
    jmp .loop
.done:
    popa
    ret

print_string:
    pusha
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0A
    je .newline
    cmp al, 0x0D
    je .carriage
    ; print char with attr
    mov ah, 0x09
    mov bl, 0x0F
    mov cx, 1
    int 0x10
    ; move cursor right
    mov ah, 0x03
    xor bh, bh
    int 0x10
    inc dl
    cmp dl, 80
    jb .no_wrap
    mov dl, 0
    inc dh
.no_wrap:
    mov ah, 0x02
    int 0x10
    jmp .loop
.newline:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    inc dh
    mov dl, 0
    mov ah, 0x02
    int 0x10
    jmp .loop
.carriage:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 0
    mov ah, 0x02
    int 0x10
    jmp .loop
.done:
    popa
    ret

set_cursor_pos:
    mov ah, 2h
    xor bh, bh
    int 10h
    ret

get_filename_input:
    pusha
.get_filename:
    mov ah, 00h
    int 16h
    cmp al, 0Dh
    je .filename_done
    cmp al, 08h
    je .handle_backspace
    cmp cx, 11
    jge .get_filename
    stosb
    mov ah, 0Eh
    mov bl, 0x0F
    int 10h
    inc cx
    jmp .get_filename

.handle_backspace:
    cmp cx, 0
    je .get_filename
    dec di
    dec cx
    mov al, 08h
    mov ah, 0Eh
    int 10h
    mov al, ' '
    int 10h
    mov al, 08h
    int 10h
    jmp .get_filename

.filename_done:
    mov byte [di], 0
    cmp cx, 0
    je .no_filename
    popa
    clc
    ret

.no_filename:
    popa
    stc
    ret

; --- Data Section ---

msg               db 'PRos writer v0.3                                                                  ',  0
helper            db '[F2] - save text     [ESC] - quit                                               ', 13, 10, 0
saved_msg         db 'Text saved!', 0
save_prompt       db 'Enter filename to save: ', 0
save_failed_msg   db 'Failed to save file', 0
no_filename_msg   db 'No filename entered', 0
clear_msg         db 80 dup(' '), 0
text_size         dw 0
filename times 12 db 0
string times 512  db 0