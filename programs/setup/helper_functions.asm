; -----------------------------
; Set VGA background color
; IN  : AL = color number (0-15)
set_background_color:
    pusha
    mov ah, 0x0B
    mov bh, 0  
    mov bl, al     
    int 0x10
    
    popa
    ret

string_move_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

string_get_cursor_pos:
    pusha
    mov ah, 0x03
    mov bh, 0
    int 0x10
    mov [.tmp_dl], dl
    mov [.tmp_dh], dh
    popa
    mov dl, [.tmp_dl]
    mov dh, [.tmp_dh]
    ret

.tmp_dl db 0
.tmp_dh db 0

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