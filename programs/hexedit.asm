; HEXEDIT.ASM - Hex Editor for x16-PRos OS
; Copyright (C) @cuzhima
; Usage: hexedit <filename>
;
; WARNING: sirbu12 repaired it, but file is still originally created by @cuzhima

[BITS 16]
[ORG 0x8000]

start:
    cld                 ; Ensure string operations move forward
    mov [filename_ptr], si

    ; Check if filename argument exists
    mov si, [filename_ptr]
    cmp byte [si], 0
    jne .load_file

    mov si, no_args_msg
    call print_string_red
    int 20h             ; Exit to OS

.load_file:
    mov ah, 0x02        ; OS function: Load File
    mov si, [filename_ptr]
    mov cx, file_buffer
    int 22h             ; OS Interrupt
    jc .load_error

    cmp bx, 32768       ; Max size check (32KB)
    jbe .size_ok
    mov si, file_too_big_msg
    call print_string_red
    int 20h

.size_ok:
    mov [file_size], bx
    mov [cursor_pos], word 0
    mov [view_offset], word 0
    mov [edit_mode], byte 0
    mov [byte_buffer], byte 0
    mov [nibble_flag], byte 0
    mov [modified_flag], byte 0
    mov [text_attr], byte 0x07 ; Default Light Grey

.main_loop:
    call display_ui
    call handle_input
    jmp .main_loop

.load_error:
    mov si, load_error_msg
    call print_string_red
    int 20h

;----------------------------------------------------------
; INPUT HANDLING
;----------------------------------------------------------
handle_input:
    mov ah, 0x00
    int 16h             ; BIOS get keystroke

    cmp [edit_mode], byte 1
    je .edit_mode_logic

    ; Navigation Mode
    cmp ah, 0x48 ; Up
    je .move_up
    cmp ah, 0x50 ; Down
    je .move_down
    cmp ah, 0x4B ; Left
    je .move_left
    cmp ah, 0x4D ; Right
    je .move_right
    cmp al, 0x1B ; Esc
    je .exit
    cmp al, 0x0D ; Enter
    je .start_edit
    cmp ah, 0x3B ; F1 Save
    je .save_file
    cmp ah, 0x3C ; F2 Revert
    je .discard_changes
    cmp ah, 0x3D ; F3 Help
    je .show_help
    jmp .done

.move_up:
    cmp [cursor_pos], word 16
    jb .done
    sub [cursor_pos], word 16
    jmp .check_view

.move_down:
    mov ax, [file_size]
    sub ax, 16
    cmp ax, [cursor_pos]
    jbe .done
    add [cursor_pos], word 16
    jmp .check_view

.move_left:
    cmp [cursor_pos], word 0
    je .done
    dec word [cursor_pos]
    jmp .check_view

.move_right:
    mov ax, [file_size]
    dec ax
    cmp [cursor_pos], ax
    jae .done
    inc word [cursor_pos]
    jmp .check_view

.check_view:
    mov ax, [cursor_pos]
    mov bx, [view_offset]
    cmp ax, bx
    jb .scroll_up
    mov dx, bx
    add dx, 256 - 16
    cmp ax, dx
    ja .scroll_down
    jmp .done

.scroll_up:
    sub bx, 256
    jns .set_view
    xor bx, bx
    jmp .set_view

.scroll_down:
    add bx, 256
    mov ax, [file_size]
    sub ax, 256
    jns .set_view
    xor bx, bx
    jmp .set_view

.set_view:
    mov [view_offset], bx
    jmp .done

.start_edit:
    mov [edit_mode], byte 1
    mov [nibble_flag], byte 0
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [si]
    mov [byte_buffer], al
    jmp .done

.save_file:
    mov si, [filename_ptr]
    mov bx, file_buffer
    mov cx, [file_size]
    mov ah, 0x03        ; OS function: Save File
    int 22h
    jc .save_error
    mov [modified_flag], byte 0
    mov si, save_success_msg
    call print_string_green
    mov cx, 30
    call delay
    jmp .done

.save_error:
    mov si, save_error_msg
    call print_string_red
    mov cx, 30
    call delay
    jmp .done

.discard_changes:
    jmp start.load_file ; Fixed jump to outer scope label

.show_help:
    mov si, help_extended_msg
    call print_string_cyan
    mov cx, 100
    call delay
    jmp .done

.exit:
    int 0x19            ; Warm reboot or return to OS

.done:
    ret

.edit_mode_logic:
    cmp al, 0x1B ; Esc
    je .cancel_edit
    cmp al, 0x0D ; Enter
    je .finish_edit
    cmp al, 0x08 ; Backspace
    je .backspace

    call is_hex_digit
    jnc .done_edit
    call char_to_hex

    mov bl, [byte_buffer]
    cmp [nibble_flag], byte 0
    je .high_nibble

    and bl, 0xF0
    or bl, al
    mov [byte_buffer], bl
    mov [nibble_flag], byte 0
    jmp .update_byte

.high_nibble:
    shl al, 4
    and bl, 0x0F
    or bl, al
    mov [byte_buffer], bl
    mov [nibble_flag], byte 1

.update_byte:
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [byte_buffer]
    mov [si], al
    mov [modified_flag], byte 1

.done_edit:
    ret

.backspace:
    mov [nibble_flag], byte 0
    ret

.finish_edit:
    mov [edit_mode], byte 0
    mov [nibble_flag], byte 0
    mov ax, [cursor_pos]
    inc ax
    cmp ax, [file_size]
    jae .stay
    mov [cursor_pos], ax
    jmp .check_view
.stay:
    dec ax
    mov [cursor_pos], ax
    ret

.cancel_edit:
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [si]
    mov [byte_buffer], al
    mov [edit_mode], byte 0
    mov [nibble_flag], byte 0
    ret

;----------------------------------------------------------
; UI DISPLAY
;----------------------------------------------------------
display_ui:
    mov ah, 0x06     ; Clear/Scroll screen
    mov al, 0        ; Full clear
    int 21h          ; Note: Adjust this if your OS uses BIOS INT 10h for CLS

    mov si, [filename_ptr]
    mov di, header_str
    call string_copy

    cmp [modified_flag], byte 0
    je .no_modify
    mov si, modified_str
    call string_append

.no_modify:
    mov si, header_str
    call print_string_cyan

    mov si, size_prefix
    call print_string
    mov ax, [file_size]
    call int_to_string
    mov si, ax
    call print_string

    mov si, pos_prefix
    call print_string
    mov ax, [cursor_pos]
    call int_to_string
    mov si, ax
    call print_string
    call print_newline

    mov si, addr_header
    call print_string_green
    call print_newline

    mov cx, 16
    mov bx, [view_offset]

.hex_loop:
    push cx
    push bx

    mov [text_attr], byte 0x07
    mov ax, bx
    call print_hex_word
    mov al, ':'
    call print_char

    mov cx, 16
    mov si, file_buffer
    add si, bx

.hex_bytes:
    push cx
    mov al, ' '
    call print_char

    mov dx, [cursor_pos]
    cmp dx, bx
    jne .normal_byte
    mov [text_attr], byte 0x0A ; Highlight cursor green

.normal_byte:
    lodsb
    call print_hex_byte

    cmp [edit_mode], byte 1
    jne .restore_color
    mov dx, [cursor_pos]
    cmp dx, bx
    jne .restore_color

    ; Show edit preview
    mov al, '['
    call print_char
    mov al, [byte_buffer]
    call print_hex_byte
    mov al, ']'
    call print_char
    jmp .next_iter

.restore_color:
    mov [text_attr], byte 0x07

.next_iter:
    inc bx
    pop cx
    loop .hex_bytes

    ; ASCII Section
    mov [text_attr], byte 0x07
    mov al, ' '
    call print_char
    mov al, '|'
    call print_char

    pop bx
    push bx
    mov cx, 16
    mov si, file_buffer
    add si, bx

.ascii_bytes:
    lodsb
    cmp al, 32
    jb .dot
    cmp al, 126
    ja .dot
    jmp .print_ascii
.dot:
    mov al, '.'
.print_ascii:
    mov dx, [cursor_pos]
    cmp dx, bx
    jne .norm_ascii
    mov [text_attr], byte 0x0A
    call print_char
    mov [text_attr], byte 0x07
    jmp .a_next
.norm_ascii:
    call print_char
.a_next:
    inc bx
    loop .ascii_bytes

    mov al, '|'
    call print_char
    call print_newline

    pop bx
    add bx, 16
    pop cx
    dec cx
    jnz .hex_loop

    mov si, help_msg
    cmp [edit_mode], byte 1
    jne .print_status
    mov si, edit_help_msg
.print_status:
    call print_string
    call print_newline
    ret

;----------------------------------------------------------
; HELPERS
;----------------------------------------------------------
print_hex_word:
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    ret

print_hex_byte:
    push ax
    shr al, 4
    call print_hex_digit
    pop ax
    push ax
    and al, 0x0F
    call print_hex_digit
    pop ax
    ret

print_hex_digit:
    cmp al, 9
    jg .letter
    add al, '0'
    jmp .p
.letter:
    add al, 'A' - 10
.p:
    call print_char
    ret

print_char:
    pusha
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, [text_attr]
    int 10h             ; BIOS TTY Output
    popa
    ret

print_string:
    pusha
    mov ah, 0x0E
    mov bx, 0007h
.l:
    lodsb
    test al, al
    jz .d
    int 10h
    jmp .l
.d:
    popa
    ret

print_string_red:
    mov byte [text_attr], 0x04
    call print_string
    mov byte [text_attr], 0x07
    ret

print_string_green:
    mov byte [text_attr], 0x02
    call print_string
    mov byte [text_attr], 0x07
    ret

print_string_cyan:
    mov byte [text_attr], 0x03
    call print_string
    mov byte [text_attr], 0x07
    ret

print_newline:
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    int 10h
    mov al, 0x0A
    int 10h
    popa
    ret

is_hex_digit:
    cmp al, '0'
    jb .n
    cmp al, '9'
    jbe .y
    cmp al, 'A'
    jb .n
    cmp al, 'F'
    jbe .y
    cmp al, 'a'
    jb .n
    cmp al, 'f'
    jbe .y
.n: clc
    ret
.y: stc
    ret

char_to_hex:
    cmp al, '9'
    jle .dig
    cmp al, 'F'
    jle .up
    sub al, 'a' - 10
    ret
.up: sub al, 'A' - 10
    ret
.dig: sub al, '0'
    ret

delay:
    pusha
    xor dx, dx          ; DX must be 0 for short delays in INT 15h
    mov ah, 0x86
    int 15h
    popa
    ret

string_copy:
    pusha
.c: lodsb
    stosb
    test al, al
    jnz .c
    popa
    ret

string_append:
    pusha
    xor al, al
    mov cx, -1
    repne scasb
    dec di
.a: lodsb
    stosb
    test al, al
    jnz .a
    popa
    ret

int_to_string:
    pusha
    mov di, num_buffer
    add di, 6
    mov byte [di], 0
    dec di
    mov cx, 10
.conv:
    xor dx, dx
    div cx
    add dl, '0'
    mov [di], dl
    dec di
    test ax, ax
    jnz .conv
    inc di
    mov si, di
    mov di, num_buffer
.mv: lodsb
    stosb
    test al, al
    jnz .mv
    popa
    mov ax, num_buffer
    ret

;----------------------------------------------------------
; DATA
;----------------------------------------------------------
filename_ptr dw 0
file_size dw 0
cursor_pos dw 0
view_offset dw 0
edit_mode db 0
byte_buffer db 0
nibble_flag db 0
modified_flag db 0
text_attr db 0x07

no_args_msg db 'Error: No filename provided!', 0
load_error_msg db 'Error: Could not load file!', 0
file_too_big_msg db 'Error: File exceeds 32KB!', 0
save_success_msg db 'File saved successfully!', 0
save_error_msg db 'Error: Save failed!', 0
modified_str db ' *', 0

help_msg db 'Arrows:Move Enter:Edit F1:Save F2:Reload Esc:Exit', 0
edit_help_msg db 'HEX:Input Enter:Finish Esc:Abort', 0
help_extended_msg db 'HexEdit 1.0 - Use Hex keys to modify data.', 0

header_str times 32 db 0
size_prefix db 'Size:', 0
pos_prefix db ' Pos:', 0
addr_header db 'Offset  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  ASCII', 0
num_buffer times 8 db 0

file_buffer:
