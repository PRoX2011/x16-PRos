; ==================================================================
; x16-PRos - Kernel String API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Provides string functions via INT 0x23
; Function codes in AH:
;   0x00: Initialize string API (no-op, reserved)
;   0x01: Get string length (AX = string, returns AX = length)
;   0x02: Convert string to uppercase (AX = string)
;   0x03: Copy string (SI = source, DI = destination)
;   0x04: Remove leading/trailing spaces (AX = string)
;   0x05: Compare strings (SI = string1, DI = string2, returns CF set if equal)
;   0x06: Compare strings with length limit (SI = string1, DI = string2, CL = length, returns CF set if equal)
;   0x07: Tokenize string (SI = string, AL = delimiter, returns DI = next token)
;   0x08: Input string from keyboard (AX = buffer)
;   0x09: Clear screen
;   0x0A: Get time string (BX = buffer)
;   0x0B: Get date string (BX = buffer)
;   0x0C: Convert BCD to integer (AL = BCD, returns AL = integer)
;   0x0D: Convert integer to string (AX = integer, returns AX = string)
;   0x0E: Get cursor position (returns DL = column, DH = row)
;   0x0F: Move cursor (DL = column, DH = row)
;   0x10: Parse string (SI = string, returns AX = token1, BX = token2, CX = token3, DX = token4)
; Preserves all registers unless specified in function description
; Sets carry flag (CF) where applicable (e.g., string comparison)
; ==================================================================

[BITS 16]

; -----------------------------
; Initialize the string API (sets up INT 0x23, currently no-op for string-specific init)
; IN  : None
; OUT : None
; Preserves: All registers
api_string_init:
    pusha
    push es
    ; Set up INT 0x23 in IVT
    xor ax, ax
    mov es, ax
    mov word [es:0x23*4], int23_handler ; Offset
    mov word [es:0x23*4+2], cs          ; Segment
    pop es
    popa
    ret

; -----------------------------
; INT 0x23 Handler
; IN  : AH = Function code, other registers per function (AX, BX, SI, DI, etc.)
; OUT : Per function (e.g., AX for string_length, DL/DH for get_cursor_pos)
; Preserves: All registers unless specified in function
int23_handler:
    pusha
    pushf                       ; Save flags (for carry flag)
    cmp ah, 0x00
    je .init
    cmp ah, 0x01
    je .string_length
    cmp ah, 0x02
    je .string_uppercase
    cmp ah, 0x03
    je .string_copy
    cmp ah, 0x04
    je .string_chomp
    cmp ah, 0x05
    je .string_compare
    cmp ah, 0x06
    je .string_strincmp
    cmp ah, 0x07
    je .string_tokenize
    cmp ah, 0x08
    je .string_input
    cmp ah, 0x09
    je .clear_screen
    cmp ah, 0x0A
    je .get_time_string
    cmp ah, 0x0B
    je .get_date_string
    cmp ah, 0x0C
    je .bcd_to_int
    cmp ah, 0x0D
    je .int_to_string
    cmp ah, 0x0E
    je .get_cursor_pos
    cmp ah, 0x0F
    je .move_cursor
    cmp ah, 0x10
    je .string_parse
    stc                         ; Unknown function, set carry
    jmp .done

.init:
    ; No-op (reserved for future initialization)
    jmp .done

.string_length:
    mov word [.tmp_ax], ax      ; Save string pointer
    call string_string_length
    mov word [.tmp_ax], ax      ; Save length
    jmp .done

.string_uppercase:
    mov word [.tmp_ax], ax      ; Save string pointer
    call string_string_uppercase
    jmp .done

.string_copy:
    mov word [.tmp_si], si      ; Save source
    mov word [.tmp_di], di      ; Save destination
    call string_string_copy
    jmp .done

.string_chomp:
    mov word [.tmp_ax], ax      ; Save string pointer
    call string_string_chomp
    jmp .done

.string_compare:
    mov word [.tmp_si], si      ; Save string1
    mov word [.tmp_di], di      ; Save string2
    call string_string_compare
    jmp .done

.string_strincmp:
    mov word [.tmp_si], si      ; Save string1
    mov word [.tmp_di], di      ; Save string2
    mov byte [.tmp_cl], cl      ; Save length
    call string_string_strincmp
    jmp .done

.string_tokenize:
    mov word [.tmp_si], si      ; Save string
    mov byte [.tmp_al], al      ; Save delimiter
    call string_string_tokenize
    mov word [.tmp_di], di      ; Save next token
    mov word [.tmp_si], si      ; Save updated SI
    jmp .done

.string_input:
    mov word [.tmp_ax], ax      ; Save buffer
    call string_input_string
    jmp .done

.clear_screen:
    call string_clear_screen
    jmp .done

.get_time_string:
    mov word [.tmp_bx], bx      ; Save buffer
    call string_get_time_string
    jmp .done

.get_date_string:
    mov word [.tmp_bx], bx      ; Save buffer
    call string_get_date_string
    jmp .done

.bcd_to_int:
    mov byte [.tmp_al], al      ; Save BCD
    call string_bcd_to_int
    mov byte [.tmp_al], al      ; Save integer
    jmp .done

.int_to_string:
    mov word [.tmp_ax], ax      ; Save integer
    call string_int_to_string
    mov word [.tmp_ax], ax      ; Save string pointer
    jmp .done

.get_cursor_pos:
    call string_get_cursor_pos
    mov byte [.tmp_dl], dl      ; Save column
    mov byte [.tmp_dh], dh      ; Save row
    jmp .done

.move_cursor:
    mov byte [.tmp_dl], dl      ; Save column
    mov byte [.tmp_dh], dh      ; Save row
    call string_move_cursor
    jmp .done

.string_parse:
    mov word [.tmp_si], si      ; Save string
    call string_string_parse
    mov word [.tmp_ax], ax      ; Save token1
    mov word [.tmp_bx], bx      ; Save token2
    mov word [.tmp_cx], cx      ; Save token3
    mov word [.tmp_dx], dx      ; Save token4
    jmp .done

.done:
    ; Restore return values
    mov ax, word [.tmp_ax]
    mov bx, word [.tmp_bx]
    mov cx, word [.tmp_cx]
    mov dx, word [.tmp_dx]
    mov si, word [.tmp_si]
    mov di, word [.tmp_di]
    mov cl, byte [.tmp_cl]
    mov al, byte [.tmp_al]
    mov dl, byte [.tmp_dl]
    mov dh, byte [.tmp_dh]
    popf                        ; Restore flags (including carry)
    popa
    iret

; Temporary storage for register values
.tmp_ax dw 0
.tmp_bx dw 0
.tmp_cx dw 0
.tmp_dx dw 0
.tmp_si dw 0
.tmp_di dw 0
.tmp_cl db 0
.tmp_al db 0
.tmp_dl db 0
.tmp_dh db 0