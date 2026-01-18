%ifndef EDCOMMS
%define EDCOMMS

; in:          si - ptr to start of operand
; out:         cx - line_num
; side effect: ax
;              si point to 0 or ' '
command_parse_line_operand:
    xor cx, cx
    
.get_char:
    mov ax, [si]
    cmp al, ' '
    je .end
    cmp al, 0
    je .end
    cmp al, '.'
    je .handle_cur_line
    cmp al, '$'
    je .handle_last_line

    cmp al, '0'
    jb .invalid_operand
    cmp al, '9'
    ja .invalid_operand
    sub al, '0'
    imul cx, 10
    xor ah, ah
    add cx, ax

.next_char:
    inc si
    jmp .get_char

.handle_cur_line:
    add cx, [cur_line]
    jmp .next_char

.handle_last_line:
    neg cx
    add cx, [lines_num]
    jmp .next_char

.end:
    ret

.invalid_operand:
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
.skip_spaces:
    mov ax, [si]
    cmp al, 0
    je .end
    cmp al, ' '
    jne .skip_spaces_end
    inc si
    jmp .skip_spaces

.skip_spaces_end:
    push cx  ; saving num of operands to get
    call command_parse_line_operand
    pop dx  ; get saved num of oprands to dx
    mov [di], cx  ; save operand value to buffer
    mov cx, dx  ; moving saved num of operands back to cx
    add di, 2
    inc bx
    cmp bx, cx
    je .end
    jmp .skip_spaces

.end:
    ret

command_w:
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


command_p:
    ; cx - StLN
    ; dx - EdLN

    mov di, command_operand_buffer
    mov cx, 2
    call command_get_line_operands

    mov cx, [command_operand_buffer]
    mov dx, [command_operand_buffer + 2]

    cmp bx, 1
    jb .non_operands
    je .non_operands2

    jmp .operands_valid_chack

.non_operands:
    mov cx, [cur_line]
.non_operands2:
    mov dx, cx

.operands_valid_chack:
    mov [cur_line], cx

    cmp cx, 1
    jb command_err_invalid_operand
    cmp cx, [lines_num]
    ja command_err_invalid_operand
    
    cmp dx, 1
    jb command_err_invalid_operand
    cmp dx, [lines_num]
    ja command_err_invalid_operand

    cmp dx, cx
    jb command_err_invalid_operand
    push cx

    mov bx, cx
    sub bx, 1
    jz .ptr_set
    shl bx, 1
.ptr_set:
    lea di, [text_lines_buffer + bx]

.print_line:
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
.print_char:
    mov ax, [si]
    mov ah, 0x0E
    int 0x10
    
    cmp al, 0x0A  ; al == '\n'
    je .to_next_line
    cmp al, 0x0D  ; al == '\r'
    je .to_next_line
    cmp al, 0
    je .end

    inc si
    jmp .print_char

.to_next_line:
    mov ax, [si + 1]
    mov ah, 0x0E
    int 0x10
    
    add di, 2
    inc cx

    cmp cx, dx
    ja .end

    jmp .print_line

.end:
    mov ah, 0x0E
    mov al, 10
    int 0x10
    mov al, 13
    int 0x10

    pop cx
    jmp command_loop

command_d:
    ; cx - StLN
    ; dx - EdLN

    push si
    call save_buffer_for_undo
    pop si

    mov di, command_operand_buffer
    mov cx, 2
    call command_get_line_operands

    mov cx, [command_operand_buffer]
    mov dx, [command_operand_buffer + 2]

    cmp bx, 1
    jb .non_operands
    je .non_operands2

    jmp .operands_valid_chack

.non_operands:
    mov cx, [cur_line]
.non_operands2:
    mov dx, cx

.operands_valid_chack:
    mov [cur_line], cx

    cmp cx, 1
    jb command_err_invalid_operand
    cmp cx, [lines_num]
    ja command_err_invalid_operand
    
    cmp dx, 1
    jb command_err_invalid_operand
    cmp dx, [lines_num]
    ja command_err_invalid_operand

    cmp dx, cx
    jb command_err_invalid_operand

.delete_line:
    mov bx, dx
    cmp dx, [lines_num]
    je .last_line_get_ptr
    shl bx, 1
    mov di, [text_lines_buffer + bx]  ; di - point to start of next line after EdLN
    jmp .get_start_line_ptr_prelude

.last_line_get_ptr:
    mov bx, [lines_num]
    dec bx
    shl bx, 1
    mov di, [text_lines_buffer + bx]
.last_line_get_ptr_shift_char:
    cmp byte [di], 0
    je .get_start_line_ptr_prelude
    inc di
    jmp .last_line_get_ptr_shift_char

.get_start_line_ptr_prelude:
    push word 0  ; flag of deletting first line
    mov bx, cx
    dec bx
    cmp bx, 0
    je .get_start_line_ptr
    shl bx, 1

.get_start_line_ptr:
    mov si, [text_lines_buffer + bx]  ; si - point to start of StLN
    jmp .move_char

.set_firt_line_flag:
    mov bp, sp
    mov word [bp], 1  ; set flag of delleting last line
    jmp .get_start_line_ptr

.move_char:
    mov al, [di]
    mov [si], al

    cmp al, 0
    je .move_end

    inc si
    inc di
    jmp .move_char
.move_end:
    call split_text_by_lines
    and byte [flags], 0b11111110  ; disable bit of file saved
    pop bx
    cmp bx, 0
    jnz .end
    dec word [lines_num]
.end:
    jmp command_loop


command_u:
    mov si, file_text_buffer
    mov di, undo_buffer

.restore_char:
    mov al, [di]
    mov [si], al
    cmp al, 0
    je .end
    inc si
    inc di
    jmp .restore_char

.end:
    call split_text_by_lines
    jmp command_loop


command_a:
    push si
    call save_buffer_for_undo
    pop si


command_err_invalid_operand:
    mov si, err_text_invalid_operand
    mov ah, 0x01
    int 0x21
    jmp command_loop

%include "programs/ed-common.inc"

%endif