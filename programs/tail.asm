; ==================================================================
; x16-PRos -- TAIL. tail utility for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Usage: tail <filename>
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov [param_list], si

    mov ah, 0x05
    int 0x21

    pusha

    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_help

    mov [.filename], ax

    mov si, [.filename]
    mov ah, 0x04
    int 0x22
    jc .file_not_found

    mov ah, 0x10
    mov si, [.filename]
    mov cx, 0x0000
    mov dx, 0x4000
    int 0x22
    jc .load_error

    cmp dx, 0
    jne .limit_size
    cmp ax, 0
    je .empty_file
    jmp .save_size

.limit_size:
    mov ax, 0xFFFF

.save_size:
    mov [.file_size], ax
    
    mov ax, 0x4000
    mov es, ax
    
    mov si, [.file_size]
    dec si
    
    mov word [.lines_found], 0
    mov word [.lines_to_show], 10

.find_lines:
    cmp si, 0xFFFF
    je .found_all_lines_start

    mov ax, [.lines_found]
    cmp ax, [.lines_to_show]
    jge .found_limit

    mov al, [es:si]
    cmp al, 10
    jne .continue_search

    inc word [.lines_found]

.continue_search:
    dec si
    jmp .find_lines

.found_all_lines_start:
    mov word [.print_start], 0
    jmp .start_printing

.found_limit:
    inc si
    inc si
    mov [.print_start], si

.start_printing:
    mov si, [.print_start]

.print_loop:
    cmp si, [.file_size]
    jae .done

    mov al, [es:si]

    cmp al, 10
    je .print_newline
    cmp al, 13
    je .skip_char
    cmp al, 32
    jb .skip_char
    cmp al, 126
    ja .skip_char
    
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .next_char

.print_newline:
    mov ah, 0x05
    int 0x21
    jmp .next_char

.skip_char:
    jmp .next_char

.next_char:
    inc si
    jmp .print_loop

.done:
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21
    popa
    ret

.show_help:
    mov si, .help_msg
    mov ah, 0x01
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.file_not_found:
    mov si, notfound_msg
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.load_error:
    mov si, .load_error_msg
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.empty_file:
    mov si, .empty_file_msg
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.filename        dw 0
.file_size       dw 0
.print_start     dw 0
.lines_to_show   dw 10
.lines_found     dw 0

.help_msg          db 'Usage: tail <filename>', 0
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0
notfound_msg       db 'File not found', 0
param_list         dw 0

string_string_parse:
    push si
    mov ax, si
    xor bx, bx
    xor cx, cx
    xor dx, dx
    push ax
.loop1:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop1
    dec si
    mov byte [si], 0
    inc si
    mov bx, si
.loop2:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop2
    dec si
    mov byte [si], 0
    inc si
    mov cx, si
.finish:
    pop ax
    pop si
    ret