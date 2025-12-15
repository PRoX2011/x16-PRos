; ==================================================================
; x16-PRos - string functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

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

string_input_string:
    pusha
    mov di, ax
    mov cx, 0

    call string_get_cursor_pos
    mov word [.cursor_col], dx 

.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, 255
    jge .read_loop
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp cx, 0
    je .read_loop
    dec di
    dec cx
    call string_get_cursor_pos
    cmp dl, [.cursor_col]
    jbe .read_loop
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
    popa
    ret

.cursor_col dw 0

string_clear_screen:
    pusha
    mov ax, 0x12
    int 0x10
    popa
    ; Load and aply theme from THEME.CFG file
    call load_and_apply_theme
    ret

string_get_time_string:
    pusha
    mov di, bx
    clc
    mov ah, 2
    int 1Ah
    jnc .read
    clc
    mov ah, 2
    int 1Ah

.read:
    mov al, ch
    call string_bcd_to_int
    mov dx, ax
    mov al, ch
    shr al, 4
    and ch, 0Fh
    call .add_digit
    mov al, ch
    call .add_digit
    mov al, ':'
    stosb
    mov al, cl
    shr al, 4
    and cl, 0Fh
    call .add_digit
    mov al, cl
    call .add_digit
    mov al, ':'
    stosb
    mov al, dh
    shr al, 4
    and dh, 0Fh
    call .add_digit
    mov al, dh
    call .add_digit
    mov byte [di], 0
    popa
    ret

.add_digit:
    add al, '0'
    stosb
    ret

string_get_date_string:
    pusha
    mov di, bx
    mov bx, [fmt_date]
    and bx, 7F03h
    clc
    mov ah, 4
    int 1Ah
    jnc .read
    clc
    mov ah, 4
    int 1Ah

.read:
    cmp bl, 2
    jne .try_fmt1
    mov ah, ch
    call .add_2digits
    mov ah, cl
    call .add_2digits
    mov al, '/'
    stosb
    mov ah, dh
    call .add_2digits
    mov al, '/'
    stosb
    mov ah, dl
    call .add_2digits
    jmp short .done

.try_fmt1:
    cmp bl, 1
    jne .do_fmt0
    mov ah, dl
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, dh
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, ch
    cmp ah, 0
    je .fmt1_year
    call .add_1or2digits
.fmt1_year:
    mov ah, cl
    call .add_2digits
    jmp short .done

.do_fmt0:
    mov ah, dh
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, dl
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, ch
    cmp ah, 0
    je .fmt0_year
    call .add_1or2digits
.fmt0_year:
    mov ah, cl
    call .add_2digits

.done:
    mov ax, 0
    stosw
    popa
    ret

.add_1or2digits:
    test ah, 0F0h
    jz .only_one
    call .add_2digits
    jmp short .two_done
.only_one:
    mov al, ah
    and al, 0Fh
    call .add_digit
.two_done:
    ret

.add_2digits:
    mov al, ah
    shr al, 4
    call .add_digit
    mov al, ah
    and al, 0Fh
    call .add_digit
    ret

.add_digit:
    add al, '0'
    stosb
    ret

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

; -----------------------------
; Convert string to integer
; IN  : SI = string location
; OUT : AX = number
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

parse_prompt:
    push ax
    push bx
    push si
    push di

.loop:
    lodsb               
    cmp al, 0              
    je .done
    cmp al, '$'        
    je .check_username
    cmp al, '%'             
    je .check_hex
.store:
    stosb        
    jmp .loop

.check_username:
    ; Check for $username (next 8 bytes: 'u','s','e','r','n','a','m','e')
    mov ax, [si]
    cmp ax, 0x7375           ; 'u' (0x75), 's' (0x73) -> 0x7375
    jne .store_dollar
    mov ax, [si+2]
    cmp ax, 0x7265           ; 'e' (0x65), 'r' (0x72) -> 0x7265
    jne .store_dollar
    mov ax, [si+4]
    cmp ax, 0x616E           ; 'n' (0x6E), 'a' (0x61) -> 0x616E
    jne .store_dollar
    mov ax, [si+6]
    cmp ax, 0x656D           ; 'm' (0x6D), 'e' (0x65) -> 0x656D
    jne .store_dollar
    add si, 8
    push si
    mov si, user
.copy_user:
    lodsb
    cmp al, 0
    je .user_done
    stosb
    jmp .copy_user
.user_done:
    pop si
    jmp .loop

.store_dollar:
    mov al, '$'
    stosb
    jmp .loop

.check_hex:
    mov al, [si]    
    cmp al, 0                
    je .store_percent
    inc si
    mov ah, [si]     
    cmp ah, 0                
    je .store_percent
    inc si               

    call hex_char_to_nibble
    jc .store_percent        
    mov bl, al
    shl bl, 4             

    mov al, ah
    call hex_char_to_nibble
    jc .store_percent        
    or bl, al     

    mov al, bl
    stosb
    jmp .loop

.store_percent:
    mov al, '%'
    stosb
    dec si     
    cmp ah, 0       
    je .loop
    dec si
    jmp .loop

.done:
    mov byte [di], 0     
    pop di
    pop si
    pop bx
    pop ax
    ret

hex_char_to_nibble:
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .invalid
    cmp al, 'F'
    jbe .uppercase
    cmp al, 'a'
    jb .invalid
    cmp al, 'f'
    jbe .lowercase
.invalid:
    stc
    ret
.digit:
    sub al, '0'
    clc
    ret
.uppercase:
    sub al, 'A'
    add al, 10
    clc
    ret
.lowercase:
    sub al, 'a'
    add al, 10
    clc
    ret