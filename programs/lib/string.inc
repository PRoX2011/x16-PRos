; ==================================================================
; x16-PRos - string functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; =======================================================================
; STRING_STRING_LENGTH - Calculates the length of a null-terminated string
; IN  : AX = pointer to string
; OUT : AX = length of string (excluding null terminator)
; =======================================================================
string_string_length:
    pusha
    mov bx, ax
    mov cx, 0

.more:
    cmp byte [bx], 0
    je .done
    inc bx
    inc cx
    jmp .more

.done:
    mov word [.tmp_counter], cx
    popa
    mov ax, [.tmp_counter]
    ret

.tmp_counter dw 0

; =======================================================================
; STRING_STRING_UPPERCASE - Converts a string to uppercase
; IN  : AX = pointer to string
; OUT : String is modified in place
; =======================================================================
string_string_uppercase:
    pusha
    mov si, ax

.more:
    cmp byte [si], 0
    je .done
    cmp byte [si], 'a'
    jb .noatoz
    cmp byte [si], 'z'
    ja .noatoz
    sub byte [si], 20h
    inc si
    jmp .more

.noatoz:
    inc si
    jmp .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_COPY - Copies a null-terminated string
; IN  : SI = pointer to source string
;       DI = pointer to destination buffer
; OUT : String copied to destination (including null terminator)
; =======================================================================
string_string_copy:
    pusha

.more:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    cmp byte al, 0
    jne .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_CHOMP - Removes leading and trailing spaces from string
; IN  : AX = pointer to string
; OUT : String is modified in place, trimmed of whitespace
; =======================================================================
string_string_chomp:
    pusha
    mov dx, ax
    mov di, ax
    mov cx, 0

.keepcounting:
    cmp byte [di], ' '
    jne .counted
    inc cx
    inc di
    jmp .keepcounting

.counted:
    cmp cx, 0
    je .finished_copy
    mov si, di
    mov di, dx

.keep_copying:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .finished_copy
    inc si
    inc di
    jmp .keep_copying

.finished_copy:
    mov ax, dx
    call string_string_length
    cmp ax, 0
    je .done
    mov si, dx
    add si, ax

.more:
    dec si
    cmp byte [si], ' '
    jne .done
    mov byte [si], 0
    jmp .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_COMPARE - Compares two null-terminated strings
; IN  : SI = pointer to first string
;       DI = pointer to second string
; OUT : CF = 1 if strings are equal, CF = 0 if different
; =======================================================================
string_string_compare:
    pusha

.more:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_same
    cmp al, 0
    je .terminated
    inc si
    inc di
    jmp .more

.not_same:
    popa
    clc
    ret

.terminated:
    popa
    stc
    ret

; =======================================================================
; STRING_STRING_STRINCMP - Compares first CL characters of two strings
; IN  : SI = pointer to first string
;       DI = pointer to second string
;       CL = number of characters to compare
; OUT : CF = 1 if strings match for CL characters, CF = 0 if different
; =======================================================================
string_string_strincmp:
    pusha

.more:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_same
    cmp al, 0
    je .terminated
    inc si
    inc di
    dec cl
    cmp cl, 0
    je .terminated
    jmp .more

.not_same:
    popa
    clc
    ret

.terminated:
    popa
    stc
    ret

; =======================================================================
; STRING_STRING_TOKENIZE - Finds and splits string by delimiter
; IN  : SI = pointer to string
;       AL = delimiter character
; OUT : SI = unchanged (original string start)
;       DI = pointer to next token after delimiter (or 0 if no more)
;       Delimiter in string is replaced with null terminator
; =======================================================================
string_string_tokenize:
    push si

.next_char:
    cmp byte [si], al
    je .return_token
    cmp byte [si], 0
    jz .no_more
    inc si
    jmp .next_char

.return_token:
    mov byte [si], 0
    inc si
    mov di, si
    pop si
    ret

.no_more:
    mov di, 0
    pop si
    ret


; =======================================================================
; STRING_CLEAR_SCREEN - Clears the screen and applies theme
; IN  : Nothing
; OUT : Screen cleared and theme reloaded
; =======================================================================
string_clear_screen:
    mov ah, 0x06
    int 0x21
    ret

; =======================================================================
; STRING_BCD_TO_INT - Converts BCD (Binary Coded Decimal) to integer
; IN  : AL = BCD value
; OUT : AL = integer value
; =======================================================================
string_bcd_to_int:
    push cx
    mov cl, al
    shr al, 4
    and cl, 0Fh
    mov ah, 10
    mul ah
    add al, cl
    pop cx
    ret

; =======================================================================
; STRING_INT_TO_STRING - Converts integer to decimal string
; IN  : AX = integer value
; OUT : AX = pointer to converted string (static buffer)
; =======================================================================
string_int_to_string:
    pusha
    mov cx, 0
    mov bx, 10
    mov di, .t

.push:
    mov dx, 0
    div bx
    inc cx
    push dx
    test ax, ax
    jnz .push
.pop:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    dec cx
    jnz .pop
    mov byte [di], 0
    popa
    mov ax, .t
    ret

.t times 7 db 0

; =======================================================================
; STRING_TO_INT - Converts decimal string to integer
; IN  : SI = pointer to decimal string
; OUT : AX = integer value (-1 if invalid)
; =======================================================================
string_to_int:
    push bx
    push cx
    push dx
    push si
    
    xor ax, ax
    xor bx, bx
    xor cx, cx
    
.convert_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    ja .invalid
    
    sub al, '0'
    mov cl, al
    mov ax, bx
    mov dx, 10
    mul dx
    add ax, cx
    mov bx, ax
    jmp .convert_loop
    
.invalid:
    mov bx, -1
    
.done:
    mov ax, bx
    pop si
    pop dx
    pop cx
    pop bx
    ret

string_move_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

string_string_parse:
    push si
    mov ax, si
    mov bx, 0
    mov cx, 0
    mov dx, 0
    push ax

.loop1:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop1
    dec si
    mov byte [si], 0
    inc si
    mov bx, si

.loop2:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop2
    dec si
    mov byte [si], 0
    inc si
    mov cx, si

.loop3:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop3
    dec si
    mov byte [si], 0
    inc si
    mov dx, si

.finish:
    pop ax
    pop si
    ret