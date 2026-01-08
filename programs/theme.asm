; ==================================================================
; x16-PRos -- THEME. Theming tool for PRos terminal
; Copyright (C) 2025 PRoX2011
;
; Usage: THEME <theme name>
;
; Available themes:
;   DEFAULT, VGA, UBUNTU, OCEAN
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov [param_list], si

    push cs
    pop ds
    push cs
    pop es

    mov si, [param_list]
    call string_string_parse
    
    cmp ax, 0
    je print_usage

    mov [arg_ptr], ax
    call string_string_uppercase

    mov si, [arg_ptr]
    mov di, str_default
    call string_string_compare
    jc set_default

    mov si, [arg_ptr]
    mov di, str_vga
    call string_string_compare
    jc set_vga

    mov si, [arg_ptr]
    mov di, str_ubuntu
    call string_string_compare
    jc set_ubuntu

    mov si, [arg_ptr]
    mov di, str_ocean
    call string_string_compare
    jc set_ocean

    jmp print_usage

; ------------------------------------------------
; Theme Selection Handlers
; ------------------------------------------------

set_default:
    mov si, theme_default_data
    mov cx, theme_default_size
    jmp save_theme

set_vga:
    mov si, theme_vga_data
    mov cx, theme_vga_size
    jmp save_theme

set_ubuntu:
    mov si, theme_ubuntu_data
    mov cx, theme_ubuntu_size
    jmp save_theme

set_ocean:
    mov si, theme_ocean_data
    mov cx, theme_ocean_size
    jmp save_theme

save_theme:
    mov di, 43008
    push cx
    rep movsb
    pop cx

    ; Save current directory
    mov ah, 0x0E
    int 0x22

    ; Go to root 
    mov ah, 0x0A    
    int 0x22
    
    ; Switch to /CONF.DIR
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22
    
    ; Write THEME.CFG
    mov ah, 0x03
    mov si, theme_cfg_file
    mov bx, 43008
    int 0x22
    
    ; Restore current directory
    mov ah, 0x0F
    int 0x22

    ; Success message
    mov ah, 0x02    
    mov si, msg_success
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


print_usage:
    mov ah, 0x04
    mov si, msg_usage
    int 0x21
    mov ah, 0x05
    int 0x21
    ret

string_string_parse:
    push si
    mov ax, si
    xor bx, bx
    xor cx, cx
    xor dx, dx
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
.finish:
    pop ax
    pop si
    ret

string_string_uppercase:
    push di
    mov di, [arg_ptr]
.more:
    cmp byte [di], 0
    je .done
    cmp byte [di], 'a'
    jb .next
    cmp byte [di], 'z'
    ja .next
    sub byte [di], 20h
.next:
    inc di
    jmp .more
.done:
    pop di
    ret

string_string_compare:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc
    ret
.equal:
    popa
    stc
    ret


param_list      dw 0
arg_ptr         dw 0

conf_dir_name   db 'CONF.DIR', 0
theme_cfg_file  db 'THEME.CFG', 0

str_default     db 'DEFAULT', 0
str_vga         db 'VGA', 0
str_ubuntu      db 'UBUNTU', 0
str_ocean       db 'OCEAN', 0

msg_usage       db 'Usage: THEME <DEFAULT | VGA | UBUNTU | OCEAN>', 0
msg_success     db 'Theme applied successfully.', 0

; --- THEME DATA ---

theme_default_data:
    db '0,2,3,5', 10
    db '1,25,24,52', 10
    db '2,41,52,31', 10
    db '3,12,32,32', 10
    db '4,52,13,32', 10
    db '5,27,28,48', 10
    db '6,10,40,38', 10
    db '7,63,57,45', 10
    db '8,3,14,17', 10
    db '9,50,19,5', 10
    db '10,22,27,29', 10
    db '11,45,34,0', 10
    db '12,25,30,32', 10
    db '13,32,37,37', 10
    db '14,36,40,40', 10
    db '15,63,58,44', 0
theme_default_size equ $ - theme_default_data

theme_ubuntu_data:
    db '0,20,9,14', 10
    db '1,18,26,40', 10
    db '2,21,37,10', 10
    db '3,18,26,40', 10
    db '4,46,9,12', 10
    db '5,29,25,36', 10
    db '6,41,15,12', 10
    db '7,22,26,28', 10
    db '8,14,19,22', 10
    db '9,28,41,53', 10
    db '10,33,53,22', 10
    db '11,16,53,56', 10
    db '12,53,17,20', 10
    db '13,41,34,45', 10
    db '14,56,55,27', 10
    db '15,47,50,52', 0
theme_ubuntu_size equ $ - theme_ubuntu_data

theme_vga_data:
    db '0,0,0,0', 10
    db '1,0,0,42', 10
    db '2,0,42,0', 10
    db '3,0,42,42', 10
    db '4,42,0,0', 10
    db '5,42,0,42', 10
    db '6,42,21,0', 10
    db '7,42,42,42', 10
    db '8,21,21,21', 10
    db '9,21,21,63', 10
    db '10,21,63,21', 10
    db '11,21,63,63', 10
    db '12,63,21,21', 10
    db '13,63,21,63', 10
    db '14,63,63,21', 10
    db '15,63,63,63', 0
theme_vga_size equ $ - theme_vga_data

theme_ocean_data:
    db '0,5,8,15', 10
    db '1,10,15,30', 10
    db '2,15,40,35', 10
    db '3,20,45,50', 10
    db '4,50,20,25', 10
    db '5,35,25,45', 10
    db '6,25,35,40', 10
    db '7,45,50,55', 10
    db '8,15,20,25', 10
    db '9,25,35,55', 10
    db '10,30,55,50', 10
    db '11,35,60,63', 10
    db '12,60,30,35', 10
    db '13,50,40,55', 10
    db '14,55,58,45', 10
    db '15,58,60,63', 0
theme_ocean_size equ $ - theme_ocean_data