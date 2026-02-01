; ==================================================================
; x16-PRos - Kernel Output API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Provides output functions via INT 0x21
; Function codes in AH:
;   0x00: Re-Initialize output system (sets video mode)
;   0x01: Print string (white, SI = string pointer)
;   0x02: Print string (green, SI = string pointer)
;   0x03: Print string (cyan, SI = string pointer)
;   0x04: Print string (red, SI = string pointer)
;   0x05: Print newline
;   0x06: Clear screen
;   0x07: Set color (BL = color code)
;   0x08: Print string with current color (SI = string pointer)
; Preserves all registers unless specified
; ==================================================================

section .data
current_color db 0x0F    ; Default color: White

section .text

api_output_init:
    pusha
    push es
    xor ax, ax
    mov es, ax
    mov word [es:0x21*4], int21_handler
    mov word [es:0x21*4+2], cs
    pop es
    popa
    ret

int21_handler:
    pusha
    cmp ah, 0x00
    je .init
    cmp ah, 0x01
    je .print_string_white
    cmp ah, 0x02
    je .print_string_green
    cmp ah, 0x03
    je .print_string_cyan
    cmp ah, 0x04
    je .print_string_red
    cmp ah, 0x05
    je .print_newline
    cmp ah, 0x06
    je .clear_screen
    cmp ah, 0x07
    je .set_color
    cmp ah, 0x08
    je .print_colored
    jmp .done

.init:
    mov ax, 0x12
    int 0x10
    jmp .done

.print_string_white:
    mov bl, 0x0F          ; White color
    jmp .print_with_color

.print_string_green:
    mov bl, 0x0A          ; Green color
    jmp .print_with_color

.print_string_cyan:
    mov bl, 0x0B          ; Cyan color
    jmp .print_with_color

.print_string_red:
    mov bl, 0x0C          ; Red color
    jmp .print_with_color

.print_colored:
    mov bl, [current_color]

.print_with_color:
    mov ah, 0x0E
.print_char:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0A
    je .handle_newline
    int 0x10
    jmp .print_char

.handle_newline:
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    jmp .print_char

.print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    jmp .done

.clear_screen:
    mov ax, 0x12
    int 0x10
    jmp .done

.set_color:
    mov [current_color], bl
    jmp .done

.done:
    popa
    iret