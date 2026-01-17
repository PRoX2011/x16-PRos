%ifndef EDCOMMON
%define EDCOMMON

; === error messages ===
    err_text_file_name_lenght   db "ERROR: to large file name", 10, 13, 0
    err_text_file_not_be_opened db "ERROR: input file_not be opened (file not exist or disk error)", 10, 13, 0
    err_text_unknown_command    db "ERROR: Unknown command", 10, 13, 0
    err_text_invalid_operand    db "ERROR: Invalid operand", 10, 13, 0
; ======================

; === info messages ===
    
    text_file_readed1       db "readed ", 0
    text_file_readed2       db " bytes", 10, 13, 0
    text_help_command       db "?", 0
    text_help_message       db "ED", 10, 13
                            db "Dev: Desvor", 10, 13
                            db "Ver: 0.0.2", 10, 13
                            db "See manual A:/docs/edman.txt", 10, 13, 0
    comm_text_buf_not_saved db "Text buffer not saved. save file with `w` command "
                            db "or use `Q` command for exiting witout chacking", 10, 13, 0
; =====================

; === sub info ===
    ; control flags
    ; 0 - file_text_buffer is saved
    flags db 0b00000001
    ; num of buffer lines
    lines_num dw 1
    ; number of current line
    cur_line dw 1
; ================

; === buffers ===
    ; buf resb TEXT_BUF_SIZE  ; buffer for some calculations
    command_buffer        resb COMMAND_BUF_SIZE  ; buffer for command
    cur_file_name         resb FILE_NAME_MAX_LENGTH + 1  ; name of current file
    file_text_buffer      resb FILE_TEXT_BUF_SIZE  ; redacted buffer
    text_lines_buffer     resb FILE_LINES_BUF_SIZE * 2  ; array of pointer to lines at file_text_buffer
    number_convert_buffer resb 6
    command_operand_buffer resb 8
; ===============

; === constants ===
FILE_NAME_MAX_LENGTH equ 12
TEXT_BUF_SIZE        equ 4096
FILE_TEXT_BUF_SIZE   equ TEXT_BUF_SIZE
FILE_LINES_BUF_SIZE  equ TEXT_BUF_SIZE / 4
COMMAND_BUF_SIZE     equ 24  ; calced for 'A L01 L02 filename.ext \0'
; =================


; in:          si - string
; out:         cx - size
; side effect: no
strlen:
    xor cx, cx
.strlen_count_loop:
    cmp byte [si], 0
    je .strlen_end
    inc cx
    inc si
    jmp .strlen_count_loop
.strlen_end:
    ret

; in:          si - str1
;              di - str2
; out:         ax = 0 - eq, ax = 1 - not eq
; side effect: no
strcmp:
.strcmp_count_loop:
    cmp byte [si], 0
    je .strcmp_end
    mov al, [si]
    cmp [di], al
    jne .strcmp_neq
    inc si
    inc di
    jmp .strcmp_count_loop
.strcmp_end:
    cmp byte [di], 0
    je .strcmp_eq
.strcmp_neq:
    mov ax, 0xFFFF
    ret
.strcmp_eq:
    mov ax, 0
    ret


; in:          no
; out:         file_text_lines and lines_num updating
; side effect: si, di, ax
split_text_by_lines:
    mov word [lines_num], 1
    mov si, file_text_buffer
    mov di, text_lines_buffer

    mov [di], si
    add di, 2

.splitting_loop:
    mov ax, [si]
    cmp al, 0x0A  ; if al = '\r'
    je .next_line
    cmp al, 0
    je .end
    inc si
    jmp .splitting_loop

.next_line:
    inc si
    mov [di], si
    add di, 2
    inc word [lines_num]
    jmp .splitting_loop

.end:
    inc word [lines_num]
    mov word [di + 2], 0

%endif