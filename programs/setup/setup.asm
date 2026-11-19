; ==================================================================
; x16-PRos -- SETUP. First-boot configuration wizard for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Walks the user through the initial system configuration: chooses
; an install target disk (and clones the system to it if requested),
; then collects username, password, timezone, color theme, command
; prompt style and the bundled programs package.
;
; Files created:
;   CONF.DIR/USER.CFG      -- plain username
;   CONF.DIR/PASSWORD.CFG  -- encrypted password
;   CONF.DIR/TIMEZONE.CFG  -- UTC offset string
;   CONF.DIR/THEME.CFG     -- selected color theme palette
;   CONF.DIR/PROMPT.CFG    -- selected command prompt template
;   CONF.DIR/FIRST_B.CFG   -- '0' marker meaning setup has completed
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

%define SETUP_STAGE_WELCOME   0
%define SETUP_STAGE_USERNAME  1
%define SETUP_STAGE_PASSWORD  2
%define SETUP_STAGE_TIMEZONE  3
%define SETUP_STAGE_THEME     4
%define SETUP_STAGE_PROMPT    5
%define SETUP_STAGE_PROGRAMS  6
%define SETUP_STAGE_END       7

; Max chars accepted in any setup field. The *.CFG field buffers are 32
; bytes (31 chars + null), so this also bounds the input visually.
%define SETUP_FIELD_MAX       31

; ========== SETUP ROUTINE ==========
setup:
%ifndef NO_SETUP
    ; Clear screen
    mov ah, 0x06
    int 0x21

    mov al, 0x01
    call set_background_color

    call draw_top_and_bottom_lines

    mov al, SETUP_STAGE_WELCOME
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg1
    int 0x21

    ; Wait for key press
    mov ah, 0
    int 16h

    ; ========== DISK INSTALL ==========
    call install_run

    mov ah, 0x06
    int 0x21
    mov al, 0x01
    call set_background_color

    call draw_top_and_bottom_lines

    ; ========== USERNAME SETUP ==========
    mov al, SETUP_STAGE_USERNAME
    call setup_draw_stage_ui

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
    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov byte [setup_input_buf + 31], 0

    ; Check length
    mov si, setup_input_buf
    call string_string_length
    cmp ax, 0
    je .skip_copy_user

    ; Copy input to 'user' variable
    mov si, setup_input_buf
    mov di, user
    mov cx, 31
    call string_string_copy

.skip_copy_user:
    ; --- SAVE USER.CFG in CONF.DIR ---
    ; 1. Create directory (ignore error if exists)
    mov ah, 0x0B
    mov si, conf_dir_name
    int 0x22

    ; 2. Enter directory
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    ; 3. Save file
    mov ah, 0x03
    mov si, user_cfg_file
    mov bx, user
    mov cx, 32
    int 0x22

    ; 4. Exit directory
    mov ah, 0x0A
    int 0x22

    ; ========== PASSWORD SETUP ==========
    mov al, SETUP_STAGE_PASSWORD
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg3
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_password_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor

    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov byte [setup_input_buf + 31], 0

    mov si, setup_input_buf
    call string_string_length
    cmp ax, 0
    je .encrypt_pass ; use default empty pass

    mov si, setup_input_buf
    mov di, password
    mov cx, 31
    call string_string_copy

.encrypt_pass:
    mov si, password
    mov di, encrypted_pass
    mov cx, 31
    call encrypt_string

    ; --- SAVE PASSWORD.CFG in CONF.DIR ---
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x03
    mov si, password_cfg_file
    mov bx, encrypted_pass
    mov cx, 32
    int 0x22

    mov ah, 0x0A
    int 0x22

    ; ========== TIMEZONE SETUP ==========
    mov al, SETUP_STAGE_TIMEZONE
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg4
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_timezone_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor

    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov byte [setup_input_buf + 31], 0

    mov si, setup_input_buf
    call string_string_length
    cmp ax, 0
    je .save_timezone

    mov si, setup_input_buf
    mov di, timezone
    mov cx, 31
    call string_string_copy

.save_timezone:
    ; --- SAVE TIMEZONE.CFG in CONF.DIR ---
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x03
    mov si, timezone_cfg_file
    mov bx, timezone
    mov cx, 32
    int 0x22

    mov ah, 0x0A
    int 0x22

    ; ========== THEME SETUP ==========
    mov al, SETUP_STAGE_THEME
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg7
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_theme_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor

    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov si, setup_input_buf
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
    ; Copy to buffer
    mov di, setup_input_buf
    push cx
    rep movsb
    pop cx

    ; --- SAVE THEME.CFG in CONF.DIR ---
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x03
    mov si, theme_cfg_file
    mov bx, setup_input_buf
    int 0x22

    mov ah, 0x0A
    int 0x22

    ; ========== PROMPT SETUP ==========
    mov al, SETUP_STAGE_PROMPT
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg6
    int 0x21

    mov dh, 17
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_prompt_prompt
    int 0x21

    mov dh, 19
    mov dl, 5
    call string_move_cursor

    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov si, setup_input_buf
    call string_to_int

    cmp ax, 0
    je .prompt_default
    cmp ax, 2
    je .prompt_fancy
    cmp ax, 3
    je .prompt_unix
    cmp ax, 4
    je .prompt_cpp
    cmp ax, 5
    je .prompt_vmini
    cmp ax, 6
    je .prompt_mini
    cmp ax, 7
    je .prompt_dos
    cmp ax, 8
    je .prompt_debian

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

.prompt_cpp:
    mov si, prompt_option4
    jmp .save_prompt

.prompt_vmini:
    mov si, prompt_option5
    jmp .save_prompt

.prompt_mini:
    mov si, prompt_option6
    jmp .save_prompt

.prompt_dos:
    mov si, prompt_option7
    jmp .save_prompt

.prompt_debian:
    mov si, prompt_option8
    jmp .save_prompt

.save_prompt:
    mov di, setup_input_buf
    xor al, al
    mov cx, 64
    rep stosb

    mov di, setup_input_buf
    call string_string_copy

    mov ax, setup_input_buf
    call string_string_length
    inc ax
    mov cx, ax

    ; --- SAVE PROMPT.CFG in CONF.DIR ---
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x03
    mov si, prompt_cfg_file
    mov bx, setup_input_buf
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg_clear
    int 0x21

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    ; ========== PROGRAM SELECTION ==========
    mov al, SETUP_STAGE_PROGRAMS
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_help_msg5
    int 0x21

    mov dh, 12
    mov dl, 0
    call string_move_cursor

    mov ah, 0x01
    mov si, setup_program_prompt
    int 0x21

    mov dh, 14
    mov dl, 5
    call string_move_cursor

    mov di, setup_input_buf
    mov byte [di], 0
    mov ax, di
    mov cx, SETUP_FIELD_MAX
    call string_input_string

    mov si, setup_input_buf
    call string_to_int
    cmp ax, 2
    je .essential_programs
    cmp ax, 3
    je .minimal_programs
    jmp .save_settings

.essential_programs:
    mov ah, 0x09
    mov si, bin_dir_name
    int 0x22

    mov si, essential_remove_list
    call remove_file_list
    jmp .leave_bin_dir

.minimal_programs:
    mov ah, 0x09
    mov si, bin_dir_name
    int 0x22

    mov si, essential_remove_list
    call remove_file_list
    mov si, minimal_remove_list
    call remove_file_list

.leave_bin_dir:
    mov ah, 0x0A
    int 0x22

.save_settings:
    mov al, SETUP_STAGE_END
    call setup_draw_stage_ui

    ; --- UPDATE FIRST_B.CFG in CONF.DIR ---
    ; This marks setup as complete ('0')
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x03
    mov byte [setup_input_buf], '0'
    mov byte [setup_input_buf + 1], 0
    mov si, first_boot_file
    mov bx, setup_input_buf
    mov cx, 2
    int 0x22

    mov ah, 0x0A
    int 0x22

    ;mov ah, 0x06
    ;int 0x21

    ;mov al, 0x01
    ;call set_background_color

    ;call draw_top_and_bottom_lines

    mov al, SETUP_STAGE_END
    call setup_draw_stage_ui

    mov dh, 3
    mov dl, 0
    call string_move_cursor
    mov ah, 0x01
    mov si, setup_help_msg8
    int 0x21

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

remove_file_list:
    push ax
    push si
    cld
.next:
    cmp byte [si], 0
    je .done
    mov ah, 0x06
    int 0x22
.skip:
    lodsb
    test al, al
    jnz .skip
    jmp .next
.done:
    pop si
    pop ax
    ret

setup_draw_stage_ui:
    pusha
    mov [setup_stage_current], al
    call setup_draw_stage_bar
    popa
    ret

setup_draw_stage_bar:
    pusha

    mov dh, 24
    mov dl, 1
    call string_move_cursor
    mov ah, 0x01
    mov si, setup_stagebar_top
    int 0x21

    mov al, [setup_stage_current]
    cmp al, SETUP_STAGE_WELCOME
    je .bar_welcome
    cmp al, SETUP_STAGE_USERNAME
    je .bar_username
    cmp al, SETUP_STAGE_PASSWORD
    je .bar_password
    cmp al, SETUP_STAGE_TIMEZONE
    je .bar_timezone
    cmp al, SETUP_STAGE_THEME
    je .bar_theme
    cmp al, SETUP_STAGE_PROMPT
    je .bar_prompt
    cmp al, SETUP_STAGE_PROGRAMS
    je .bar_programs
    mov si, setup_stagebar_end
    jmp .draw_bar_mid

.bar_welcome:
    mov si, setup_stagebar_welcome
    jmp .draw_bar_mid
.bar_username:
    mov si, setup_stagebar_username
    jmp .draw_bar_mid
.bar_password:
    mov si, setup_stagebar_password
    jmp .draw_bar_mid
.bar_timezone:
    mov si, setup_stagebar_timezone
    jmp .draw_bar_mid
.bar_theme:
    mov si, setup_stagebar_theme
    jmp .draw_bar_mid
.bar_prompt:
    mov si, setup_stagebar_prompt
    jmp .draw_bar_mid
.bar_programs:
    mov si, setup_stagebar_programs

.draw_bar_mid:
    mov dh, 25
    mov dl, 1
    call string_move_cursor
    mov ah, 0x07
    mov bl, 0x0F
    int 0x21
    mov ah, 0x08
    int 0x21

    mov dh, 26
    mov dl, 1
    call string_move_cursor
    mov ah, 0x01
    mov si, setup_stagebar_bottom
    int 0x21

    popa
%endif
    ret

draw_top_and_bottom_lines:
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

    ret

; ========== INCLUDES ==========
%INCLUDE "src/kernel/features/encrypt.asm"
%INCLUDE "programs/setup/setup_messages.asm"
%INCLUDE "programs/setup/helper_functions.asm"
%INCLUDE "programs/setup/install.asm"

; ========== DATA SECTION ==========

user_cfg_file        db 'USER.CFG', 0
conf_dir_name        db 'CONF.DIR', 0
bin_dir_name         db 'BIN.DIR', 0
password_cfg_file    db 'PASSWORD.CFG', 0
timezone_cfg_file    db 'TIMEZONE.CFG', 0
first_boot_file      db 'FIRST_B.CFG', 0
prompt_cfg_file      db 'PROMPT.CFG', 0
theme_cfg_file       db 'THEME.CFG', 0

; Pre-filled defaults
user                 db 'user', 0
                     times 27 db 0
password             times 32 db 0
timezone             db '0', 0
                     times 30 db 0
encrypted_pass       times 32 db 0

; Prompt options
prompt_option1    db '[$username@PRos] > ', 0
prompt_option2    db '%DA%C4%C4 $username%0A%C0%C4 %FE %10 ', 0
prompt_option3    db '$username@pros:~$ ', 0
prompt_option4    db 'pros::$username; ', 0
prompt_option5    db '%-', 0
prompt_option6    db '$username> ', 0
prompt_option7    db 'PRos\\> ', 0
prompt_option8    db '$username@host:/$ ', 0

; Theme data - Default
theme_default_data:
    db '0,2,3,5', 10
    db '1,25,24,52', 10
    db '2,21,37,10', 10
    db '3,18,26,40', 10
    db '4,46,9,12', 10
    db '5,27,28,48', 10
    db '6,10,40,38', 10
    db '7,63,56,50', 10
    db '8,3,14,17', 10
    db '9,50,19,5', 10
    db '10,33,53,22', 10
    db '11,16,53,56', 10
    db '12,53,17,20', 10
    db '13,32,37,37', 10
    db '14,56,55,27', 10
    db '15,63,63,63', 0
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

; Program removal tables for Essential [2] and Minimal [3] modes
essential_remove_list:
    db 'BCHART.BIN', 0, 'BRAINF.BIN', 0, 'CHARS.BIN', 0, 'CREDITS.BIN', 0
    db 'EYE.BIN', 0, 'HELLO.BIN', 0, 'IMFPLAY.BIN', 0, 'MANDEL.BIN', 0
    db 'MINE.BIN', 0, 'PAINT.BIN', 0, 'PIANO.BIN', 0, 'PONG.BIN', 0
    db 'PROCENTC.BIN', 0, 'SNAKE.BIN', 0, 'SPACE.BIN', 0, 'TETRIS.BIN', 0
    db 'TETRIS2.BIN', 0, 'WAVPLAY.BIN', 0
    db 0

minimal_remove_list:
    db 'CALC.BIN', 0, 'CALENDAR.BIN', 0, 'CLOCK.BIN', 0, 'CPU.BIN', 0
    db 'DLIST.BIN', 0, 'ED.BIN', 0, 'FDISK.BIN', 0, 'FETCH.BIN', 0
    db 'FONT.BIN', 0, 'GREP.BIN', 0, 'HEAD.BIN', 0, 'HELP.BIN', 0
    db 'HEXEDIT.BIN', 0, 'KILL.BIN', 0, 'LAUNCH.BIN', 0, 'MEMORY.BIN', 0
    db 'PRASM.BIN', 0, 'PRINT.BIN', 0, 'PS.BIN', 0, 'SETTINGS.BIN', 0
    db 'TAIL.BIN', 0, 'THEME.BIN', 0, 'TREE.BIN', 0, 'WRITER.BIN', 0
    db 0

setup_stage_current db 0
setup_input_buf     times 256 db 0