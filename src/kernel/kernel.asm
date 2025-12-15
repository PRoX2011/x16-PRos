; ==================================================================
; x16-PRos -- The x16-PRos Operating System kernel
; Copyright (C) 2025 PRoX2011
;
; This is loaded from disk by BOOT.BIN as KERNEL.BIN
; ==================================================================

[BITS 16]
[ORG 0x0000]


disk_buffer equ   24576

section .text

start:
    cli 
    ; ------ Stack installation ------
    mov ax, 0
    mov ss, ax
    mov sp, 0x0FFFF

    sti

    cld

    call set_video_mode  ; Setting up video mode

    call InitMouse       ; Mouse initialization

    mov ax, 2000h
    mov ds, ax
    mov es, ax
    ;mov fs, ax
    ;mov gs, ax

    ; Set up frequency (1193180 Hz / 1193 = ~1000 Hz)
    mov al, 0xB6
    out 0x43, al
    mov ax, 700
    out 0x42, al
    mov al, ah
    out 0x42, al

    ; PRoX kernel API initialization
    call api_output_init    ; Output API (INT 21H)
    call api_fs_init        ; File system API (INT 22h)
    call api_string_init    ; String API (INT 23h)

    ; Display PRoX OS logo if available
    call load_logo_and_display

    call set_video_mode

    ; Load and check FIRST_B.CFG
    call load_first_boot_cfg
    mov al, [32768]
    cmp al, '1'
    je .first_boot
    jmp .normal_boot

.first_boot:
    ; Load and execute SETUP.BIN
    call load_setup_bin
    jc .setup_failed            ; Jump if file loading fails
    ; Prepare to execute SETUP.BIN
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]   ; Parameter list
    mov di, 0
    call 32768                  ; Execute SETUP.BIN

    ; Load USER.CFG into "user" if exists
    call load_user_cfg
    jnc .load_user_after_setup
    jmp .load_prompt
.load_user_after_setup:
    mov si, 32768
    mov di, user
    mov cx, bx
    cmp cx, 31
    jbe .copy_user_after_setup
    mov cx, 31
.copy_user_after_setup:
    rep movsb
    mov byte [di], 0
    jmp .load_prompt

.setup_failed:
    ; Handle failure to load SETUP.BIN (already handled in load_setup_bin)
    jmp .load_prompt

.normal_boot:
    ; Load USER.CFG into "user" if exists
    call load_user_cfg
    jnc .load_user_success
    jmp .load_prompt
.load_user_success:
    mov si, 32768
    mov di, user
    mov cx, bx
    cmp cx, 31
    jbe .copy_user
    mov cx, 31
.copy_user:
    rep movsb
    mov byte [di], 0

.load_prompt:
    ; Load PROMPT.CFG if exists
    call load_prompt_cfg
    jnc .load_prompt_success
    jmp .set_default_prompt

.load_prompt_success:
    cmp bx, 63
    jbe .copy_prompt
    mov bx, 63
.copy_prompt:
    mov si, 32768
    mov di, temp_prompt
    mov cx, bx
    rep movsb
    mov byte [di], 0

    mov si, temp_prompt
    mov di, final_prompt
    call parse_prompt
    jmp .prompt_done

.set_default_prompt:
    mov di, final_prompt
    mov al, '['
    stosb
    mov si, user
.default_user_copy:
    lodsb
    cmp al, 0
    je .default_user_done
    stosb
    jmp .default_user_copy
.default_user_done:
    mov si, .default_suffix
.default_suffix_copy:
    lodsb
    stosb
    cmp al, 0
    jne .default_suffix_copy
    jmp .prompt_done

.prompt_done:
    ; Password check
    call load_password_cfg
    jnc .password_check
    jmp .password_ok 

.password_check:
    ; Decrypt the loaded password
    mov si, 32768              ; Encrypted password from file
    mov di, decrypted_pass     ; Buffer for decrypted password
    mov cx, bx                 ; Length from file load
    call decrypt_string

    ; Check if password is empty (first byte is 0 after decrypt)
    cmp byte [decrypted_pass], 0
    je .password_ok
    cmp bx, 0
    je .password_ok

.password_prompt:
    mov dh, 12
    mov dl, 0
    call string_move_cursor

    mov si, login_password_prompt
    call print_string

    mov dh, 14
    mov dl, 24
    call string_move_cursor

    mov di, .password_input
    mov al, 0
    mov cx, 32
    rep stosb

    mov ax, .password_input
    call string_input_string

    ; Compare input (plaintext) with decrypted password
    mov si, .password_input
    mov di, decrypted_pass
    call string_string_compare
    jc .password_ok

    ; Wrong password
    mov dh, 28
    mov dl, 27
    call string_move_cursor

    mov si, .wrong_password_msg
    call print_string_red

    ; Wait for key press
    mov ah, 0
    int 16h

    mov dh, 28
    mov dl, 27
    call string_move_cursor

    mov si, .clear_row
    call print_string_red

    jmp .password_prompt

.password_ok:
    call EnableMouse        ; Turn on mouse
    call string_clear_screen

    call print_interface    ; Help menu and header
    mov si, start_melody
    call play_melody        ; Startup melody

    ; Check for AUTOEXEC.BIN
    mov ax, autoexec_file
    call fs_file_exists
    jnc .execute_autoexec   ; File exists, execute it
    jmp .skip_autoexec      ; File doesn't exist, skip to normal boot

.execute_autoexec:
    mov ax, autoexec_file
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jc .skip_autoexec       ; If loading fails, skip to normal boot

    ; Execute AUTOEXEC.BIN
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call DisableMouse
    call 32768              ; Execute the loaded binary
    call EnableMouse

.skip_autoexec:
    ; Load and aply theme from THEME.CFG file
    call load_and_apply_theme

    call shell              ; PRos terminal
    jmp $

.wrong_password_msg db 'Wrong password! Try again.', 13, 10, 0
.clear_row          db 80 dup(' '), 0
.password_input     times 32 db 0
.default_suffix     db '@PRos] > ', 0

; Load and display LOGO.BMP
load_logo_and_display:
    pusha
    mov ax, pros_logo_file
    mov cx, 32768
    call fs_load_file
    jnc .display_logo
    mov si, error_message
    call print_string_red
    mov si, logo_missed
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h
    jmp .done

.display_logo:
    mov ax, 0x13
    int 0x10
    push bx
    mov si, 32768 
    call display_bmp
    mov ah, 0
    int 16h
    mov byte [_palSet], 0
    pop bx  

.done:
    popa
    ret

; Load FIRST_B.CFG (create if not exists)
load_first_boot_cfg:
    pusha
    mov ax, first_boot_file
    mov cx, 32768
    call fs_load_file
    jnc .done
    mov si, error_message
    call print_string_red
    mov si, boot_cfg_missed
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h

    mov si, first_boot_value
    mov di, 32768
    mov cx, 2
    rep movsb
    mov ax, first_boot_file
    mov bx, 32768
    mov cx, 2
    call fs_write_file

.done:
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
    mov ax, user_cfg_file
    mov cx, 32768
    call fs_load_file
    jnc .done
    mov si, error_message
    call print_string_red
    mov si, user_cfg_missed
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h
    stc  

.done:
    popa
    ret

; Load PROMPT.CFG
load_prompt_cfg:
    pusha
    mov ax, prompt_cfg_file
    mov cx, 32768
    call fs_load_file
    jnc .done
    mov si, error_message
    call print_string_red
    mov si, prompt_cfg_missed
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h
    stc  

.done:
    popa
    ret

; Load PASSWORD.CFG
load_password_cfg:
    pusha
    mov ax, password_cfg_file
    mov cx, 32768
    call fs_load_file
    jnc .done
    mov si, error_message
    call print_string_red
    mov si, pass_cfg_missed
    call print_string
    call print_newline
    ; Wait for key press
    mov ah, 0
    int 16h
    stc 

.done:
    popa
    ret

set_video_mode:
    ; VGA 640*480, 16 colors
    mov ax, 0x12
    int 0x10
    ret

; ===================== String Output Functions =====================

; -----------------------------
; Output a string to the screen
; IN  : SI = string location
; OUT : Nothing
print_string:
    mov ah, 0x0E
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0A          ; Check for newline (LF)
    je .handle_newline
    int 0x10              ; Print character
    jmp .print_char
.handle_newline:
    mov al, 0x0D          ; Output carriage return (CR)
    int 0x10
    mov al, 0x0A          ; Output line feed (LF)
    int 0x10
    jmp .print_char
.done:
    ret

; -----------------------------
; Prints empty line
; IN  : Nothing
; OUT : Nothing
print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ===================== Colored print functions =====================

; ------ Green ------
print_string_green:
    mov ah, 0x0E
    mov bl, 0x0A
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; ------ Cyan ------
print_string_cyan:
    mov ah, 0x0E
    mov bl, 0x0B
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; ------ Red ------
print_string_red:
    mov ah, 0x0E
    mov bl, 0x0C
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; ------ Yellow ------
print_string_yellow:
    mov ah, 0x0E
    mov bl, 0x0E
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

; -----------------------------
; Print decimal number
; IN  : AX = num location
print_decimal:
    mov cx, 0
    mov dx, 0
.setup:
    cmp ax, 0  
    je .check_0
    mov bx, 10          
    div bx             
    push dx   
    inc cx                 
    xor dx, dx            
    jmp .setup
.check_0:
    cmp cx, 0
    jne .print_number
    push dx
    inc cx
.print_number:
    mov ah, 0x0E              
.print_char:
    cmp cx, 0                
    je .return
    pop dx                    
    add dx, 48            
    mov al, dl
    int 0x10
    dec cx
    jmp .print_char
.return:
    ret

print_interface:
    mov si, header
    call print_string

    call print_newline
    call print_newline

    mov si, .pros
    call print_string

    call print_newline

    mov si, .copyright
    call print_string

    mov si, .shell
    call print_string
    
    mov si, version_msg
    call print_string

    call print_newline

    mov si, .tip
    call print_string_cyan

    call print_newline
    
    mov cx, 15         
    mov bl, 0           
.color_blocks:
    push cx            
    
    mov ah, 0x0E          
    mov al, 0xDB            
    int 0x10      
    
    inc bl             
    cmp bl, 15        
    jbe .next_block
    mov bl, 0          
    
.next_block:
    pop cx          
    loop .color_blocks
    
    call print_newline
    call print_newline

    ret

.pros       db '  _____  _____   ____   _____ ', 10, 13
            db ' |  __ \|  __ \ / __ \ / ____|', 10, 13
            db ' | |__) | |__) | |  | | (___  ', 10, 13
            db ' |  ___/|  _  /| |  | |\___ \ ', 10, 13
            db ' | |    | | \ \| |__| |____) |', 10, 13
            db ' |_|    |_|  \_\\____/|_____/ ', 10, 13, 0
.copyright  db '* Copyright (C) 2025 PRoX2011', 10, 13, 0
.shell      db '* Shell: ', 0
.tip        db 'Type HELP to get list of the comands', 10, 13, 0

print_help:
    call string_clear_screen
    call string_get_cursor_pos
    mov [.saved_row], dh
    mov [.saved_col], dl
    
    mov word [current_category], 0
    call .show_current_category

.key_loop:
    mov ah, 0    
    int 16h    
    ; Check for navigation keys
    cmp ah, 0x48    ; Up arrow
    je .prev_category
    cmp ah, 0x4B    ; Left arrow
    je .prev_category
    cmp ah, 0x50    ; Down arrow
    je .next_category
    cmp ah, 0x4D    ; Right arrow
    je .next_category
    cmp al, 27      ; ESC key
    je .exit_help
    
    jmp .key_loop   ; Ignore other keys

.prev_category:
    ; Can't go before first category
    cmp word [current_category], 0
    je .key_loop
    dec word [current_category]
    jmp .update_category

.next_category:
    mov si, help_categories
    mov bx, [current_category]
    shl bx, 1      
    add si, bx
    add si, 2      
    cmp word [si], 0
    je .key_loop  
    inc word [current_category]

.update_category:
    call .show_current_category
    jmp .key_loop

.show_current_category:
    mov dh, [.saved_row]
    mov dl, [.saved_col]
    call string_move_cursor

    mov dh, [.saved_row]
    mov dl, [.saved_col]
    call string_move_cursor
    
    mov si, help_categories
    mov bx, [current_category]
    shl bx, 1   
    add si, bx
    mov si, [si]   
    call print_string_green
    ret

.exit_help:
    mov dh, [.saved_row]
    add dh, 22     
    mov dl, 0
    call string_move_cursor
    jmp get_cmd  

.saved_row db 0
.saved_col db 0

print_info:
    mov si, info
    call print_string_green
    call print_newline
    jmp get_cmd

; ===================== Command Line Interpreter =====================

shell:
get_cmd:
    mov si, final_prompt 
    call print_string
    
    mov di, input
    mov al, 0
    mov cx, 256
    rep stosb

    mov di, command
    mov cx, 32
    rep stosb

    mov ax, input
    call string_input_string

    call print_newline

    mov ax, input
    call string_string_chomp

    mov si, input
    cmp byte [si], 0
    je get_cmd

    mov si, input
    mov al, ' '
    call string_string_tokenize

    mov word [param_list], di

    mov si, input
    mov di, command
    call string_string_copy

    mov ax, input
    call string_string_uppercase

    mov si, input

    mov di, exit_string
    call string_string_compare
    jc near exit

    mov di, help_string
    call string_string_compare
    jc near print_help

    mov di, info_string
    call string_string_compare
    jc near print_info

    mov di, cls_string
    call string_string_compare
    jc near clear_screen

    mov di, dir_string
    call string_string_compare
    jc near list_directory

    mov di, ver_string
    call string_string_compare
    jc near print_ver

    mov di, time_string
    call string_string_compare
    jc near print_time

    mov di, date_string
    call string_string_compare
    jc near print_date

    mov di, cat_string
    call string_string_compare
    jc near cat_file

    mov di, del_string
    call string_string_compare
    jc near del_file

    mov di, copy_string
    call string_string_compare
    jc near copy_file

    mov di, ren_string
    call string_string_compare
    jc near ren_file

    mov di, size_string
    call string_string_compare
    jc near size_file

    mov di, shut_string
    call string_string_compare
    jc near do_shutdown

    mov di, reboot_string
    call string_string_compare
    jc near do_reboot

    mov di, cpu_string
    call string_string_compare
    jc near do_CPUinfo

    mov di, touch_string
    call string_string_compare
    jc near touch_file

    mov di, write_string
    call string_string_compare
    jc near write_file

    mov di, view_string
    call string_string_compare
    jc near view_bmp

    mov di, chars_string
    call string_string_compare
    jc near print_chars_table

    mov di, grep_string
    call string_string_compare
    jc near grep_file

    mov di, head_string
    call string_string_compare
    jc near head_file

    mov di, tail_string
    call string_string_compare
    jc near tail_file

    mov di, theme_string
    call string_string_compare
    jc near change_theme

    mov di, mkdir_string
    call string_string_compare
    jc near mkdir_command

    mov di, deldir_string
    call string_string_compare
    jc near deldir_command

    mov di, cd_string
    call string_string_compare
    jc near cd_command

    mov si, command
    mov di, kernel_file
    call string_string_compare
    jc no_kernel_allowed

    mov ax, command
    call string_string_uppercase
    call string_string_length

    mov si, command
    add si, ax

    sub si, 4

    mov di, bin_extension
    call string_string_compare
    jc bin_file

    mov ax, command
    call string_string_length

    mov si, command
    add si, ax

    mov byte [si], '.'
    mov byte [si+1], 'B'
    mov byte [si+2], 'I'
    mov byte [si+3], 'N'
    mov byte [si+4], 0

    mov si, command
    mov di, kernel_file
    call string_string_compare
    jc no_kernel_allowed

    mov ax, command
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jc total_fail

    jmp execute_bin

bin_file:
    mov ax, command
    mov bx, 0
    mov cx, 32768
    call fs_load_file
    jc total_fail

execute_bin:
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call DisableMouse

    call 32768

    mov ax, 0x2000   
    mov ds, ax        
    mov es, ax           

    call EnableMouse

    ; Load and aply theme from THEME.CFG file
    call load_and_apply_theme

    jmp get_cmd

total_fail:
    mov si, invalid_msg
    call print_string_red
    call print_newline
    jmp get_cmd

no_kernel_allowed:
    mov si, kern_warn_msg
    call print_string_red
    call print_newline
    jmp get_cmd

; ------------------------------------------------------------------

clear_screen:
    call string_clear_screen
    jmp get_cmd

print_ver:
    call print_newline
    mov si, version_msg
    call print_string
    call print_newline
    jmp get_cmd

exit:
    int 0x19
    ret

; ===================== CPU Info Functions =====================

print_edx:
    mov ah, 0eh
    mov bx, 4
.loop4r:
    mov al, dl
    int 10h
    ror edx, 8
    dec bx
    jnz .loop4r
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

print_cores:
    mov si, cores
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 16
    mov al, bl
    call print_al
    ret

print_cache_line:
    mov si, cache_line
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 8
    mov al, bl
    mov bl, 8
    mul bl
    call print_al
    ret

print_stepping:
    mov si, stepping
    call print_string
    mov eax, 1
    cpuid
    and al, 15
    call print_al
    ret

print_al:
    mov ah, 0
    mov dl, 10
    div dl
    add ax, '00'
    mov dx, ax

    mov ah, 0eh
    mov al, dl
    cmp dl, '0'
    jz skip_fn
    mov bl, 0x0F
    int 10h
skip_fn:
    mov al, dh
    mov bl, 0x0F
    int 10h
    ret

; -----------------------------
; Prints CPU information
; IN  : Nothing
do_CPUinfo:
    call print_newline

    pusha

    ; Print FLAGS register
    mov si, flags_str
    call print_string
    xor ax, ax
    lahf
    call print_decimal
    mov si, mt
    call print_string

    ; Print Control Register (CR0)
    mov si, control_reg
    call print_string
    mov eax, cr0
    call print_decimal
    mov si, mt
    call print_string

    ; Print Code Segment (CS)
    mov si, code_segment
    call print_string
    mov ax, cs
    call print_decimal
    mov si, mt
    call print_string

    ; Print Data Segment (DS)
    mov si, data_segment
    call print_string
    mov ax, ds
    call print_decimal
    mov si, mt
    call print_string

    ; Print Extra Segment (ES)
    mov si, extra_segment
    call print_string
    mov ax, es
    call print_decimal
    mov si, mt
    call print_string

    ; Print Stack Segment (SS)
    mov si, stack_segment
    call print_string
    mov ax, ss
    call print_decimal
    mov si, mt
    call print_string

    ; Print Base Pointer (BP)
    mov si, base_pointer
    call print_string
    mov ax, bp
    call print_decimal
    mov si, mt
    call print_string

    ; Print Stack Pointer (SP)
    mov si, stack_pointer
    call print_string
    mov ax, sp
    call print_decimal
    mov si, mt
    call print_string

    call print_newline

    popa

    pusha

    ; Print CPU Family name
    mov si, family_str
    call print_string
    mov eax, 1
    cpuid
    mov ebx, eax     
    shr eax, 8          
    and eax, 0x0F       
    mov ecx, ebx     
    shr ecx, 20          
    and ecx, 0xFF        
    add eax, ecx        

    mov si, family_table
.lookup_loop:
    cmp word [si], 0      
    je .unknown_family
    cmp ax, word [si]     
    je .found_family
    add si, 4   
    jmp .lookup_loop

.found_family:
    mov si, word [si + 2]  
    call print_string_cyan
    jmp .family_done

.unknown_family:
    mov si, unknown_family_str
    call print_string_cyan

.family_done:
    mov si, mt
    call print_string

    ; Print CPU name
    mov si, cpu_name
    call print_string
    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part
    mov si, mt
    call print_string
    call print_cores
    mov si, mt
    call print_string
    call print_cache_line
    mov si, mt
    call print_string
    call print_stepping
    mov si, mt
    call print_string
    popa
    call print_newline
    jmp get_cmd

; ===================== Date and Time Functions =====================

; -----------------------------
; Prints date (DD/MM/YY)
; IN  : Nothing
print_date:
    mov si, date_msg
    call print_string

    mov bx, tmp_string
    call string_get_date_string
    mov si, bx
    call print_string_cyan
    call print_newline
    jmp get_cmd

; -----------------------------
; Prints time (HH:MM:SS)
; IN  : Nothing
print_time:
    mov si, time_msg
    call print_string

    mov bx, tmp_string
    call string_get_time_string
    mov si, bx
    call print_string_cyan
    call print_newline
    jmp get_cmd

; -----------------------------
; One second delay
; IN  : Nothing
delay_ms:
    pusha
    mov ax, dx
    mov cx, 1000
    mul cx
    mov cx, dx
    mov dx, ax
    mov ah, 0x86
    int 0x15
    popa
    ret

do_shutdown:
    mov si, shut_melody
    call play_melody

    pusha

    mov ax, 5300h 
    xor bx, bx 
    int 15h 
    jc APM_error

    mov ax, 5301h
    xor bx, bx
    int 15h

    mov ax, 530Eh
    mov cx, 0102h
    xor bx, bx
    int 15h

    mov ax, 5307h
    mov bx, 0001h
    mov cx, 0003h
    int 15h

    hlt

APM_error: 
    mov si, APM_error_msg
    call print_string_red

    call print_newline

    popa 

    jmp get_cmd

do_reboot:
    int 0x19
    ret

; ===================== File Operation Functions =====================

list_directory:
    call print_newline

    cmp byte [current_directory], 0
    je .show_root
    
    mov si, .subdir_prefix
    call print_string
    mov si, current_directory
    call print_string
    jmp .show_path_done
    
.show_root:
    mov si, root
    call print_string

.show_path_done:
    call print_newline
    call print_newline

    mov cx, 0
    mov ax, dirlist
    call fs_get_file_list
    mov word [file_count], dx

    mov si, dirlist
    mov ah, 0Eh

.repeat:
    lodsb
    cmp al, 0
    je .done
    cmp al, ','
    jne .nonewline
    pusha
    call print_newline
    popa
    jmp .repeat

.nonewline:
    mov bl, 0x0F
    int 10h
    jmp .repeat

.done:
    call print_newline

    mov ax, [file_count]
    call string_int_to_string
    mov si, ax
    call print_string_cyan
    mov si, files_msg
    call print_string

    mov si, .sep
    call print_string

    call fs_free_space
    shr ax, 1           
    mov [.freespace], ax 
    mov bx, 1440 
    sub bx, ax 
    mov ax, bx
    call string_int_to_string
    mov si, ax
    call print_string_green 
    mov si, .kb_msg
    call print_string

    call print_newline
    call print_newline

    mov ax, [.freespace]
    call string_int_to_string
    mov si, ax
    call print_string_green
    mov si, .free_msg
    call print_string

    call print_newline
    call print_newline

    jmp get_cmd

.free_msg      db ' KB free', 0
.kb_msg        db ' KB', 0
.sep           db '   ', 0
.subdir_prefix db 'A:/', 0
.freespace     dw 0

cat_file:
    call print_newline
    pusha
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.filename_provided:
    call fs_file_exists
    jc .not_found
    mov cx, 32768
    call fs_load_file
    mov word [file_size], bx
    cmp bx, 0
    je .empty_file
    mov si, 32768
    mov di, file_buffer
    mov cx, bx
    rep movsb
    mov byte [di], 0
    mov si, file_buffer
    call print_string
    call print_newline
    call print_newline
    popa
    jmp get_cmd

.empty_file:
    popa
    jmp get_cmd

.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd

del_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    mov si, ax
    mov di, kernel_file
    call string_string_compare
    jc .kernel_protected
    mov si, ax
    mov di, .kernel_file_lowc
    call string_string_compare
    jc .kernel_protected
    call fs_remove_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.kernel_protected:
    mov si, kern_warn2_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.success_msg      db 'Deleted file.', 0
.kernel_file_lowc db 'kernel.bin', 0
.failure_msg      db 'Could not delete file - does not exist or write protected', 0

size_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    call fs_get_file_size
    jc .failure
    mov si, .size_msg
    call print_string
    mov ax, bx
    call string_int_to_string
    mov si, ax
    call print_string_cyan
    mov si, .bytes_msg
    call print_string
    call print_newline
    jmp get_cmd

.failure:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.size_msg  db 'Size: ', 0
.bytes_msg db ' bytes', 0

copy_file:
    mov word si, [param_list]
    call string_string_parse
    mov word [.tmp], bx
    cmp bx, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    mov dx, ax
    mov ax, bx
    call fs_file_exists
    jnc .already_exists
    mov ax, dx
    mov cx, 32768
    call fs_load_file
    jc .load_fail
    mov cx, bx
    mov bx, 32768
    mov word ax, [.tmp]
    call fs_write_file
    jc .write_fail
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.load_fail:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.write_fail:
    mov si, writefail_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.tmp dw 0
.success_msg db 'File copied successfully', 0

ren_file:
    mov word si, [param_list]
    call string_string_parse
    cmp bx, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    mov cx, ax
    mov ax, bx
    call fs_file_exists
    jnc .already_exists
    mov ax, cx
    call fs_rename_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.success_msg db 'File renamed successfully', 0
.failure_msg db 'Operation failed - file not found or invalid filename', 0

touch_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    call fs_file_exists
    jnc .already_exists
    call fs_create_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.already_exists:
    mov si, exists_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.success_msg db 'File created successfully', 0
.failure_msg db 'Could not create file - invalid filename or disk error', 0

write_file:
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename_provided:
    cmp bx, 0
    jne .text_provided
    mov si, notext_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.text_provided:
    mov word [.filename], ax
    mov si, bx
    mov di, file_buffer
    call string_string_copy
    mov ax, file_buffer
    call string_string_length
    mov cx, ax
    mov word ax, [.filename]
    mov bx, file_buffer
    call fs_write_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.failure:
    mov si, writefail_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.filename dw 0
.success_msg db 'File written successfully', 0
.notext_msg db 'No text provided for writing', 0

; ===================== Additional String Functions for File Operations =====================

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

; ===================== CUSTOMISATION =====================

change_theme:
    call string_clear_screen

    mov si, [param_list]           ; Get parameter list
    cmp byte [si], 0               ; Check if no parameters provided
    je .show_usage

    ; Check for -h flag
    mov di, .help_flag_str
    call string_string_compare
    jc .show_usage

    ; Check for theme names
    mov di, .default_str
    call string_string_compare
    jc .set_default

    mov di, .groovybox_str
    call string_string_compare
    jc .set_groovybox

    mov di, .ubuntu_str
    call string_string_compare
    jc .set_ubuntu

    ; Invalid theme
    mov si, .invalid_theme_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.set_default:
    call set_default_palette
    jmp .done

.set_groovybox:
    call set_groovybox_palette
    jmp .done

.set_ubuntu:
    call set_ubuntu_palette
    jmp .done

.done:
    call print_interface
    jmp get_cmd

.show_usage:
    mov si, .usage_msg
    call print_string
    call print_newline
    jmp get_cmd

.help_flag_str    db '-h', 0
.default_str      db 'DEFAULT', 0
.groovybox_str    db 'GROOVYBOX', 0
.ubuntu_str       db 'UBUNTU', 0
.usage_msg        db 'Usage: theme [-h] | [thme name]', 10, 13
                  db 'Themes:', 10, 13
                  db '  DEFAULT   Set default color palette', 10, 13
                  db '  GROOVYBOX Set groovybox color palette', 10, 13
                  db '  UBUNTU    Set ubuntu color palette', 10, 13, 0
.invalid_theme_msg db 'Invalid theme name', 0

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

wait_for_key:
    pusha
    mov ax, 0
    mov ah, 10h    
    int 16h
    mov [.tmp_buf], ax
    popa
    mov ax, [.tmp_buf]
    ret

.tmp_buf    dw 0


; -----------------------------
; Prints ASCII table (0-255)
; IN  : Nothing
; OUT : Nothing
print_chars_table:
    pusha
    call print_newline
    
    mov cx, 0  
    
.print_loop:
    mov ah, 0x0E
    mov al, cl                    
    mov bl, 0x0F           
    int 0x10
    
    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10

    mov si, .sep
    call print_string
    
    inc cx
    cmp cx, 256
    je .done
    
    mov ah, 0x0E
    mov al, cl                    
    int 0x10
    
    call print_newline
    inc cx
    cmp cx, 256
    jb .print_loop
    
.done:
    call print_newline
    call print_newline
    popa
    jmp get_cmd

.sep db '  ', 0

; ===================== GREP Command =====================

grep_file:
    call print_newline
    pusha
    
    ; Parse parameters (filename and search string)
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .not_enough_params
    cmp bx, 0
    je .not_enough_params
    
    ; AX = filename, BX = search string
    mov [.filename], ax
    mov [.search_str], bx
    
    ; Check if file exists
    mov ax, [.filename]
    call fs_file_exists
    jc .file_not_found
    
    ; Load file into memory
    mov ax, [.filename]
    mov cx, 32768
    call fs_load_file
    jc .load_error
    
    ; Check if file is empty
    cmp bx, 0
    je .empty_file
    
    ; Prepare for search
    mov word [.file_size], bx
    mov word [.file_ptr], 32768
    mov word [.line_num], 1
    mov word [.col_num], 1
    mov word [.match_count], 0
    
    ; Get search string length
    mov ax, [.search_str]
    call string_string_length
    mov [.search_len], ax
    cmp ax, 0
    je .invalid_search
    
    ; Convert search string to uppercase for case-insensitive search
    mov ax, [.search_str]
    call string_string_uppercase
    
.search_loop:
    ; Check if we have enough bytes left to match
    mov ax, [.file_size]
    cmp ax, [.search_len]
    jb .search_complete
    
    ; Compare current position with search string
    mov si, [.file_ptr]
    mov di, [.search_str]
    mov cx, [.search_len]
    call .compare_chars
    jc .match_found
    
    ; No match, move to next character
    mov si, [.file_ptr]
    mov al, [si]
    call .process_char
    inc word [.file_ptr]
    dec word [.file_size]
    jmp .search_loop

.match_found:
    ; We found a match
    inc word [.match_count]
    
    ; Find start of line
    call .find_line_start
    
    ; Find end of line
    call .find_line_end
    
    ; Print the line with highlighted match
    call .print_line_with_match
    
    ; Skip past the matched string
    mov ax, [.search_len]
    add [.file_ptr], ax
    sub [.file_size], ax
    jmp .search_loop

.search_complete:
    cmp word [.match_count], 0
    jne .done
    mov si, .no_matches_msg
    call print_string
    call print_newline
    jmp .done

.not_enough_params:
    mov si, .usage_msg
    call print_string_red
    call print_newline
    jmp .done

.file_not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp .done

.load_error:
    mov si, .load_error_msg
    call print_string_red
    call print_newline
    jmp .done

.empty_file:
    mov si, .empty_file_msg
    call print_string_red
    call print_newline
    jmp .done

.invalid_search:
    mov si, .invalid_search_msg
    call print_string_red
    call print_newline

.done:
    popa
    jmp get_cmd

; Compare characters case-insensitively
; SI = file pointer, DI = search string, CX = length
; Returns carry set if match
.compare_chars:
    pusha
.compare_loop:
    mov al, [si]
    call .to_upper
    mov bl, [di]
    cmp al, bl
    jne .no_match
    inc si
    inc di
    loop .compare_loop
    stc
    jmp .compare_done
.no_match:
    clc
.compare_done:
    popa
    ret

; Convert character in AL to uppercase
.to_upper:
    cmp al, 'a'
    jb .not_lower
    cmp al, 'z'
    ja .not_lower
    sub al, 32
.not_lower:
    ret

; Process character for line/column counting
; AL = character
.process_char:
    cmp al, 10          ; Newline
    je .newline
    cmp al, 13          ; Carriage return
    je .carriage_return
    inc word [.col_num]
    ret
.newline:
    inc word [.line_num]
    mov word [.col_num], 1
    ret
.carriage_return:
    mov word [.col_num], 1
    ret

; Find start of current line
.find_line_start:
    pusha
    mov si, [.file_ptr]
    mov cx, [.file_ptr]
    sub cx, 32768       ; Calculate how far we can go back
    jbe .find_start_done ; At start of file
    
.find_start_loop:
    dec si
    mov al, [si]
    cmp al, 10          ; Found newline
    je .found_start
    loop .find_start_loop
    jmp .find_start_done
    
.found_start:
    inc si              ; Point to first char after newline
    
.find_start_done:
    mov [.line_start], si
    popa
    ret

; Find end of current line
.find_line_end:
    pusha
    mov si, [.file_ptr]
    mov cx, [.file_size]
    
.find_end_loop:
    mov al, [si]
    cmp al, 10          ; Found newline
    je .found_end
    cmp al, 13          ; Found carriage return
    je .found_end
    inc si
    loop .find_end_loop
    
.found_end:
    mov [.line_end], si
    popa
    ret

; Print line with highlighted match
.print_line_with_match:
    pusha
    
    ; Print line number in yellow
    mov ah, 0x0E
    mov si, .line
    call print_string_yellow
    
    mov ax, [.line_num]
    call print_decimal
    
    mov al, ' '
    int 0x10
    mov si, .column
    call print_string_yellow
    
    mov ax, [.col_num]
    call print_decimal

    call print_newline
    
    ; Print the line with match highlighted
    mov si, [.line_start]
    mov di, [.line_end]
    
.print_line_loop:
    cmp si, di
    jae .print_line_done
    
    ; Check if we're at the match position
    mov ax, [.file_ptr]
    cmp si, ax
    jb .normal_char
    mov ax, [.file_ptr]
    add ax, [.search_len]
    cmp si, ax
    jae .normal_char
    
    ; Highlighted character (red)
    mov bl, 0x0C        ; Red
    jmp .print_char
    
.normal_char:
    mov bl, 0x07        ; White
    
.print_char:
    mov ah, 0x0E
    mov al, [si]
    int 0x10
    inc si
    jmp .print_line_loop
    
.print_line_done:
    call print_newline
    call print_newline
    popa
    ret

; Data for grep command
.filename       dw 0
.search_str     dw 0
.search_len     dw 0
.file_size      dw 0
.file_ptr       dw 0
.line_num       dw 0
.col_num        dw 0
.match_count    dw 0
.line_start     dw 0
.line_end       dw 0

.usage_msg          db 'Usage: grep <filename> <search_string>', 0
.load_error_msg     db 'Error loading file', 0
.empty_file_msg     db 'File is empty', 0
.invalid_search_msg db 'Invalid search string', 0
.no_matches_msg     db 'No matches found', 0
.line               db 'Line:', 0
.column             db 'Column:', 0

; ===================== HEAD Command =====================

head_file:
    call print_newline
    pusha
    
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_help
    
    mov [.filename], ax
    
    mov ax, [.filename]
    call fs_file_exists
    jc .file_not_found
    
    mov ax, [.filename]
    mov cx, 32768
    call fs_load_file
    jc .load_error

    cmp bx, 0
    je .empty_file

    mov word [.file_ptr], 32768
    mov word [.file_size], bx
    mov word [.lines_printed], 0

.print_loop:
    cmp word [.lines_printed], 10
    jge .done
    cmp word [.file_size], 0
    je .done
    
    mov si, [.file_ptr]
    mov al, [si]
    
    cmp al, 10      
    je .print_newline
    cmp al, 13       
    je .skip_char
    cmp al, 32       
    jb .skip_char
    cmp al, 126      
    ja .skip_char
    
    mov ah, 0x0E
    mov bl, 0x07
    int 0x10
    jmp .next_char

.print_newline:
    inc word [.lines_printed]
    call print_newline
    jmp .next_char

.skip_char:
    jmp .next_char

.next_char:
    inc word [.file_ptr]
    dec word [.file_size]
    jmp .print_loop

.done:
    call print_newline
    popa
    jmp get_cmd

.show_help:
    mov si, .help_msg
    call print_string
    call print_newline
    jmp .done

.file_not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp .done

.load_error:
    mov si, .load_error_msg
    call print_string_red
    call print_newline
    jmp .done

.empty_file:
    mov si, .empty_file_msg
    call print_string_red
    call print_newline
    jmp .done

.filename        dw 0
.file_ptr        dw 0
.file_size       dw 0
.lines_printed   dw 0

.help_msg          db 'Usage: head <filename>', 10, 13
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0


; ===================== TAIL Command Implementation =====================

tail_file:
    call print_newline
    pusha
    
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .show_help
    
    mov [.filename], ax
    
    mov ax, [.filename]
    call fs_file_exists
    jc .file_not_found
    
    mov ax, [.filename]
    mov cx, 32768
    call fs_load_file
    jc .load_error
    
    cmp bx, 0
    je .empty_file
    
    mov word [.file_start], 32768
    mov word [.file_size], bx
    mov word [.file_end], 32768
    add [.file_end], bx
    mov word [.lines_to_show], 10
    mov word [.lines_found], 0
    
    mov si, [.file_end]
    dec si
    
.find_lines:
    mov ax, [.lines_found]
    cmp ax, [.lines_to_show]
    jge .found_all_lines
    cmp si, [.file_start]
    jb .found_all_lines
    
    mov al, [si]
    cmp al, 10
    jne .continue_search

    inc word [.lines_found]
    
.continue_search:
    dec si
    jmp .find_lines

.found_all_lines:
    inc si
    mov [.print_start], si

    mov si, [.print_start]
    
.print_loop:
    cmp si, [.file_end]
    jge .done

    mov al, [si]

    cmp al, 10     
    je .print_newline
    cmp al, 13    
    je .skip_char
    cmp al, 32        
    jb .skip_char
    cmp al, 126       
    ja .skip_char

    mov ah, 0x0E
    mov bl, 0x07 
    int 0x10
    jmp .next_char

.print_newline:
    call print_newline
    jmp .next_char

.skip_char:
    jmp .next_char

.next_char:
    inc si
    jmp .print_loop

.done:
    call print_newline
    popa
    jmp get_cmd

.show_help:
    mov si, .help_msg
    call print_string
    call print_newline
    jmp .done

.file_not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp .done

.load_error:
    mov si, .load_error_msg
    call print_string_red
    call print_newline
    jmp .done

.empty_file:
    mov si, .empty_file_msg
    call print_string_red
    call print_newline
    jmp .done

.filename        dw 0
.file_start      dw 0
.file_end        dw 0
.file_size       dw 0
.print_start     dw 0
.lines_to_show   dw 10
.lines_found     dw 0

.help_msg          db 'Usage: tail <filename>', 10, 13
.load_error_msg    db 'Error loading file', 0
.empty_file_msg    db 'File is empty', 0
  

mkdir_command:
    call print_newline
    pusha
    
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .no_dirname
    
    mov si, ax
    push ax
    call string_string_length
    cmp ax, 8
    jg .name_too_long
    pop ax
    
    mov [.dirname], ax
    
    mov ax, [.dirname]
    call fs_file_exists
    jnc .already_exists
    
    mov ax, [.dirname]
    call fs_create_directory
    jc .failure
    
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.no_dirname:
    mov si, .no_dirname_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.name_too_long:
    pop ax
    mov si, .name_too_long_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.already_exists:
    mov si, .already_exists_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.dirname            dw 0
.success_msg        db 'Directory created successfully', 0
.no_dirname_msg     db 'No directory name provided', 0
.name_too_long_msg  db 'Directory name too long (max 8 characters)', 0
.already_exists_msg db 'File or directory already exists', 0
.failure_msg        db 'Could not create directory - disk error', 0

deldir_command:
    call print_newline
    pusha
    
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    je .no_dirname
    
    mov si, ax
    mov di, .dirname_buffer
    call string_string_copy
    
    mov ax, .dirname_buffer
    call string_string_length
    cmp ax, 8
    jg .name_too_long
    
    mov si, .dirname_buffer
    mov cx, 0
.check_dot:
    lodsb
    cmp al, 0
    je .no_extension
    cmp al, '.'
    je .has_extension
    inc cx
    jmp .check_dot
    
.no_extension:
    mov si, .dirname_buffer
    add si, cx
    mov byte [si], '.'
    inc si
    mov byte [si], 'D'
    inc si
    mov byte [si], 'I'
    inc si
    mov byte [si], 'R'
    inc si
    mov byte [si], 0
    
.has_extension:
    mov ax, .dirname_buffer
    mov [.dirname], ax
    
    mov ax, [.dirname]
    call fs_file_exists
    jc .not_found
    
    mov ax, [.dirname]
    call fs_is_directory
    jc .not_directory
    
    mov ax, [.dirname]
    call fs_remove_directory
    jc .failure
    
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.no_dirname:
    mov si, .no_dirname_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.name_too_long:
    mov si, .name_too_long_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.not_directory:
    mov si, .not_directory_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.dirname            dw 0
.dirname_buffer     times 16 db 0
.success_msg        db 'Directory deleted successfully', 0
.no_dirname_msg     db 'No directory name provided', 0
.name_too_long_msg  db 'Directory name too long (max 8 characters)', 0
.not_directory_msg  db 'Not a directory', 0
.failure_msg        db 'Could not delete directory - not empty or disk error', 0

cd_command:
    call print_newline
    pusha
    
    mov word si, [param_list]
    call string_string_parse
    
    cmp ax, 0
    je .show_current
    
    mov si, ax
    mov di, .dotdot_str
    call string_string_compare
    jc .go_parent
    
    mov si, ax
    cmp byte [si], '/'
    je .go_root
    cmp byte [si], '\'
    je .go_root
    
    mov si, ax
    mov di, .dirname_buffer
    call string_string_copy
    
    mov si, .dirname_buffer
    mov cx, 0
.check_dot:
    lodsb
    cmp al, 0
    je .no_extension
    cmp al, '.'
    je .has_extension
    inc cx
    jmp .check_dot
    
.no_extension:
    mov si, .dirname_buffer
    add si, cx
    mov byte [si], '.'
    inc si
    mov byte [si], 'D'
    inc si
    mov byte [si], 'I'
    inc si
    mov byte [si], 'R'
    inc si
    mov byte [si], 0
    
.has_extension:
    mov ax, .dirname_buffer
    call fs_change_directory
    jc .failure
    
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.show_current:
    mov si, .current_msg
    call print_string
    
    cmp byte [current_directory], 0
    jne .show_path
    
    mov si, root
    call print_string_cyan
    jmp .show_done
    
.show_path:
    mov si, current_directory
    call print_string_cyan
    
.show_done:
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.go_parent:
    call fs_parent_directory
    jc .already_root
    
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.already_root:
    mov si, .already_root_msg
    call print_string_yellow
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.go_root:
    mov di, current_directory
    mov byte [di], 0
    
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.dotdot_str         db '..', 0
.dirname_buffer     times 16 db 0
.current_msg        db 'Current directory: ', 0
.success_msg        db 'Directory changed', 0
.already_root_msg   db 'Already in root directory', 0
.failure_msg        db 'Directory not found or invalid', 0

%INCLUDE "src/kernel/features/fs.asm"               ; FAT12 filesystem functions
%INCLUDE "src/kernel/features/string.asm"           ; String functions
%INCLUDE "src/kernel/features/speaker.asm"          ; PC speaker functions
%INCLUDE "src/kernel/features/bmp_rendering.asm"    ; BMP rendering functions
%INCLUDE "src/kernel/features/themes.asm"           ; Themes 
%INCLUDE "src/kernel/features/encrypt.asm"          ; Encryption

; ====== DRIVERS ======
%INCLUDE "src/drivers/ps2_mouse.asm"                ; Mouse driver
; =====================

; ====== API ======
%INCLUDE "src/kernel/features/api/api_output.asm"
%INCLUDE "src/kernel/features/api/api_fs.asm"
%INCLUDE "src/kernel/features/api/api_string.asm"
; =================

; ===================== Data Section =====================

; ------ Header ------
header db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xDB, 0xDB, ' ', 'x16 PRos v0.5', ' ', 0xDB, 0xDB, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0

; ------ Help menu categories ------
help_categories:
    dw  help_menu_1, help_menu_2, help_menu_3, help_menu_4, help_menu_5, help_menu_6                                           
    dw 0 

current_category dw 0

help_menu_1 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Basic Commands                          [1/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  help   - get list of the commands            ', 0xBA, 10, 13
     db 0xBA, '  info   - print system information            ', 0xBA, 10, 13
     db 0xBA, '  ver    - print PRos terminal version         ', 0xBA, 10, 13
     db 0xBA, '  cls    - clear terminal                      ', 0xBA, 10, 13
     db 0xBA, '  shut   - shutdown PC                         ', 0xBA, 10, 13
     db 0xBA, '  reboot - restart system                      ', 0xBA, 10, 13
     db 0xBA, '  date   - print current date (DD/MM/YY)       ', 0xBA, 10, 13
     db 0xBA, '  time   - print current time (HH:MM:SS)       ', 0xBA, 10, 13
     db 0xBA, '  cpu    - print CPU information               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_2 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' File Operations                         [2/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  dir               - list files on disk       ', 0xBA, 10, 13
     db 0xBA, '  size  <filename>  - get file size            ', 0xBA, 10, 13
     db 0xBA, '  cat   <filename>  - display file contents    ', 0xBA, 10, 13
     db 0xBA, '  del   <filename>  - delete a file            ', 0xBA, 10, 13
     db 0xBA, '  copy  <f1> <f2>   - copy a file (only root)  ', 0xBA, 10, 13
     db 0xBA, '  ren   <f1> <f2>   - rename a file (only root)', 0xBA, 10, 13
     db 0xBA, '  touch <filename>  - create empty file        ', 0xBA, 10, 13
     db 0xBA, '  write <f> <text>  - write text to file       ', 0xBA, 10, 13
     db 0xBA, '  view  <filename>  - view BMP image           ', 0xBA, 10, 13
     db 0xBA, '  grep  <f1> <txt>  - find text in the file    ', 0xBA, 10, 13
     db 0xBA, '  head  <filename>  - show first 10 lines      ', 0xBA, 10, 13
     db 0xBA, '                      of a TXT file            ', 0xBA, 10, 13
     db 0xBA, '  tail  <filename>  - show last 10 lines       ', 0xBA, 10, 13
     db 0xBA, '                      of a TXT file            ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_3 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Directories Operations                  [3/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  cd     <dirname>  - change directory         ', 0xBA, 10, 13
     db 0xBA, '  mkdir  <dirname>  - create directory         ', 0xBA, 10, 13
     db 0xBA, '  deldir <dirname>  - delete directory         ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_4 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Image Operations                        [4/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  view  <filename> <flags>  - view image file  ', 0xBA, 10, 13
     db 0xBA, '                      ---                      ', 0xBA, 10, 13
     db 0xBA, '  The VIEW command allows you to view BMP      ', 0xBA, 10, 13
     db 0xBA, '  image files with or without 2x upscaling.    ', 0xBA, 10, 13
     db 0xBA, '  To enable 2x upscaling when displaying,      ', 0xBA, 10, 13
     db 0xBA, '  add the -upscale flag                        ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_5 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Other stuff                             [5/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, '  chars           - show characters table      ', 0xBA, 10, 13
     db 0xBA, '  theme <name>    - change color theme         ', 0xBA, 10, 13
     db 0xBA, '  exit            - exit to boot loader        ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

help_menu_6 db 0xC9, 18 dup(0xCD), ' PRos help ', 18 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' Programs                                [6/6] ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' In order to execute a program in x16-PRos     ', 0xBA, 10, 13
     db 0xBA, ' you need to enter the name of the executable  ', 0xBA, 10, 13
     db 0xBA, ' BIN file with or without extension in the     ', 0xBA, 10, 13
     db 0xBA, ' terminal. Some programs may reboot your PC    ', 0xBA, 10, 13
     db 0xBA, ' after finishing their work.                   ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, '                                               ', 0xBA, 10, 13
     db 0xBA, 47 dup(0xC4), 0xBA, 10, 13
     db 0xBA, ' <-- Back   |  Press ESC to exit   |  Next --> ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 0

; ------ About OS ------
info db 10, 13
     db 20 dup(0xC4), ' INFO ', 21 dup(0xC4), 10, 13
     db '  x16 PRos is the simple 16 bit operating', 10, 13
     db '  system written in NASM for x86 PC`s ', 10, 13
     db 47 dup(0xC4), 10, 13
     db '  Author: PRoX (https://github.com/PRoX2011)', 10, 13
     db '  Disk size: 1.44 MB', 10, 13
     db '  Video mode: 0x12 (640x480; 16 colors)', 10, 13
     db '  File system: FAT12', 10, 13
     db '  License: MIT', 10, 13
     db '  OS version: 0.5.3', 10, 13
     db 0

version_msg db 'PRos Terminal v0.2', 10, 13, 0

; ------ Commands ------
exit_string    db 'EXIT', 0
help_string    db 'HELP', 0
info_string    db 'INFO', 0
cls_string     db 'CLS', 0
dir_string     db 'DIR', 0
ver_string     db 'VER', 0
time_string    db 'TIME', 0
date_string    db 'DATE', 0
cat_string     db 'CAT', 0
del_string     db 'DEL', 0
copy_string    db 'COPY', 0
ren_string     db 'REN', 0
size_string    db 'SIZE', 0
shut_string    db 'SHUT', 0
reboot_string  db 'REBOOT', 0
cpu_string     db 'CPU', 0
touch_string   db 'TOUCH', 0
write_string   db 'WRITE', 0
view_string    db 'VIEW', 0
chars_string   db 'CHARS', 0 
grep_string    db 'GREP', 0
head_string    db 'HEAD', 0
tail_string    db 'TAIL', 0
theme_string   db 'THEME', 0
mkdir_string   db 'MKDIR', 0
deldir_string  db 'DELDIR', 0
cd_string      db 'CD', 0

; ------ Errors ------
invalid_msg       db 'No such command or program', 0
nofilename_msg    db 'No filename or not enough filenames', 0
notfound_msg      db 'File not found', 0
writefail_msg     db 'Could not write file. Write protected or invalid filename?', 0
exists_msg        db 'Target file already exists!', 0
kern_warn_msg     db 'Cannot execute kernel file!', 0
kern_warn2_msg    db 'Cannot delete kernel file!', 0
notext_msg        db 'No text provided for writing', 0
APM_error_msg     db "APM error or APM not available",0
setup_failed_msg  db 'Failed to load SETUP.BIN. Press any key to continue...', 0
boot_cfg_missed   db 'FIRST_B.CFG file not found. Press any key to continue...', 0
user_cfg_missed   db 'USER.CFG file not found. Press any key to continue...', 0
pass_cfg_missed   db 'PASSWORD.CFG file not found. Press any key to continue...', 0
prompt_cfg_missed db 'PROMPT.CFG file not found. Press any key to continue...', 0
logo_missed       db 'LOGO.BMP file not found. Press any key to continue...', 0

; ------ Log messages ------
error_message    db '[ ERROR ] ', 0
okay_message     db '[ OKAY ]  ', 0
warn_message     db '[ WARN ]  ', 0

; ------ CPU info ------
flags_str          db '  FLAGS: ', 0
control_reg        db '  Control Reg   (CR) : ', 0
stack_segment      db '  Stack Seg     (SS) : ', 0
code_segment       db '  Code Seg      (CS) : ', 0
data_segment       db '  Data Seg      (DS) : ', 0
extra_segment      db '  Extra Seg     (ES) : ', 0
base_pointer       db '  Base Pointer  (BP) : ', 0
stack_pointer      db '  Stack Pointer (SP) : ', 0

family_str         db '  CPU Family         : ', 0
unknown_family_str db 'Unknown', 0
intel_core_str     db 'Intel', 0
intel_pentium_str  db 'Intel Pentium', 0
amd_ryzen_str      db 'AMD Ryzen', 0
amd_athlon_str     db 'AMD Athlon', 0

family_table:
    dw 6, intel_core_str
    dw 5, intel_pentium_str
    dw 15, amd_athlon_str
    dw 21, amd_ryzen_str
    dw 0, 0

cpu_name           db '  CPU name           : ', 0
cores              db '  CPU cores          : ', 0
stepping           db '  Stepping ID        : ', 0
cache_line         db '  Cache line         : ', 0

time_msg  db 'Current time: ', 0
date_msg  db 'Current date: ', 0

files_msg db ' files', 0
root      db 'A:/', 0

; ------ Sounds ------
start_melody:
    dw 4186, 150 
    dw 3136, 150  
    dw 2637, 150  
    dw 2093, 300  
    dw 0, 0         


shut_melody:
    dw 2093, 150  
    dw 2637, 150  
    dw 3136, 150    
    dw 4186, 300    
    dw 0, 0         

file_size       dw 0
param_list      dw 0

x_offset dw 0
y_offset dw 0

bin_extension   db '.BIN', 0

total_file_size dd 0
file_count      dw 0

timezone_offset dw 0


first_boot_value         db '1', 0

kernel_file          db 'KERNEL.BIN', 0
setup_bin_file       db 'SETUP.BIN', 0
user_cfg_file        db 'USER.CFG', 0
password_cfg_file    db 'PASSWORD.CFG', 0
timezone_cfg_file    db 'TIMEZONE.CFG', 0
theme_cfg_file       db 'THEME.CFG', 0
first_boot_file      db 'FIRST_B.CFG', 0
prompt_cfg_file      db 'PROMPT.CFG', 0
autoexec_file        db 'AUTOEXEC.BIN', 0
pros_logo_file       db 'LOGO.BMP', 0

login_password_prompt  db 19 dup(' '), 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                       db 19 dup(' '), 0xBA, '        Enter your password:           ', 0xBA, 10, 13
                       db 19 dup(' '), 0xBA, '    _______________________________    ', 0xBA, 10, 13
                       db 19 dup(' '), 0xC0, 39 dup(0xCD), 0xBC, 10, 13, 0

mt           db '', 10, 13, 0
Sides        dw 2
SecsPerTrack dw 18
bootdev      db 0
fmt_date     dw 1
 
; ------ Buffers ------
tmp_string        times 15    db 0
command           times 32    db 0
user              times 32    db 0
password          times 32    db 0
decrypted_pass    times 32    db 0
timezone          times 32    db 0
final_prompt      times 64    db 0
temp_prompt       times 64    db 0  
input             times 256   db 0
current_directory times 256   db 0
dirlist           times 1024  db 0
file_buffer       times 32768 db 0