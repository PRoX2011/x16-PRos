[BITS 16]
[ORG 0x8000]

; ========== SETUP ROUTINE ==========
setup:
    ; Clear screen
    mov ah, 0x06
    int 0x21

    mov al, 0x01
    call set_background_color
    
    ; Show welcome message
    mov ah, 0x01
    mov si, setup_welcome_msg
    int 0x21

    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov dh, 28
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_bottom_msg
    int 0x21

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg1
    int 0x21

    ; Wait for key press
    mov ah, 0
    int 16h

    ; ========== USERNAME SETUP ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg2
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Prompt for username
    mov ah, 0x01
    mov si, setup_username_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get username input
    mov di, 43008  
    mov byte [di], 0           
    mov ax, di             
    call string_input_string  
    
    ; Check if input is empty
    mov si, 43008
    call string_string_length
    cmp ax, 0
    jne .copy_username
    
    ; Use default username if input is empty
    mov si, default_username
    jmp .save_username
    
.copy_username:
    mov si, 43008
    
.save_username:
    mov di, user 
    mov cx, 31  
    call string_string_copy 
    
    ; Save USER.CFG
    mov ah, 0x03
    mov si, user_cfg_file
    mov bx, user              
    mov cx, 32
    int 0x22

    ; ========== PASSWORD SETUP ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg3
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Prompt for password
    mov ah, 0x01
    mov si, setup_password_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get password input
    mov di, 43008  
    mov byte [di], 0           
    mov ax, di             
    call string_input_string  
    
    ; Check if input is empty
    mov si, 43008
    call string_string_length
    cmp ax, 0
    jne .copy_password
    
    ; Use default password if input is empty
    mov si, default_password
    jmp .save_password
    
.copy_password:
    mov si, 43008
    
.save_password:
    mov di, password 
    mov cx, 31  
    call string_string_copy 
    
    ; Encrypt the password
    mov si, password
    mov di, encrypted_pass
    mov cx, 31
    call encrypt_string
    
    ; Save PASSWORD.CFG with encrypted password
    mov ah, 0x03
    mov si, password_cfg_file
    mov bx, encrypted_pass              
    mov cx, 32
    int 0x22

    ; ========== TIMEZONE SETUP ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg4
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Prompt for timezone
    mov ah, 0x01
    mov si, setup_timezone_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get timezone input
    mov di, 43008  
    mov byte [di], 0           
    mov ax, di             
    call string_input_string  
    
    ; Check if input is empty
    mov si, 43008
    call string_string_length
    cmp ax, 0
    jne .copy_timezone
    
    ; Use default timezone if input is empty
    mov si, default_timezone
    jmp .save_timezone
    
.copy_timezone:
    mov si, 43008
    
.save_timezone:
    mov di, timezone 
    mov cx, 31  
    call string_string_copy 
    
    ; Save TIMEZONE.CFG
    mov ah, 0x03
    mov si, timezone_cfg_file
    mov bx, timezone              
    mov cx, 32
    int 0x22

    ; ========== THEME SETUP ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg7
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Show theme selection options
    mov ah, 0x01
    mov si, setup_theme_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get theme selection
    mov di, 43008
    mov byte [di], 0
    mov ax, di
    call string_input_string
    
    ; Convert input to number
    mov si, 43008
    call string_to_int
    cmp ax, 0
    je .theme_default
    cmp ax, 2
    je .theme_ubuntu
    cmp ax, 3
    je .theme_vga
    cmp ax, 4
    je .theme_ocean
    jmp .theme_default

.theme_default:
    mov si, theme_default_data
    mov cx, theme_default_size
    jmp .save_theme

.theme_ubuntu:
    mov si, theme_ubuntu_data
    mov cx, theme_ubuntu_size
    jmp .save_theme

.theme_vga:
    mov si, theme_vga_data
    mov cx, theme_vga_size
    jmp .save_theme

.theme_ocean:
    mov si, theme_ocean_data
    mov cx, theme_ocean_size
    jmp .save_theme

.save_theme:
    ; Copy theme data to buffer
    mov di, 43008
    push cx
    rep movsb
    pop cx
    
    ; Save THEME.CFG
    mov ah, 0x03
    mov si, theme_cfg_file
    mov bx, 43008
    int 0x22

    ; ========== PROMPT SETUP ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg6
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Show prompt selection options
    mov ah, 0x01
    mov si, setup_prompt_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get prompt selection
    mov di, 43008
    mov byte [di], 0
    mov ax, di
    call string_input_string
    
    ; Convert input to number
    mov si, 43008
    call string_to_int
    cmp ax, 0
    je .prompt_default
    cmp ax, 2
    je .prompt_fancy
    cmp ax, 3
    je .prompt_unix
    jmp .prompt_default

.prompt_default:
    mov si, prompt_option1
    jmp .save_prompt

.prompt_fancy:
    mov si, prompt_option2
    jmp .save_prompt

.prompt_unix:
    mov si, prompt_option3
    jmp .save_prompt

.save_prompt:
    mov di, 43008
    mov cx, 64
    call string_string_copy
    mov ah, 0x03
    mov si, prompt_cfg_file
    mov bx, 43008
    mov cx, 64
    int 0x22

    ; ========== PROGRAM SELECTION ==========
    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg5
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor
    
    ; Show program options
    mov ah, 0x01
    mov si, setup_program_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor
    
    ; Get program selection
    mov di, 43008
    mov byte [di], 0
    mov ax, di
    call string_input_string
    
    ; Convert input to number
    mov si, 43008
    call string_to_int
    cmp ax, 0
    je .default_programs
    cmp ax, 2
    je .essential_programs
    cmp ax, 3
    je .minimal_programs

.default_programs:
    jmp .save_settings

.essential_programs:
    ; Remove non-essential programs
    mov ah, 0x06
    mov si, brainf_file
    int 0x22
    mov si, bchart_file
    int 0x22
    mov si, hello_file
    int 0x22
    mov si, mine_file
    int 0x22
    mov si, piano_file
    int 0x22
    mov si, procentc_file
    int 0x22
    mov si, space_file
    int 0x22
    mov si, hexedit_file
    int 0x22
    mov si, paint_file
    int 0x22
    mov si, pong_file
    int 0x22
    mov si, snake_file
    int 0x22
    jmp .save_settings

.minimal_programs:
    ; Remove all non-core programs
    mov ah, 0x06
    mov si, brainf_file
    int 0x22
    mov si, bchart_file
    int 0x22
    mov si, hello_file
    int 0x22
    mov si, mine_file
    int 0x22
    mov si, piano_file
    int 0x22
    mov si, procentc_file
    int 0x22
    mov si, space_file
    int 0x22
    mov si, calc_file
    int 0x22
    mov si, memory_file
    int 0x22
    mov si, writer_file
    int 0x22
    mov si, hexedit_file
    int 0x22
    mov si, paint_file
    int 0x22
    mov si, pong_file
    int 0x22
    mov si, snake_file
    int 0x22

.save_settings:
    ; Update FIRST_B.CFG to '0'
    mov ah, 0x03
    mov byte [43008], '0'
    mov si, first_boot_file
    mov bx, 43008             
    mov cx, 2  
    int 0x22

    mov dh, 28
    mov dl, 0
    call string_move_cursor
    
    ; Show completion message
    mov ah, 0x01
    mov si, setup_complete_msg
    int 0x21
    
    ; Wait for key press
    mov ah, 0
    int 16h
    
    mov ah, 0x06
    int 0x21

    ret

; ========== INCLUDES ==========
%INCLUDE "src/kernel/features/encrypt.asm"  
%INCLUDE "programs/setup/setup_messages.asm"  
%INCLUDE "programs/setup/helper_functions.asm"

; ========== DATA SECTION ==========

user_cfg_file        db 'USER.CFG', 0
password_cfg_file    db 'PASSWORD.CFG', 0
timezone_cfg_file    db 'TIMEZONE.CFG', 0
first_boot_file      db 'FIRST_B.CFG', 0
prompt_cfg_file      db 'PROMPT.CFG', 0
theme_cfg_file       db 'THEME.CFG', 0

default_username      db 'user', 0
default_password      db '', 0
default_timezone      db '0', 0  

; Prompt options
prompt_option1       db '[$username@PRos] > ', 0
prompt_option2       db '%DA%C4%C4 $username%0A%C0%C4 %FE %10 ', 0
prompt_option3       db '$username@pros:~$ ', 0

; Theme data - Default 
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

; Theme data - Ubuntu
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

; Theme data - VGA Default
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

; Theme data - Ocean Deep 
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

; Program file names
brainf_file    db 'BRAINF.BIN', 0
bchart_file    db 'BCHART.BIN', 0
hello_file     db 'HELLO.BIN', 0
mine_file      db 'MINE.BIN', 0
piano_file     db 'PIANO.BIN', 0
procentc_file  db 'PROCENTC.BIN', 0
space_file     db 'SPACE.BIN', 0
calc_file      db 'CALC.BIN', 0
memory_file    db 'MEMORY.BIN', 0
writer_file    db 'WRITER.BIN', 0
hexedit_file   db 'HEXEDIT.BIN', 0
paint_file     db 'PAINT.BIN', 0
pong_file      db 'PONG.BIN', 0
snake_file     db 'SNAKE.BIN', 0

user           times 32 db 0
password       times 32 db 0
timezone       times 32 db 0
encrypted_pass times 32 db 0