; ==================================
; "Hello, world!" program example:
; ++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
; ==================================

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

    mov dl, 0
    mov dh, 0
    call set_cursor_pos

    mov bp, helper
    mov cx, 82
    call print_message

    mov dl, 0
    mov dh, 24
    call set_cursor_pos

    mov bp, msg
    mov cx, 80
    call print_message

    mov dl, 0
    mov dh, 17
    call set_cursor_pos

    mov si, hr
    call print_string

    ; Переход к вводу
    jmp getInput

getInput:
    ; Настройка для ввода
    mov bx, 000Fh
    mov cx, 1
    xor dx, dx
    cld
    mov di, sectorEnd
    mov ah, 02h
    mov dh, 2
    int 10h

.read_char:
    mov ah, 00h
    int 16h

    cmp al, 1Bh
    jz esc_exit

    cmp al, 08h
    je .handle_backspace

    stosb

    cmp al, 0Dh
    je allocateWorkspace

    mov ah, 09h
    int 10h

    call incrementCursor
    jmp .read_char

.handle_backspace:
    dec di
    call decrementCursor
    mov al, ' '
    mov ah, 09h
    int 10h
    jmp .read_char

allocateWorkspace:
    mov word [programCounter], sectorEnd
    mov [dataPointer], di
    mov cx, 30000
    mov al, 0
.loop:
    stosb
    dec cx
    jnz .loop

runCode:
    mov bx, 000Fh
    mov cx, 1
    mov dl, 0
    mov ah, 02h
    mov dh, 20
    int 10h
    dec word [programCounter]

.next_instruction:
    inc word [programCounter]
    movzx eax, word [programCounter]
    cmp byte [eax], '>'
    je .inc_data_ptr
    cmp byte [eax], '<'
    je .dec_data_ptr
    cmp byte [eax], '+'
    je .inc_cell
    cmp byte [eax], '-'
    je .dec_cell
    cmp byte [eax], '.'
    je .out_cell
    cmp byte [eax], ','
    je .in_cell
    cmp byte [eax], '['
    je .jump_forward
    cmp byte [eax], ']'
    je .jump_backward

.error:
    mov ah, 00h
    int 16h
    jmp getInput

.inc_data_ptr:
    inc word [dataPointer]
    jmp .next_instruction

.dec_data_ptr:
    dec word [dataPointer]
    jmp .next_instruction

.inc_cell:
    movzx eax, word [dataPointer]
    inc byte [eax]
    jmp .next_instruction

.dec_cell:
    movzx eax, word [dataPointer]
    dec byte [eax]
    jmp .next_instruction

.out_cell:
    movzx eax, word [dataPointer]
    mov al, [eax]
    mov ah, 09h
    int 10h
    call incrementCursor
    jmp .next_instruction

.in_cell:
    mov ah, 00h
    int 16h
    mov ah, 09h
    int 10h
    mov cl, al
    call incrementCursor
    movzx eax, word [dataPointer]
    mov [eax], cl
    mov cx, 1
    jmp .next_instruction

.jump_forward:
    movzx eax, word [dataPointer]
    mov al, [eax]
    test al, 0FFh
    jnz .next_instruction
    mov cx, 1
.jump_forward_loop:
    inc word [programCounter]
    movzx eax, word [programCounter]
    cmp byte [eax], '['
    jne .jump_forward_loop_no_open
    inc cx
.jump_forward_loop_no_open:
    cmp byte [eax], ']'
    jne .jump_forward_loop_no_close
    dec cx
.jump_forward_loop_no_close:
    test cx, 0FFh
    jnz .jump_forward_loop
    mov cx, 1
    jmp .next_instruction

.jump_backward:
    movzx eax, word [dataPointer]
    mov al, [eax]
    test al, 0FFh
    jz .next_instruction
    mov cx, 1
.jump_backward_loop:
    dec word [programCounter]
    movzx eax, word [programCounter]
    cmp byte [eax], ']'
    jne .jump_backward_loop_no_close
    inc cx
.jump_backward_loop_no_close:
    cmp byte [eax], '['
    jne .jump_backward_loop_no_open
    dec cx
.jump_backward_loop_no_open:
    test cx, 0FFh
    jnz .jump_backward_loop
    mov cx, 1
    jmp .next_instruction

incrementCursor:
    inc dl
    cmp dl, 80
    jne .no_newline
    xor dl, dl
    inc dh
.no_newline:
    mov ah, 02h
    int 10h
    ret

decrementCursor:
    test dl, 0FFh
    jnz .no_newline
    dec dh
    mov dl, 80
.no_newline:
    dec dl
    mov ah, 02h
    int 10h
    ret

programCounter:
    dw 0

print_message:
    mov bl, 0x1F
    mov ax, 1301h
    int 10h
    ret

print_message2:
    mov bl, 0x0F
    mov ax, 1301h
    int 10h
    ret

print_string:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

set_cursor_pos:
    mov ah, 2h
    xor bh, bh
    int 10h
    ret

esc_exit:
    mov ax, 0600h
    mov bh, 0x0F
    xor cx, cx
    mov dx, 184Fh
    int 10h

    mov ax, 0x12
    int 0x10

    ret

dataPointer:
    dw 0
    msg db 13, 10, 'PRos brainf v0.1                                                                 ', 0
    hr db 13, 10, '________________________________________________________________________________', 0

    helper db 13, 10, 'ENTER - run code  ESC - quit                                                      ', 0

sectorEnd: