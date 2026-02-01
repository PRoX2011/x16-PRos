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

start:
    mov [param_list], si

    push cs
    pop ds
    push cs
    pop es

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

    mov [file_size], bx
    mov word [file_ptr], file_buffer
    mov word [line_num], 1
    mov word [col_num], 1
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
    mov ax, [file_size]
    cmp ax, [search_len]
    jb .search_complete

    ; === Compare at current position ===
    mov si, [file_ptr]
    mov di, [search_str_ptr]
    mov cx, [search_len]
    call compare_chars
    jc .match_found

    ; === No match — advance 1 char ===
    mov si, [file_ptr]
    mov al, [si]
    call process_char
    inc word [file_ptr]
    dec word [file_size]
    jmp .search_loop

.match_found:
    inc word [match_count]

    call find_line_start
    call find_line_end

    call print_line_with_match

    mov ax, [search_len]
    add [file_ptr], ax
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

; ------------------------------------------------------------------
; compare_chars
; IN: SI = file_ptr, DI = search_str_ptr, CX = len
; OUT: CF = 1 if match, 0 otherwise
; Clobbers: AX, BX, CX, SI, DI
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
    jmp .done
.no_match:
    clc
.done:
    pop di
    pop si
    pop cx
    ret

to_upper:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 20h
.done:
    ret

; ------------------------------------------------------------------
; process_char — update line/col counters
; IN: AL = char
process_char:
    cmp al, 10          ; LF
    je .newline
    cmp al, 13          ; CR
    je .carriage_return
    inc word [col_num]
    ret
.newline:
    inc word [line_num]
    mov word [col_num], 1
    ret
.carriage_return:
    mov word [col_num], 1
    ret

; ------------------------------------------------------------------
; find_line_start → [line_start]
find_line_start:
    pusha
    mov si, [file_ptr]
    mov ax, si
    sub ax, file_buffer    ; distance from buffer start
    jbe .at_start
    mov cx, ax
.find_start_loop:
    dec si
    mov al, [si]
    cmp al, 10            ; LF
    je .found
    loop .find_start_loop
    jmp .at_start
.found:
    inc si                ; first char after newline
.at_start:
    mov [line_start], si
    popa
    ret

; ------------------------------------------------------------------
; find_line_end → [line_end]
find_line_end:
    pusha
    mov si, [file_ptr]
    mov cx, [file_size]
.find_end_loop:
    mov al, [si]
    cmp al, 10
    je .found
    cmp al, 13
    je .found
    inc si
    loop .find_end_loop
.found:
    mov [line_end], si
    popa
    ret

; ------------------------------------------------------------------
; print_line_with_match
print_line_with_match:
    pusha

    ; Line: N Column: M
    mov ah, 0x0E
    mov si, line_label
    mov bl, 0x0E
.print_line_lbl:
    lodsb
    cmp al, 0
    je .line_done
    int 0x10
    jmp .print_line_lbl
.line_done:

    mov ax, [line_num]
    call print_decimal
    mov al, ' '
    int 0x10

    mov si, col_label
    mov bl, 0x0E
.print_col_lbl:
    lodsb
    cmp al, 0
    je .col_done
    int 0x10
    jmp .print_col_lbl
.col_done:

    mov ax, [col_num]
    call print_decimal

    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    ; Print line (highlight match in red)
    mov si, [line_start]
    mov di, [line_end]
.print_loop:
    cmp si, di
    jae .print_done

    ; Check if inside match range
    mov ax, [file_ptr]
    cmp si, ax
    jb .normal
    add ax, [search_len]
    cmp si, ax
    jae .normal

    ; Highlighted (red)
    mov bl, 0x0C
    jmp .emit
.normal:
    mov bl, 0x07
.emit:
    mov ah, 0x0E
    mov al, [si]
    int 0x10
    inc si
    jmp .print_loop

.print_done:
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21
    popa
    ret

; -----------------------------
; print_decimal: AX = number
print_decimal:
    pusha
    mov cx, 0
.setup:
    cmp ax, 0
    je .check_zero
    mov bx, 10
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .setup
.check_zero:
    cmp cx, 0
    jne .print_digits
    push dx
    inc cx
.print_digits:
    mov ah, 0x0E
.print_loop:
    pop dx
    add dx, '0'
    mov al, dl
    mov bl, 0x07
    int 0x10
    dec cx
    jnz .print_loop
    popa
    ret

; ===============================================================
; string_string_parse — same as in kernel
; IN: SI = ptr to space-separated params
; OUT: AX = 1st token, BX = 2nd token, CX = 3rd, DX = 4th
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
.loop3:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop3
    dec si
    mov byte [si], 0
    inc si
    mov dx, si
.finish:
    pop ax
    pop si
    ret

; ===============================================================
; string_string_length — AX = ptr → AX = len
string_string_length:
    push di
    mov di, ax
    xor cx, cx
.more:
    cmp byte [di], 0
    je .done
    inc di
    inc cx
    jmp .more
.done:
    mov ax, cx
    pop di
    ret

; ===============================================================
; string_string_uppercase — in-place, AX = ptr
string_string_uppercase:
    push di
    mov di, ax
.more:
    cmp byte [di], 0
    je .done
    cmp byte [di], 'a'
    jb .next
    cmp byte [di], 'z'
    ja .next
    sub byte [di], 20h
.next:
    inc di
    jmp .more
.done:
    pop di
    ret

usage_msg          db 'Usage: grep <filename> <search_string>', 0
load_error_msg     db 'Error loading file', 0
empty_file_msg     db 'File is empty', 0
invalid_search_msg db 'Invalid search string', 0
no_matches_msg     db 'No matches found', 0
notfound_msg       db 'File not found', 0
line_label         db 'Line:', 0
col_label          db 'Column:', 0

param_list         dw 0

filename_ptr       dw 0
search_str_ptr     dw 0
search_len         dw 0
file_size          dw 0
file_ptr           dw 0
line_num           dw 0
col_num            dw 0
match_count        dw 0
line_start         dw 0
line_end           dw 0

file_buffer: resb 32768