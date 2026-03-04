; ==================================================================
; x16-PRos -- GREP. grep utility for x16-PRos
; Copyright (C) 2025 PRoX2011
; 
; Usage: grep <filename> <search_string>
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

file_buffer equ 0xE000

start:
    mov [param_list], si

    mov ah, 0x05
    int 0x21

    pusha

    ; === Parse parameters ===
    mov si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .not_enough_params
    cmp bx, 0
    je .not_enough_params

    mov [filename_ptr], ax
    mov [search_str_ptr], bx

    ; === Check file exists ===
    mov ah, 0x04
    mov si, [filename_ptr]
    int 0x22
    jc .file_not_found

    ; === Load file into file_buffer ===
    mov ah, 0x02
    mov si, [filename_ptr]
    mov cx, file_buffer
    int 0x22
    jc .load_error

    cmp bx, 0
    je .empty_file

    mov [file_total], bx
    mov [file_size],  bx
    mov word [file_ptr], file_buffer
    mov word [line_num], 1
    mov word [col_num],  1
    mov word [match_count], 0

    ; === Get search string length ===
    mov ax, [search_str_ptr]
    call string_string_length
    mov [search_len], ax
    cmp ax, 0
    je .invalid_search

    ; === Convert search string to uppercase ===
    mov ax, [search_str_ptr]
    call string_string_uppercase

.search_loop:
    ; Enough bytes left for a possible match?
    mov ax, [file_size]
    cmp ax, [search_len]
    jb .search_complete

    ; === Compare at current position ===
    mov si, [file_ptr]
    mov di, [search_str_ptr]
    mov cx, [search_len]
    call compare_chars
    jc .match_found

    ; === No match — advance 1 char, update counters ===
    mov si, [file_ptr]
    mov al, [si]
    call process_char
    inc word [file_ptr]
    dec word [file_size]
    jmp .search_loop

.match_found:
    inc word [match_count]

    push word [line_num]
    push word [col_num]

    call find_line_start
    call find_line_end

    pop  word [match_col]
    pop  word [match_line]

    call print_line_with_match

    mov cx, [search_len]
    mov si, [file_ptr]
.skip_match:
    mov al, [si]
    call process_char
    inc si
    loop .skip_match

    mov [file_ptr], si
    mov ax, [search_len]
    sub [file_size], ax
    jmp .search_loop

.search_complete:
    cmp word [match_count], 0
    jne .done

    mov ah, 0x04
    mov si, no_matches_msg
    int 0x21

    mov ah, 0x05
    int 0x21
    jmp .done

.not_enough_params:
    mov ah, 0x04
    mov si, usage_msg
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
    mov si, load_error_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.empty_file:
    mov ah, 0x04
    mov si, empty_file_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.invalid_search:
    mov ah, 0x04
    mov si, invalid_search_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.done:
    popa
    ret

compare_chars:
    push cx
    push si
    push di
.compare_loop:
    mov al, [si]
    call to_upper
    mov bl, [di]
    cmp al, bl
    jne .no_match
    inc si
    inc di
    loop .compare_loop
    stc
    jmp .cc_done
.no_match:
    clc
.cc_done:
    pop di
    pop si
    pop cx
    ret

to_upper:
    cmp al, 'a'
    jb .tu_done
    cmp al, 'z'
    ja .tu_done
    sub al, 20h
.tu_done:
    ret

process_char:
    cmp al, 10
    je .newline
    cmp al, 13
    je .cr
    inc word [col_num]
    ret
.newline:
    inc word [line_num]
    mov word [col_num], 1
    ret
.cr:
    mov word [col_num], 1
    ret

find_line_start:
    pusha
    mov si, [file_ptr]

    cmp si, file_buffer
    je .at_start

    mov ax, si
    sub ax, file_buffer
    mov cx, ax
.back_loop:
    dec si
    mov al, [si]
    cmp al, 10
    je .found_lf
    loop .back_loop
    jmp .at_start
.found_lf:
    inc si
.at_start:
    mov [line_start], si
    popa
    ret

find_line_end:
    pusha
    mov si, [line_start]

    mov ax, file_buffer
    add ax, [file_total]
    sub ax, si
    mov cx, ax
    jcxz .store

.scan_loop:
    mov al, [si]
    cmp al, 10
    je .store
    cmp al, 13
    je .store
    inc si
    dec cx
    jnz .scan_loop

.store:
    mov [line_end], si
    popa
    ret

print_line_with_match:
    pusha

    ; --- "Line: N Column: M" header ---
    mov ah, 0x0E
    mov bl, 0x0E

    mov si, line_label
.lbl_line:
    lodsb
    cmp al, 0
    je .lbl_line_done
    int 0x10
    jmp .lbl_line
.lbl_line_done:

    mov ax, [match_line]
    call print_decimal

    mov ah, 0x0E
    mov al, ' '
    mov bl, 0x07
    int 0x10

    mov si, col_label
    mov bl, 0x0E
.lbl_col:
    lodsb
    cmp al, 0
    je .lbl_col_done
    int 0x10
    jmp .lbl_col
.lbl_col_done:

    mov ax, [match_col]
    call print_decimal

    mov ah, 0x05
    int 0x21

    mov si, [line_start]
    mov di, [line_end]

.ploop:
    cmp si, di
    jae .pdone

    mov ax, [file_ptr]
    cmp si, ax
    jb .grey
    add ax, [search_len]
    cmp si, ax
    jae .grey

    mov bl, 0x0C
    jmp .emit
.grey:
    mov bl, 0x07
.emit:
    mov ah, 0x0E
    mov al, [si]
    int 0x10
    inc si
    jmp .ploop

.pdone:
    mov ah, 0x05
    int 0x21

    popa
    ret

print_decimal:
    pusha
    mov cx, 0
    cmp ax, 0
    jne .divloop
    mov ah, 0x0E
    mov al, '0'
    mov bl, 0x07
    int 0x10
    jmp .pddone
.divloop:
    cmp ax, 0
    je .printdigits
    mov bx, 10
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .divloop
.printdigits:
    mov ah, 0x0E
    mov bl, 0x07
.digitloop:
    pop dx
    mov al, dl
    add al, '0'
    int 0x10
    dec cx
    jnz .digitloop
.pddone:
    popa
    ret

string_string_parse:
    push si
    mov ax, si
    xor bx, bx
    xor cx, cx
    xor dx, dx
    push ax
.lp1:
    lodsb
    cmp al, 0
    je .fin
    cmp al, ' '
    jne .lp1
    dec si
    mov byte [si], 0
    inc si
    mov bx, si
.lp2:
    lodsb
    cmp al, 0
    je .fin
    cmp al, ' '
    jne .lp2
    dec si
    mov byte [si], 0
    inc si
    mov cx, si
.lp3:
    lodsb
    cmp al, 0
    je .fin
    cmp al, ' '
    jne .lp3
    dec si
    mov byte [si], 0
    inc si
    mov dx, si
.fin:
    pop ax
    pop si
    ret

string_string_length:
    push di
    mov di, ax
    xor cx, cx
.ssl_loop:
    cmp byte [di], 0
    je .ssl_done
    inc di
    inc cx
    jmp .ssl_loop
.ssl_done:
    mov ax, cx
    pop di
    ret

string_string_uppercase:
    push di
    mov di, ax
.ssu_loop:
    cmp byte [di], 0
    je .ssu_done
    cmp byte [di], 'a'
    jb .ssu_next
    cmp byte [di], 'z'
    ja .ssu_next
    sub byte [di], 20h
.ssu_next:
    inc di
    jmp .ssu_loop
.ssu_done:
    pop di
    ret

section .data

usage_msg          db 'Usage: grep <filename> <search_string>', 0
load_error_msg     db 'Error loading file', 0
empty_file_msg     db 'File is empty', 0
invalid_search_msg db 'Invalid search string', 0
no_matches_msg     db 'No matches found', 0
notfound_msg       db 'File not found', 0
line_label         db 'Line: ', 0
col_label          db 'Column: ', 0

param_list         dw 0

filename_ptr       dw 0
search_str_ptr     dw 0
search_len         dw 0
file_total         dw 0
file_size          dw 0
file_ptr           dw 0
line_num           dw 0
col_num            dw 0
match_count        dw 0
line_start         dw 0
line_end           dw 0
match_line         dw 0
match_col          dw 0