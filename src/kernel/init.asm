init_system:
    xor ax, ax
    mov es, ax
    mov word [es:0x80], int20_handler
    mov word [es:0x82], cs

    sti
    cld

    call init_segments
    call init_timer
    call init_api
    call init_configs
    call init_display
    call init_security
    call init_autoexec
    ret

init_segments:
    mov ax, 2000h
    mov ds, ax
    mov es, ax

    mov si, segment_init_msg
    call log_okay

    ret

init_timer:
    mov al, 0xB6
    out 0x43, al
    mov ax, 700
    out 0x42, al
    mov al, ah
    out 0x42, al

    mov si, timer_init_msg
    call log_okay

    ret

init_api:
    mov si, api_init_msg
    call log_okay

    call api_output_init

    mov si, api_output_init_msg
    call log_okay

    call api_fs_init

    mov si, api_fs_init_msg
    call log_okay
    ret

init_configs:
    call load_system_cfg

    mov si, config_init_msg
    call log_okay

    ret

init_display:
    mov si, display_init_msg
    call log_okay

    call InitMouse

    mov si, mouse_init_msg
    call log_okay

    call load_logo_and_display
    call set_video_mode
    ret

init_security:
    call check_first_boot
    call handle_password_check

    mov si, security_init_msg
    call log_okay

    ret

init_autoexec:
    mov si, shell_init_msg
    call log_okay

    call EnableMouse
    call string_clear_screen
    call print_interface
    call play_startup_sound
    call execute_autoexec_if_exists

    ret

check_first_boot:
    call load_first_boot_cfg
    mov al, [32768]
    cmp al, '1'
    je .first_boot
    call load_user_from_config
    call load_prompt_from_config
    ret

.first_boot:
    mov si, first_boot_detected_msg
    call log_warn

    call run_setup_wizard
    call load_user_from_config
    call load_prompt_from_config
    ret

run_setup_wizard:
    mov si, setup_exec_load_msg

    call load_setup_bin
    jc .setup_failed

    call log_okay

    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0
    call 32768
    ret

.setup_failed:
    call log_error
    ret

load_user_from_config:
    mov si, user_cfg_load_msg

    call load_user_cfg
    jc .use_default

    call log_okay

    mov si, 32768
    mov di, user
    mov cx, bx
    cmp cx, 31
    jbe .copy
    mov cx, 31
.copy:
    rep movsb
    mov byte [di], 0
    ret

.use_default:
    call log_warn
    ret

load_prompt_from_config:
    mov si, prompt_cfg_load_msg

    call load_prompt_cfg
    jc .use_default_prompt

    call log_okay

    cmp bx, 63
    jbe .copy
    mov bx, 63
.copy:
    mov si, 32768
    mov di, temp_prompt
    mov cx, bx
    rep movsb
    mov byte [di], 0

    mov si, temp_prompt
    mov di, final_prompt
    call parse_prompt
    ret

.use_default_prompt:
    call log_warn
    call build_default_prompt
    ret

build_default_prompt:
    mov di, final_prompt
    mov al, '['
    stosb
    mov si, user
.copy_user:
    lodsb
    cmp al, 0
    je .done
    stosb
    jmp .copy_user
.done:
    mov si, .suffix
.copy_suffix:
    lodsb
    stosb
    cmp al, 0
    jne .copy_suffix
    ret
.suffix db '@PRos] > ', 0

handle_password_check:
    mov si, password_cfg_load_msg

    call load_password_cfg
    jc .no_password

    call log_okay
    call decrypt_and_verify_password
    ret

.no_password:
    call log_warn
    ret

decrypt_and_verify_password:
    mov si, 32768
    mov di, decrypted_pass
    mov cx, bx
    call decrypt_string

    cmp byte [decrypted_pass], 0
    je .no_password_set
    cmp bx, 0
    je .no_password_set

    mov si, password_check_msg
    call log_okay

    call prompt_for_password
    ret

.no_password_set:
    ret

prompt_for_password:
    call string_clear_screen
.loop:
    call display_password_prompt
    call get_password_input
    call verify_password
    jc .loop

    call string_clear_screen

    mov si, password_correct_msg
    call log_okay
    ret

display_password_prompt:
    mov dh, 12
    mov dl, 0
    call string_move_cursor
    mov si, login_password_prompt
    call print_string

    mov dh, 14
    mov dl, 24
    call string_move_cursor
    ret

get_password_input:
    mov di, .password_buffer
    mov al, 0
    mov cx, 32
    rep stosb

    mov ax, .password_buffer
    call string_input_string
    ret
.password_buffer times 32 db 0

verify_password:
    mov si, get_password_input.password_buffer
    mov di, decrypted_pass
    call string_string_compare
    jc .correct

    call show_wrong_password
    stc
    ret

.correct:
    clc
    ret

show_wrong_password:
    mov dh, 28
    mov dl, 27
    call string_move_cursor
    mov si, .msg
    call print_string_red

    mov ah, 0
    int 16h

    mov dh, 28
    mov dl, 27
    call string_move_cursor
    mov si, .clear
    call print_string_red
    ret
.msg   db 'Wrong password! Try again.', 13, 10, 0
.clear db 80 dup(' '), 0

play_startup_sound:
    cmp byte [cfg_sound_enabled], 1
    jne .skip

    mov si, sound_play_msg
    call log_okay

    mov si, start_melody
    call play_melody
    ret

.skip:
    mov si, sound_disabled_msg
    call log_warn
    ret

execute_autoexec_if_exists:
    mov ax, autoexec_file
    call fs_file_exists
    jc .skip

    mov si, autoexec_found_msg
    call log_okay

    call print_newline

    mov ax, autoexec_file
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jc .skip

    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call DisableMouse
    call 32768
    call EnableMouse
    ret

.skip:
    mov si, autoexec_not_found_msg
    call log_warn
    ret


; Load SYSTEM.CFG
load_system_cfg:
    pusha

    mov byte [cfg_sound_enabled], 1
    mov byte [cfg_logo_stretch], 0

    mov si, default_logo_file
    mov di, current_logo_file
    call string_string_copy

    mov ax, system_cfg_file
    mov cx, 32768
    call fs_load_file
    jc .done

    mov si, 32768
    mov cx, bx
    call parse_system_cfg_data

.done:
    popa
    ret

parse_system_cfg_data:
    pusha

.scan_loop:
    cmp cx, 0
    jle .finish_parse

    lodsb
    dec cx
    cmp al, ' '
    je .scan_loop
    cmp al, 9
    je .scan_loop
    cmp al, 13
    je .scan_loop
    cmp al, 10
    je .scan_loop

    cmp al, '#'
    je .skip_comment_line

    dec si
    inc cx

    push si
    mov di, cfg_key_logo
    call .check_keyword
    jnc .found_logo
    pop si

    push si
    mov di, cfg_key_logo_stretch
    call .check_keyword
    jnc .found_logo_stretch
    pop si

    push si
    mov di, cfg_key_sound
    call .check_keyword
    jnc .found_sound
    pop si

    inc si
    dec cx
    jmp .scan_loop

.skip_comment_line:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, 10
    je .scan_loop
    cmp al, 13
    je .scan_loop
    jmp .skip_comment_line

.found_logo:
    pop si
    add si, 5
    sub cx, 5

.skip_logo_spaces:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, ' '
    je .skip_logo_spaces
    cmp al, 9
    je .skip_logo_spaces

    dec si
    inc cx

    push si
    push cx
    mov di, .false_str
    call .check_keyword
    pop cx
    pop si
    jnc .set_logo_false

    mov di, current_logo_file
.copy_logo_val:
    cmp cx, 0
    jle .logo_val_done
    lodsb
    dec cx
    cmp al, 13          ; CR
    je .logo_val_done
    cmp al, 10          ; LF
    je .logo_val_done
    cmp al, 0
    je .logo_val_done
    cmp al, '#'         ; Comment
    je .logo_val_done
    cmp al, ' '         ; Space
    je .check_logo_end
    cmp al, 9           ; Tab
    je .check_logo_end
    stosb
    jmp .copy_logo_val

.check_logo_end:
    cmp cx, 0
    jle .logo_val_done
    push si
    lodsb
    dec cx
    cmp al, '#'
    je .logo_val_done_pop
    cmp al, 13
    je .logo_val_done_pop
    cmp al, 10
    je .logo_val_done_pop
    pop si
    mov al, ' '
    stosb
    jmp .copy_logo_val

.logo_val_done_pop:
    pop si
.logo_val_done:
    mov byte [di], 0
    mov byte [cfg_logo_enabled], 1
    jmp .scan_loop

.set_logo_false:
    add si, 5
    sub cx, 5
    mov byte [cfg_logo_enabled], 0
.skip_logo_line:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, 10
    je .scan_loop
    cmp al, 13
    je .scan_loop
    jmp .skip_logo_line

.found_logo_stretch:
    pop si
    add si, 13
    sub cx, 13

.skip_stretch_spaces:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, ' '
    je .skip_stretch_spaces
    cmp al, 9
    je .skip_stretch_spaces

    dec si
    inc cx

    lodsb
    dec cx
    cmp al, 'F'
    je .set_stretch_false
    cmp al, 'f'
    je .set_stretch_false
    cmp al, 'T'
    je .set_stretch_true
    cmp al, 't'
    je .set_stretch_true

    mov byte [cfg_logo_stretch], 0
    jmp .skip_stretch_line

.set_stretch_false:
    mov byte [cfg_logo_stretch], 0
    jmp .skip_stretch_line

.set_stretch_true:
    mov byte [cfg_logo_stretch], 1

.skip_stretch_line:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, 10
    je .scan_loop
    cmp al, 13
    je .scan_loop
    jmp .skip_stretch_line

.found_sound:
    pop si
    add si, 12
    sub cx, 12

.skip_sound_spaces:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, ' '
    je .skip_sound_spaces
    cmp al, 9
    je .skip_sound_spaces

    dec si
    inc cx
    lodsb
    dec cx
    cmp al, 'F'
    je .set_sound_false
    cmp al, 'f'
    je .set_sound_false
    cmp al, 'T'
    je .set_sound_true
    cmp al, 't'
    je .set_sound_true

    mov byte [cfg_sound_enabled], 1
    jmp .skip_sound_line

.set_sound_false:
    mov byte [cfg_sound_enabled], 0
    jmp .skip_sound_line

.set_sound_true:
    mov byte [cfg_sound_enabled], 1

.skip_sound_line:
    cmp cx, 0
    jle .finish_parse
    lodsb
    dec cx
    cmp al, 10
    je .scan_loop
    cmp al, 13
    je .scan_loop
    jmp .skip_sound_line

.finish_parse:
    popa
    ret

.check_keyword:
    push si
    push di
.kw_loop:
    mov al, [di]
    cmp al, 0
    je .kw_match
    mov ah, [si]
    cmp ah, al
    jne .kw_fail
    inc si
    inc di
    jmp .kw_loop
.kw_match:
    pop di
    pop si
    clc
    ret
.kw_fail:
    pop di
    pop si
    stc
    ret

.false_str db 'FALSE', 0

; Load and display Logo
load_logo_and_display:
    pusha

    cmp byte [cfg_logo_enabled], 0
    je .done

    mov si, current_logo_file
    mov di, si
    xor cx, cx

.find_slash:
    lodsb
    inc cx
    cmp al, 0
    je .no_path
    cmp al, '/'
    je .path_found
    jmp .find_slash

.path_found:
    mov si, current_logo_file
    mov di, .temp_dir_path
    dec cx

.copy_dir_loop:
    lodsb
    stosb
    dec cx
    jnz .copy_dir_loop

    mov al, '.'
    stosb
    mov al, 'D'
    stosb
    mov al, 'I'
    stosb
    mov al, 'R'
    stosb
    mov byte [di], 0

    inc si

    push si
    mov di, .temp_file_name
.copy_file_loop:
    lodsb
    stosb
    cmp al, 0
    jne .copy_file_loop

    mov ax, .temp_dir_path
    call fs_change_directory
    jc .error_loading

    pop ax
    mov cx, 32768
    call fs_load_file

    pushf
    call fs_parent_directory
    popf

    jnc .display_logo
    jmp .error_loading

.no_path:
    mov ax, current_logo_file
    mov cx, 32768
    call fs_load_file
    jnc .display_logo

.error_loading:
    mov si, logo_missed
    call log_error
    jmp .done

.display_logo:
    mov ax, 0x13
    int 0x10
    push bx
    mov si, 32768
    cmp byte [cfg_logo_stretch], 1
    je .display_stretched
    call display_bmp
    jmp .wait_key

.display_stretched:
    call display_bmp_stretched

.wait_key:
    mov ah, 0
    int 16h
    mov byte [_palSet], 0
    pop bx

.done:
    popa
    ret

.temp_dir_path  times 20 db 0
.temp_file_name times 13 db 0

; Load FIRST_B.CFG
load_first_boot_cfg:
    pusha

    mov ax, conf_dir_name
    call fs_change_directory
    jc .fresh_install

    mov ax, first_boot_file
    mov cx, 32768
    call fs_load_file
    jc .file_missing

    call fs_parent_directory
    popa
    ret

.file_missing:
    call fs_parent_directory

.fresh_install:
    mov byte [32768], '1'
    mov byte [32769], 0
    popa
    ret

; Load SETUP.BIN
load_setup_bin:
    pusha
    mov ax, setup_bin_file
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jnc .done
    mov si, error_message
    call print_string_red
    mov si, setup_failed_msg
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h
    stc

.done:
    popa
    ret

; Load USER.CFG
load_user_cfg:
    pusha

    mov ax, conf_dir_name
    call fs_change_directory
    jc .fail_load

    mov ax, user_cfg_file
    mov cx, 32768
    call fs_load_file

    pushf
    push bx

    call fs_parent_directory

    pop bx
    popf

    jnc .done

.fail_load:
    mov si, user_cfg_missed
    call log_error
    stc

.done:
    popa
    ret

; Load PROMPT.CFG
load_prompt_cfg:
    pusha
    mov ax, conf_dir_name
    call fs_change_directory
    jc .fail

    mov ax, prompt_cfg_file
    mov cx, 32768
    call fs_load_file

    pushf
    call fs_parent_directory
    popf
    jc .fail
    popa
    clc
    ret
.fail:
    mov si, prompt_cfg_missed
    call log_error
    popa
    stc
    ret

; Load PASSWORD.CFG
load_password_cfg:
    pusha
    mov ax, conf_dir_name
    call fs_change_directory
    jc .fail

    mov ax, password_cfg_file
    mov cx, 32768
    call fs_load_file

    pushf
    call fs_parent_directory
    popf
    jc .fail
    popa
    clc
    ret
.fail:
    mov si, pass_cfg_missed
    call log_error
    popa
    stc
    ret

; Initialization messages
segment_init_msg         db 'Segment initialization', 0
timer_init_msg           db 'Timer initialization', 0
api_init_msg             db 'API initialization', 0
api_output_init_msg      db 'Output API (INT 0x21)', 0
api_fs_init_msg          db 'File System API (INT 0x22)', 0
config_init_msg          db 'Configuration loading', 0
display_init_msg         db 'Display initialization', 0
mouse_init_msg           db 'Mouse driver loaded', 0
security_init_msg        db 'Security check', 0
shell_init_msg           db 'Shell initialization', 0

; Boot process messages
first_boot_detected_msg  db 'First boot detected', 0
setup_exec_load_msg      db 'Loading SETUP.BIN', 0
user_cfg_load_msg        db 'Loading USER.CFG', 0
password_cfg_load_msg    db 'Loading PASSWORD.CFG', 0
prompt_cfg_load_msg      db 'Loading PROMPT.CFG', 0
password_check_msg       db 'Password protection enabled', 0
password_correct_msg     db 'Password verified', 0
sound_play_msg           db 'Playing startup sound', 0
sound_disabled_msg       db 'Startup sound disabled', 0
autoexec_found_msg       db 'Executing AUTOEXEC.BIN', 0
autoexec_not_found_msg   db 'AUTOEXEC.BIN not found', 0

; Error messages 
setup_failed_msg         db 'Failed to load SETUP.BIN', 0
user_cfg_missed          db 'USER.CFG not found', 0
pass_cfg_missed          db 'PASSWORD.CFG not found', 0
prompt_cfg_missed        db 'PROMPT.CFG not found', 0
logo_missed              db 'LOGO.BMP not found', 0