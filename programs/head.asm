; ==================================================================
; x16-PRos -- HEAD. head utility for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Usage: head <filename>
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
    mov dx, 0x3000
    int 0x22
    jc .load_error

    cmp dx, 0
    jne .big_file_detected
    cmp ax, 0
    je .empty_file
    jmp .set_size

.big_file_detected:
    mov ax, 0xFFFF 

.set_size:
    mov word [.file_size], ax
    
    mov ax, 0x3000
    mov es, ax
    mov word [.file_ptr], 0
    mov word [.lines_printed], 0

.print_loop:
    cmp word [.lines_printed], 10
    jge .done
    cmp word [.file_size], 0
    je .done

    mov si, [.file_ptr]
    mov al, [es:si]

    cmp al, 10
    je .print_newline
    cmp al, 13
    je .skip_char
    
    cmp al, 32
    jb .check_tab
    cmp al, 126
    ja .skip_char
    jmp .do_print

.check_tab:
    cmp al, 9
    je .do_print
    jmp .skip_char

.do_print:
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .next_char

.print_newline:
    inc word [.lines_printed]
    mov ah, 0x05
    int 0x21
    jmp .next_char

.skip_char:
    jmp .next_char

.next_char:
    inc word [.file_ptr]
    dec word [.file_size]
    
    cmp word [.file_ptr], 0
    je .done
    jmp .print_loop

.done:
    mov ah, 0x05
    int 0x21
    popa
    ret

.show_help:
    mov ah, 0x01
    mov si, .help_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.file_not_found:
    mov ah, 0x04
    mov si, notfound_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.load_error:
    mov ah, 0x04
    mov si, .load_error_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.empty_file:
    mov ah, 0x04
    mov si, .empty_file_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.filename        dw 0
.file_ptr        dw 0
.file_size       dw 0
.lines_printed   dw 0

.help_msg          db 'Usage: head <filename>', 10, 13, 0
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0

param_list         dw 0
notfound_msg       db 'File not found', 0

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