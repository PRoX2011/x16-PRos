; ==================================================================
; x16-PRos - Kernel String API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Provides string functions via INT 0x23
; Function codes in AH:
;   0x00: Re-Initialize string API
;   0x01: Get string length (SI = string, returns AX = length)
;   0x02: Convert string to uppercase (SI = string)
;   0x03: Copy string (SI = source, DI = destination)
;   0x04: Remove leading/trailing spaces (SI = string)
;   0x05: Compare strings (SI = string1, DI = string2, returns CF set if equal)
;   0x06: Compare strings with length limit (SI = string1, DI = string2, CL = length, returns CF set if equal)
;   0x07: Tokenize string (SI = string, AL = delimiter, returns DI = next token)
;   0x08: Input string from keyboard (SI = buffer)
;   0x09: Clear screen
;   0x0A: Get time string (BX = buffer)
;   0x0B: Get date string (BX = buffer)
;   0x0C: Convert BCD to integer (AL = BCD, returns AL = integer)
;   0x0D: Convert integer to string (AX = integer, returns AX = string)
;   0x0E: Get cursor position (returns DL = column, DH = row)
;   0x0F: Move cursor (DL = column, DH = row)
;   0x10: Parse string (SI = string, returns AX = token1, BX = token2, CX = token3, DX = token4)
; ==================================================================

[BITS 16]

api_string_init:
    pusha
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x23*4], int23_handler
    mov word [es:0x23*4+2], cs
    sti
    pop es
    popa
    ret

int23_handler:
    pusha
    push ds
    push es
    
    mov bp, cs
    mov ds, bp
    mov es, bp
    
    mov al, ah
    
    cmp al, 0x00
    je .init
    cmp al, 0x01
    je .string_length
    cmp al, 0x02
    je .string_uppercase
    cmp al, 0x03
    je .string_copy
    cmp al, 0x04
    je .string_chomp
    cmp al, 0x05
    je .string_compare
    cmp al, 0x06
    je .string_strincmp
    cmp al, 0x07
    je .string_tokenize
    cmp al, 0x08
    je .string_input
    cmp al, 0x09
    je .clear_screen
    cmp al, 0x0A
    je .get_time_string
    cmp al, 0x0B
    je .get_date_string
    cmp al, 0x0C
    je .bcd_to_int
    cmp al, 0x0D
    je .int_to_string
    cmp al, 0x0E
    je .get_cursor_pos
    cmp al, 0x0F
    je .move_cursor
    cmp al, 0x10
    je .string_parse
    
    stc
    jmp .done

.init:
    jmp .done

.string_length:
    mov ax, si
    call string_string_length
    mov bp, sp
    mov [bp+14], ax
    jmp .done

.string_uppercase:
    mov ax, si
    call string_string_uppercase
    jmp .done

.string_copy:
    call string_string_copy
    jmp .done

.string_chomp:
    mov ax, si
    call string_string_chomp
    jmp .done

.string_compare:
    call string_string_compare
    jmp .done_flags

.string_strincmp:
    call string_string_strincmp
    jmp .done_flags

.string_tokenize:
    mov ax, si
    call string_string_tokenize
    mov bp, sp
    mov [bp+4], di
    jmp .done

.string_input:
    mov ax, si
    call string_input_string
    jmp .done

.clear_screen:
    call string_clear_screen
    jmp .done

.get_time_string:
    call string_get_time_string
    jmp .done

.get_date_string:
    call string_get_date_string
    jmp .done

.bcd_to_int:
    call string_bcd_to_int
    mov bp, sp
    mov [bp+14], al
    jmp .done

.int_to_string:
    call string_int_to_string
    mov bp, sp
    mov [bp+14], ax
    jmp .done

.get_cursor_pos:
    call string_get_cursor_pos
    mov bp, sp
    mov [bp+10], dx
    jmp .done

.move_cursor:
    call string_move_cursor
    jmp .done

.string_parse:
    call string_string_parse
    mov bp, sp
    mov [bp+14], ax
    mov [bp+12], bx
    mov [bp+10], cx
    mov [bp+8], dx
    jmp .done

.done:
    pop es
    pop ds
    popa
    iret

.done_flags:
    pushf
    pop ax
    pop es
    pop ds
    popa
    push ax
    popf
    iret