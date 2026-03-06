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
    push ds
    xor ax, ax
    mov es, ax
    mov word [es:0x21*4], int21_handler
    mov word [es:0x21*4+2], cs
    pop ds
    pop es
    popa
    ret

int21_handler:
    pusha
    cld
    cmp ah, 0x00
    je .init
    cmp ah, 0x01
    je .print_white
    cmp ah, 0x02
    je .print_green
    cmp ah, 0x03
    je .print_cyan
    cmp ah, 0x04
    je .print_red
    cmp ah, 0x05
    je .newline
    cmp ah, 0x06
    je .clear_screen
    cmp ah, 0x07
    je .set_color
    cmp ah, 0x08
    je .print_current_color
    jmp .done

.init:
    mov ax, 0x12
    int 0x10
    jmp .done

.print_white:
    call print_string
    jmp .done

.print_green:
    call print_string_green
    jmp .done

.print_cyan:
    call print_string_cyan
    jmp .done

.print_red:
    call print_string_red
    jmp .done

.newline:
    call print_newline
    jmp .done

.clear_screen:
    call set_video_mode
    jmp .done

.set_color:
    mov [current_color], bl
    jmp .done

.print_current_color:
    mov bl, [current_color]
    call print_string_color
    jmp .done

.done:
    popa
    iret