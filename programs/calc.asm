; ==================================================================
; x16-PRos -- CALC.BIN. Calculator.
; Copyright (C) 2025 litvincode, Saeta, PRoX2011
;
; Made by litvincode, Saeta and PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21
    
main_loop:
    mov ah, 0x01
    mov si, prompt
    int 0x21
    
    mov di, buffer
    call read_string
    
    cmp byte [exit_flag], 1
    je exit_program

    cmp byte [buffer], 0
    je main_loop
    
    mov si, buffer
    call parse_input
    
    cmp dword [error_flag], 0
    jne .error
    
    mov ah, 0x01
    mov si, result_msg
    int 0x21

    mov eax, [result]
    test eax, eax
    jns .positive
    neg eax
    push eax
    mov ah, 0x0E
    mov al, '-'
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    pop eax
.positive:
    call print_number
    mov ah, 0x05
    int 0x21
    jmp main_loop
    
.error:
    mov ah, 0x04
    mov si, error_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp main_loop

exit_program:
    mov ah, 0x02
    mov si, exit_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


read_string:
    xor cx, cx
    mov byte [exit_flag], 0
.read_char:
    mov ah, 0
    int 0x16
    
    cmp al, 0x1B
    je .exit_pressed

    cmp al, 0x08
    je .backspace
    
    cmp al, 0x0D
    je .done
    
    cmp al, '-'
    je .valid_char
    cmp al, '+'
    je .valid_char
    cmp al, '*'
    je .valid_char
    cmp al, '/'
    je .valid_char
    cmp al, '^'
    je .valid_char
    cmp al, ' '
    je .valid_char
    cmp al, '0'
    jb .read_char
    cmp al, '9'
    ja .read_char    
.valid_char:
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    
    stosb
    inc cx
    cmp cx, 64
    jae .done
    jmp .read_char
    
.backspace:
    test cx, cx
    jz .read_char
    dec di
    dec cx
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_char

.exit_pressed:
    mov byte [exit_flag], 1
    mov al, 0
    stosb
    ret
    
.done:
    mov al, 0
    stosb
    mov ah, 0x05
    int 0x21
    ret


parse_number:
    xor eax, eax
    mov [number], eax
    mov byte [negative_flag], 0
    
    lodsb
    cmp al, '-'
    jne .not_negative
    mov byte [negative_flag], 1
    lodsb
    jmp .start_parse
    
.not_negative:
    cmp al, '+'
    jne .start_parse
    lodsb
    
.start_parse:
    dec si
    
.read_digit:
    lodsb
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    
    sub al, '0'
    movzx ebx, al
    
    mov eax, [number]
    mov edx, 10
    mul edx
    jo .overflow
    add eax, ebx
    jc .overflow
    mov [number], eax
    
    jmp .read_digit
    
.done:
    dec si
    
    cmp byte [negative_flag], 0
    je .positive
    neg dword [number]
.positive:
    ret
    
.overflow:
    mov dword [error_flag], 1
    ret


fold_term:
    mov eax, [result]
    mov ebx, [operand1]
    mov cl, [add_op]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    ret
.add:
    add eax, ebx
    mov [result], eax
    ret
.sub:
    sub eax, ebx
    mov [result], eax
    ret


parse_input:
    mov dword [error_flag], 0
    
.skip_spaces_start:
    lodsb
    cmp al, ' '
    je .skip_spaces_start
    cmp al, 0
    je .error
    dec si
    
    call parse_number
    cmp dword [error_flag], 0
    jne .error
    mov eax, [number]
    mov [operand1], eax
    mov dword [result], 0
    mov byte [add_op], '+'

.expr_loop:
.skip_spaces_op:
    lodsb
    cmp al, ' '
    je .skip_spaces_op
    cmp al, 0
    je .done
    cmp al, '+'
    je .store_op
    cmp al, '-'
    je .store_op
    cmp al, '*'
    je .store_op
    cmp al, '/'
    je .store_op
    cmp al, '^'
    je .store_op
    jmp .error

.store_op:
    mov [operation], al

.skip_spaces_num:
    lodsb
    cmp al, ' '
    je .skip_spaces_num
    cmp al, 0
    je .error
    dec si
    
    call parse_number
    cmp dword [error_flag], 0
    jne .error
    mov eax, [number]
    mov [operand2], eax

    mov al, [operation]
    cmp al, '*'
    je .mul_div_pow
    cmp al, '/'
    je .mul_div_pow
    cmp al, '^'
    je .mul_div_pow

    call fold_term
    mov al, [operation]
    mov [add_op], al
    mov eax, [operand2]
    mov [operand1], eax
    jmp .expr_loop

.mul_div_pow:
    call perform_operation
    cmp dword [error_flag], 0
    jne .error
    mov eax, [operand1]
    mov [operand1], eax
    jmp .expr_loop

.done:
    call fold_term
    ret
    
.error:
    mov dword [error_flag], 1
    ret


perform_operation:
    mov eax, [operand1]
    mov ebx, [operand2]
    mov cl, [operation]
    
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .sub
    cmp cl, '*'
    je .mul
    cmp cl, '/'
    je .div
    cmp cl, '^'
    je .power
    
    mov dword [error_flag], 1
    ret
    
.add:
    add eax, ebx
    mov [operand1], eax
    ret
    
.sub:
    sub eax, ebx
    mov [operand1], eax
    ret
    
.mul:
    imul ebx
    mov [operand1], eax
    ret
    
.div:
    test ebx, ebx
    jz .div_error
    
    xor edx, edx
    cmp eax, 0x80000000
    jne .normal_div
    cmp ebx, -1
    jne .normal_div
    mov dword [operand1], 0x80000000
    ret
    
.normal_div:
    cdq
    idiv ebx
    mov [operand1], eax
    ret
    
.power:
    mov ecx, ebx
    cmp ecx, 0
    jl .power_error
    mov eax, 1
    mov ebx, [operand1]
    
    test ebx, ebx
    jnz .power_loop
    test ecx, ecx
    jnz .power_loop
    mov dword [operand1], 1
    ret
    
.power_loop:
    jecxz .power_done
    imul ebx
    jo .power_error
    dec ecx
    jmp .power_loop
    
.power_done:
    mov [operand1], eax
    ret
    
.power_error:
.div_error:
    mov dword [error_flag], 1
    ret


print_number:
    pusha
    test eax, eax
    jnz .not_zero
    
    mov ah, 0x0E
    mov al, '0'
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    jmp .done
    
.not_zero:
    mov edi, number_buffer + 10
    mov byte [edi], 0
    dec edi
    mov ebx, 10
    
.convert_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec edi
    test eax, eax
    jnz .convert_loop
    
    inc edi
    
    mov si, di
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
.print_loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_loop
    
.done:
    popa
    ret


welcome_msg db 0xDA, 12 dup(0xC4), ' PRos Calculator (by @litvincode, Saeta and PRoX-dev) ', 12 dup(0xC4), 0xBF
            db 0xC0, 78 dup(0xC4), 0xD9, 10, 13
            db 'Supports: + - * / ^', 0x0D, 0x0A
            db 'Press [ESC] to exit', 0x0D, 0x0A, 0x0D, 0x0A, 0
prompt      db '> ', 0
result_msg  db '= ', 0
error_msg   db 'Error', 0
exit_msg    db 'Exiting calculator...', 0

error_flag    dd 0
number        dd 0
operand1      dd 0
operand2      dd 0
operation     db 0
result        dd 0
negative_flag db 0
exit_flag     db 0
add_op        db 0

number_buffer times 11 db 0
buffer        times 65 db 0