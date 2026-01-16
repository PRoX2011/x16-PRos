%ifndef EDCOMMS
%define EDCOMMS

; in:          si - ptr to start of operand
; out:         cx - line_num
; side effect: ax
;              si point to 0 or ' '
command_parse_line_operand:
    xor cx, cx
    
command_parse_line_operand_get_char:
    mov ax, [si]
    cmp al, ' '
    je command_parse_line_operand_end
    cmp al, 0
    je command_parse_line_operand_end
    cmp al, '.'
    je command_parse_line_operand_cur_line
    cmp al, '$'
    je command_parse_line_operand_last_line

    cmp al, '0'
    jb command_parse_line_invalid_operand
    cmp al, '9'
    ja command_parse_line_invalid_operand
    sub al, '0'
    imul cx, 10
    xor ah, ah
    add cx, ax

command_parse_line_operand_next_char:
    inc si
    jmp command_parse_line_operand_get_char

command_parse_line_operand_cur_line:
    add cx, [cur_line]
    jmp command_parse_line_operand_next_char

command_parse_line_operand_last_line:
    neg cx
    add cx, [lines_num]
    sub cx, 1
    jmp command_parse_line_operand_next_char

command_parse_line_operand_end:
    ret

command_parse_line_invalid_operand:
    mov si, err_text_invalid_operand
    mov ah, 0x01
    int 0x21
    ret


; in:          si - ptr to start of operands (or spaces after operands)
;              di - buffer to write operands (word)
;              cx - num of operands to get
; out:         save to buffer LN operands
;              bx - num of finded operands
; side effect: ax, dx
command_get_line_operands:
    xor bx, bx
command_get_line_operands_skip_spaces:
    mov ax, [si]
    cmp al, 0
    je command_get_line_operands_end
    cmp al, ' '
    jne command_get_line_operands_skip_spaces_end
    inc si
    jmp command_get_line_operands_skip_spaces

command_get_line_operands_skip_spaces_end:
    push cx  ; saving num of operands to get
    call command_parse_line_operand
    pop dx  ; get saved num of oprands to dx
    mov [di], cx  ; save operand value to buffer
    mov cx, dx  ; moving saved num of operands back to cx
    add di, 2
    inc bx
    cmp bx, cx
    je command_get_line_operands_end
    jmp command_get_line_operands_skip_spaces

command_get_line_operands_end:
    ret

command_W:
    mov si, file_text_buffer
    call strlen
    mov bx, file_text_buffer
    mov si, cur_file_name
    mov ah, 0x03
    int 0x22

    or byte [flags], 1 ; set bit of saving buffer
    jmp command_loop


command_q:
    test byte [flags], 1
    jnz exit_prog
    mov si, comm_text_buf_not_saved
    mov ah, 0x01
    int 0x21
    jmp command_loop


command_P:
    ; cx - StLN
    ; dx - EdLN

    mov di, command_operand_buffer
    mov cx, 2
    call command_get_line_operands

    cmp bx, 1
    jb .command_P_non_operands
    je .command_P_non_operands2

    mov cx, [command_operand_buffer]
    mov dx, [command_operand_buffer + 2]

    jmp .command_P_operans_valid_chack

.command_P_non_operands:
    mov cx, [cur_line]
.command_P_non_operands2:
    mov dx, cx

.command_P_operans_valid_chack:
    cmp cx, 1
    jb .command_P_err_invalid_operand
    cmp cx, [lines_num]
    jae .command_P_err_invalid_operand
    
    cmp dx, 1
    jb .command_P_err_invalid_operand
    cmp dx, [lines_num]
    jae .command_P_err_invalid_operand

    cmp dx, cx
    jb .command_P_err_invalid_operand

.command_P_ptr_con:
    push cx

    mov bx, cx
    sub bx, 1
    jz .command_P_ptr_set
    shl bx, 1
.command_P_ptr_set:
    lea di, [text_lines_buffer + bx]

.command_P_print_line:
    pusha
        mov ax, cx
        mov di, number_convert_buffer
        call convert_to_string
        mov si, number_convert_buffer
        mov ah, 0x01
        int 0x21
        
        mov ah, 0x0E
        mov bx, 0x0F
        mov al, '.'
        int 0x10
        mov al, ' '
        int 0x10
    popa

    mov si, [di]
    mov bx, 0x0F
.command_P_print_char:
    mov ax, [si]
    mov ah, 0x0E
    int 0x10
    
    cmp al, 0x0A  ; al == '\n'
    je .command_P_to_next_line
    cmp al, 0x0D  ; al == '\r'
    je .command_P_to_next_line
    cmp al, 0
    je .command_P_end

    inc si
    jmp .command_P_print_char

.command_P_to_next_line:
    mov ax, [si + 1]
    mov ah, 0x0E
    int 0x10
    
    add di, 2
    inc cx

    cmp cx, dx
    ja .command_P_end

    jmp .command_P_print_line

.command_P_end:
    mov ah, 0x0E
    mov al, 10
    int 0x10
    mov al, 13
    int 0x10

    pop cx
    mov [cur_line], cx
    jmp command_loop

.command_P_err_invalid_operand:
    mov si, err_text_invalid_operand
    mov ah, 0x01
    int 0x21
    jmp command_loop


command_D:


    jmp command_loop

%include "programs/ed-common.inc"

%endif