; BASIC INPUT/OUTPUT LIB for PRos
%ifndef BASICIO
%define BASICIO


; Print String to Screen. Text Mode
; si - string address
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


; Print Newline to Screen. Text Mode
; no args
print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; Green text
; si - string
print_string_green:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0A
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; Cyan text
; si - string
print_string_cyan:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0B
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; Red text
; si - string
print_string_red:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x055FC
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; Scan String From Input
; si - buffer
; bx - max count
scan_string:
    mov di, si
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, bx
    jge .done_read
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp di, si
    je .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0
    ret

%endif