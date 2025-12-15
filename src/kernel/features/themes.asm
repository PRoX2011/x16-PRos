%macro SetPaletteBios 4
    mov ax, 1010h   
    mov bx, %1     
    mov dh, %2   
    mov ch, %3      
    mov cl, %4    
    int 10h        
%endmacro

set_default_palette:
    ret
    
set_groovybox_palette:
    pusha       

    ; Color 0
    SetPaletteBios 0, 8, 9, 11

    ; Color 1
    SetPaletteBios 1, 0, 0, 32

    ; Color 2
    SetPaletteBios 2, 0, 32, 0

    ; Color 3
    SetPaletteBios 3, 0, 32, 32

    ; Color 4
    SetPaletteBios 4, 32, 0, 0

    ; Color 5
    SetPaletteBios 5, 20, 13, 18

    ; Color 6
    SetPaletteBios 6, 42, 17, 6

    ; Color 7
    SetPaletteBios 7, 24, 22, 22

    ; Color 8
    SetPaletteBios 8, 14, 14, 14

    ; Color 9
    SetPaletteBios 9, 31, 37, 46

    ; Color 10
    SetPaletteBios 10, 35, 50, 15

    ; Color 11
    SetPaletteBios 11, 20, 51, 50

    ; Color 12
    SetPaletteBios 12, 55, 13, 13

    ; Color 13
    SetPaletteBios 13, 43, 31, 38

    ; Color 14
    SetPaletteBios 14, 58, 51, 21

    ; Color 15
    SetPaletteBios 15, 56, 53, 52

    popa   
    ret

set_ubuntu_palette:
    pusha      

    ; Color 0
    SetPaletteBios 0, 20, 9, 14

    ; Color 1
    SetPaletteBios 1, 18, 26, 40

    ; Color 2
    SetPaletteBios 2, 21, 37, 10

    ; Color 3
    SetPaletteBios 3, 18, 26, 40

    ; Color 4
    SetPaletteBios 4, 46, 9, 12

    ; Color 5
    SetPaletteBios 5, 29, 25, 36

    ; Color 6
    SetPaletteBios 6, 41, 15, 12

    ; Color 7
    SetPaletteBios 7, 22, 26, 28

    ; Color 8
    SetPaletteBios 8, 14, 19, 22

    ; Color 9
    SetPaletteBios 9, 28, 41, 53

    ; Color 10
    SetPaletteBios 10, 33, 53, 22

    ; Color 11
    SetPaletteBios 11, 16, 53, 56

    ; Color 12
    SetPaletteBios 12, 53, 17, 20

    ; Color 13
    SetPaletteBios 13, 41, 34, 45

    ; Color 14
    SetPaletteBios 14, 56, 55, 27

    ; Color 15
    SetPaletteBios 15, 47, 50, 52

    popa  
    ret

; -----------------------------
; Load and apply theme from THEME.CFG
; IN  : Nothing
; OUT : Nothing (carry flag set on error)
load_and_apply_theme:
    pusha
    
    ; Load THEME.CFG file
    mov ax, theme_cfg_file
    mov cx, 32768
    call fs_load_file
    jc .error
    
    ; Check if file is empty
    cmp bx, 0
    je .error
    
    ; Parse and apply theme
    mov si, 32768 
    mov word [.line_count], 0
    
.parse_loop:
    cmp word [.line_count], 16
    jge .done
    
    ; Parse line: "index, r, g, b"
    call .parse_color_line
    jc .error
    
    inc word [.line_count]
    jmp .parse_loop

.done:
    clc
    popa
    ret

.error:
    stc
    popa
    ret

.parse_color_line:
    pusha
    
    call .skip_whitespace
    
    call .parse_number
    jc .parse_error
    mov [.color_index], al
    
    call .skip_comma_and_space
    jc .parse_error
    
    call .parse_number
    jc .parse_error
    mov [.red], al
    
    call .skip_comma_and_space
    jc .parse_error
    
    call .parse_number
    jc .parse_error
    mov [.green], al
    
    call .skip_comma_and_space
    jc .parse_error
    
    call .parse_number
    jc .parse_error
    mov [.blue], al
    
    call .skip_to_newline
    
    mov ax, 1010h
    mov bl, [.color_index]
    mov bh, 0
    mov dh, [.red]
    mov ch, [.green]
    mov cl, [.blue]
    int 10h
    
    popa
    clc
    ret

.parse_error:
    popa
    stc
    ret

.skip_whitespace:
    push ax
.skip_ws_loop:
    lodsb
    cmp al, ' '
    je .skip_ws_loop
    cmp al, 9           
    je .skip_ws_loop
    dec si            
    pop ax
    ret

.skip_comma_and_space:
    push ax
    call .skip_whitespace
    lodsb
    cmp al, ','
    jne .skip_comma_error
    call .skip_whitespace
    pop ax
    clc
    ret
.skip_comma_error:
    pop ax
    stc
    ret

.skip_to_newline:
    push ax
.skip_nl_loop:
    lodsb
    cmp al, 0         
    je .skip_nl_done
    cmp al, 10        
    je .skip_nl_done
    cmp al, 13         
    je .skip_nl_check_lf
    jmp .skip_nl_loop
.skip_nl_check_lf:
    lodsb
    cmp al, 10
    je .skip_nl_done
    dec si        
.skip_nl_done:
    pop ax
    ret

.parse_number:
    push bx
    push cx
    
    xor ax, ax
    xor cx, cx 
    
.parse_num_loop:
    push ax
    lodsb
    
    cmp al, '0'
    jb .parse_num_done_char
    cmp al, '9'
    ja .parse_num_done_char
    
    sub al, '0'
    mov bl, al
    pop ax
    
    mov bh, 10
    mul bh
    
    add al, bl
    inc cx
    jmp .parse_num_loop
    
.parse_num_done_char:
    pop bx            
    dec si            
    mov al, bl         
    
    cmp cx, 0
    je .parse_num_error
    
    pop cx
    pop bx
    clc
    ret

.parse_num_error:
    pop cx
    pop bx
    stc
    ret

.line_count   dw 0
.color_index  db 0
.red          db 0
.green        db 0
.blue         db 0