; -----------------------------
; Load and apply theme from THEME.CFG
; IN  : Nothing
; OUT : Nothing (carry flag set on error)
load_and_apply_theme:
    pusha

    call save_current_dir

    call fs_parent_directory

    mov ax, conf_dir_name
    call fs_change_directory
    jc .error
    
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

    call restore_current_dir
    
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