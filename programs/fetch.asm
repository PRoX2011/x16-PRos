; ==================================================================
; x16-PRos -- FETCH. Neofetch-like fetch tool for x16-PRos
; Copyright (C) 2025 PRoX2011
; 
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    ; Read USER config file to get user name
    mov ah, 0x02
    mov si, user_cfg
    mov cx, buffer
    int 0x22

    mov ah, 0x01
    mov si, ascii_art
    int 0x21

    mov ah, 0x03
    xor bh, bh 
    int 0x10      

    mov [cursor_y], dh
    mov [cursor_x], dl

    sub dh, 25  
    mov dl, 40    
    mov ah, 0x02
    xor bh, bh    
    int 0x10

    ; ------ The top of the fetch output ------
    mov ah, 0x01
    mov si, buffer
    int 0x21

    mov ah, 0x01
    mov si, dog_symbol
    int 0x21

    mov ah, 0x01
    mov si, os_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    mov ah, 0x01
    mov si, sep
    int 0x21

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ------------------ OS name --------------
    mov ah, 0x03
    mov si, os_msg
    int 0x21

    mov ah, 0x01
    mov si, os_full_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Host name --------------
    mov ah, 0x03
    mov si, host_name_msg
    int 0x21

    mov ah, 0x01
    mov si, host_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; --------------- Kernel name -------------
    mov ah, 0x03
    mov si, kernel_msg
    int 0x21

    mov ah, 0x01
    mov si, kernel_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Shell name -------------
    mov ah, 0x03
    mov si, shell_msg
    int 0x21

    mov ah, 0x01
    mov si, shell_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- CPU name ---------------
    mov ah, 0x03
    mov si, cpu_msg
    int 0x21

    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part
    ; -----------------------------------------

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- VESA support -----------
    mov ah, 0x03
    mov si, vesa_msg
    int 0x21

    ; Check VESA support
    push es
    mov ax, ds
    mov es, ax
    mov di, vesa_buffer
    mov ax, 0x4F00
    int 0x10
    pop es

    cmp al, 0x4F
    je .vesa_yes

    mov ah, 0x04
    mov si, no_str
    int 0x21
    jmp .after_vesa

.vesa_yes:
    mov ah, 0x02
    mov si, yes_str
    int 0x21

.after_vesa:
    ; -----------------------------------------
    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Resolution--------------
    mov ah, 0x03
    mov si, resolution_msg
    int 0x21

    mov ax, 0x4F03   
    int 0x10
    cmp ax, 0x004F    
    jne .resolution_unknown
    
    push es
    mov ax, ds
    mov es, ax
    mov di, vesa_buffer
    mov cx, bx         
    mov ax, 0x4F01  
    int 0x10
    pop es
    
    cmp ax, 0x004F   
    jne .resolution_unknown
    
    mov ax, [vesa_buffer + 12h]  
    mov bx, [vesa_buffer + 14h]  
    
    call print_resolution
    jmp .after_resolution

.resolution_unknown:
    mov ah, 0x04
    mov si, unknown_str
    int 0x21

.after_resolution:
    ; -----------------------------------------
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Color blocks -----------
    mov cx, 16    
    mov bl, 0          
.color_blocks:
    push cx             
    mov ah, 0x07        
    int 0x21
    mov ah, 0x08        
    mov si, block_char
    int 0x21
    inc bl             
    pop cx           
    loop .color_blocks
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x02
    xor bh, bh      
    mov dh, [cursor_y]  
    mov dl, [cursor_x]  
    int 0x10

    ret

.copy_user:
    rep movsb
    mov byte [di], 0
    
    ret

print_full_name_part:
    cpuid
    push edx
    push ecx
    push ebx
    push eax
    mov cx, 4
.loop4n:
    pop edx
    call print_edx
    loop .loop4n
    ret

print_edx:
    mov ah, 0x0E
    mov bx, 4
.loop4r:
    mov al, dl
    int 0x10
    ror edx, 8
    dec bx
    jnz .loop4r
    ret


print_resolution:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, ax
    call print_number
    
    mov ah, 0x01
    mov si, x_char
    int 0x21
     
    mov cx, bx
    call print_number
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_number:
    push ax
    push bx
    push cx
    push dx
    
    mov ax, cx
    mov bx, 10
    mov cx, 0
    
.digit_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .digit_loop
    
.output_loop:
    pop ax
    add al, '0'
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    loop .output_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

user_cfg       db 'USER.CFG', 0

sep            db '---------------', 0
dog_symbol     db '@', 0

os_msg         db 'OS: ', 0
host_name_msg  db 'Host: ', 0
kernel_msg     db 'Kernel: ', 0
shell_msg      db 'Shell: ', 0
cpu_msg        db 'CPU: ', 0
vesa_msg       db 'VESA: ', 0
resolution_msg db 'Resolution: ', 0

os_name        db 'PRos', 0
os_full_name   db 'x16-PRos x86_64', 0
kernel_name    db 'PRos Kernel', 0
shell_name     db 'PRos Terminal', 0
host_name      db 'x86_PC', 0
yes_str        db 'Yes', 0
no_str         db 'No', 0

unknown_str    db 'Unknown', 0

cursor_x       db 0
cursor_y       db 0

block_char     db 0xDB, 0 
x_char         db 'x', 0

ascii_art      db '                   .l.    lo,                 ', 13, 10
               db '                   ;ll.  ,lll.                ', 13, 10
               db '                   ,lllc lc .lll;             ', 13, 10
               db '                   .lllloll   clll            ', 13, 10
               db '                .ccllllll. , ;ll;             ', 13, 10
               db '               ccllllllllllo ,loll            ', 13, 10
               db '             lllllllllllloolllc               ', 13, 10
               db '           llllllllllllllllll:lc              ', 13, 10
               db '           llllllllllllllllllllll.            ', 13, 10
               db '         cllllllllllllllllllllllll            ', 13, 10
               db '     :clllllllllllllllllllllllllllo.          ', 13, 10
               db 'ccllll:      .ll ;lllllllllllllllllo          ', 13, 10
               db 'lllllll        .;  cllllllllllllllll,         ', 13, 10
               db ' llll.           .  ,lllllllllllllllo         ', 13, 10
               db ' ;llolc: c;         .llllllllllllllll,        ', 13, 10
               db '  lcllllolll  ,   . .lllllllllllllllll        ', 13, 10
               db '     ;c .lllo ., .: lllllllllllllllll;        ', 13, 10
               db '      ;:, ,lloo; cool. ;lllllllllllllll.      ', 13, 10
               db '       ;o:.llllolll.   ,lllllllllllllll:      ', 13, 10
               db '        llollll.      .lllllllllllllll.       ', 13, 10
               db '         :ll         .ollllllllllll           ', 13, 10
               db '                    :llllllll:                ', 13, 10
               db '                    lllll,                    ', 13, 10
               db '                    ;ll:                      ', 13, 10
               db '                     l                        ', 13, 10, 0

buffer times 32 db 0
vesa_buffer times 512 db 0