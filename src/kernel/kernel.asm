; ==================================================================
; x16-PRos -- The x16-PRos Operating System kernel
; Copyright (C) 2025 PRoX2011
;
; This is loaded from disk by BOOT.BIN as KERNEL.BIN
; ==================================================================

[BITS 16]
[ORG 0x0000]

COLOR_WHITE          equ 0x0F
COLOR_GREEN          equ 0x0A
COLOR_CYAN           equ 0x0B
COLOR_RED            equ 0x0C
COLOR_YELLOW         equ 0x0E

CHAR_LF              equ 0x0A
CHAR_CR              equ 0x0D

DOS_INT20_VECTOR     equ 0x20

COM_EXIT_OPCODE      equ 0xCD
COM_STACK_TOP        equ 0xFFFE
COM_ENTRY_OFFSET     equ 0x0100

KERNEL_DATA_SEG      equ 0x2000
FONT_SEG             equ 0x1000

PROGRAM_LOAD_OFF     equ 0x8000
DIRLIST_OFF          equ 0xA800
COMMAND_HISTORY_OFF  equ 0xD000
DISK_BUFFER_OFF      equ 0xE000
DISK_BUFFER_SIZE     equ 0x1C00
KERNEL_WORK_END_OFF  equ DISK_BUFFER_OFF + DISK_BUFFER_SIZE  ; 0xFC00

disk_buffer          equ DISK_BUFFER_OFF
program_load_addr    equ PROGRAM_LOAD_OFF
dirlist              equ DIRLIST_OFF
command_history      equ COMMAND_HISTORY_OFF
program_seg          equ 0x2FC0


section .text

start:
    cli

    ; ------ Stack installation ------
    mov ax, 0
    mov ss, ax
    mov sp, 0x0FFFF
    ; --------------------------------

    call set_video_mode        ; Set video mode
    call init_system           ; Init system (segments, timer, api, configs, display, security, start autoexec)
    call fs_list_drives        ; List drives
    call load_timezone_cfg     ; It is necessary after completion of SETUP.BIN so that the time zone is updated to the user one
    call load_and_apply_theme  ; Load and aply theme from THEME.CFG file
    call shell                 ; Start PRos terminal

    jmp $


set_video_mode:
    mov ax, 0x12
    int 0x10
    call font_reinstall
    ret

; ===================== String Output Functions =====================

; -----------------------------
; Output a string to the screen
; IN  : SI = string location
; OUT : Nothing
print_string:
    mov bl, COLOR_WHITE
.print_char:
    lodsb
    cmp al, 0
    je .done
    call print_char
    jmp .print_char
.done:
    ret

; -----------------------------
; Prints empty line
; IN  : Nothing
; OUT : Nothing
print_newline:
    mov bl, COLOR_WHITE
    mov al, CHAR_LF
    call print_char
    ret

; ===================== Colored print functions =====================

; ------ Shared color printer ------
print_string_color:
.print_char:
    lodsb
    cmp al, 0
    je .done
    call print_char
    jmp .print_char
.done:
    ret

; -----------------------------
; Output a single character with color
; IN  : AL = character code
;       BL = color
; OUT : Nothing
print_char:
    cmp al, CHAR_LF
    je .newline
    cmp al, CHAR_CR
    je .carriage_return
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret
.carriage_return:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret
.newline:
    push ax
    mov ah, 0x0E
    xor bh, bh
    mov al, CHAR_CR
    int 0x10
    pop ax
    mov ah, 0x0E
    xor bh, bh
    mov al, CHAR_LF
    int 0x10
    ret

; ------ Green ------
print_string_green:
    mov bl, COLOR_GREEN
    jmp print_string_color

; ------ Cyan ------
print_string_cyan:
    mov bl, COLOR_CYAN
    jmp print_string_color

; ------ Red ------
print_string_red:
    mov bl, COLOR_RED
    jmp print_string_color

; ------ Yellow ------
print_string_yellow:
    mov bl, COLOR_YELLOW
    jmp print_string_color

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
    mov bl, COLOR_WHITE
.print_char:
    cmp cx, 0
    je .return
    pop dx
    add dx, 48
    mov al, dl
    call print_char
    dec cx
    jmp .print_char
.return:
    ret

print_drive_prefix:
    mov bl, COLOR_WHITE
    mov al, [current_drive_char]
    call print_char
    mov al, ':'
    call print_char
    mov al, '/'
    call print_char
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
.copyright  db '* Copyright (C) 2024-2026 PRoX2011', 10, 13, 0
.shell      db '* Shell: ', 0
.tip        db 'Type HELP to get list of the comands', 10, 13, 0

print_help:
    pusha

    call save_current_dir
    mov di, temp_saved_dir
    mov si, current_directory
    call string_string_copy
    mov ax, [current_dir_cluster]
    mov [temp_saved_cluster], ax
    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

    mov ax, bin_dir_name
    call fs_change_directory
    jc .use_builtin_help

    mov ax, .help_bin_file
    call fs_file_exists
    jc .restore_and_builtin

    mov ax, .help_bin_file
    mov bx, 0
    mov cx, program_load_addr
    call fs_load_file
    jc .restore_and_builtin

    call restore_current_dir

    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call DisableMouse
    call program_load_addr

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme

    popa
    jmp get_cmd

.restore_and_builtin:
    mov di, current_directory
    mov si, temp_saved_dir
    call string_string_copy
    mov ax, [temp_saved_cluster]
    mov [current_dir_cluster], ax

.use_builtin_help:
    popa
    call print_newline

    mov si, kshell_comands
    call print_string

    call print_newline

    jmp get_cmd

.help_bin_file db 'HELP.BIN', 0

print_info:
    mov si, info
    call print_string_green
    call print_newline
    jmp get_cmd

; ===================== Command Line Interpreter =====================

shell:
get_cmd:
    call refresh_prompt
    mov si, final_prompt
    call print_string

    mov di, input
    mov al, 0
    mov cx, 256
    rep stosb

    mov di, command
    mov al, 0
    mov cx, 32
    rep stosb

    mov ax, dirlist
    call fs_get_file_list
    mov byte [autocomplete_enabled], 1

    mov ax, input
    call string_input_string

    mov byte [autocomplete_enabled], 0
    call print_newline
    cmp byte [input], 0
    je .save_input_to_history_skip

    ; append input to command history (16 entries x 256 bytes)
    pusha
    cmp byte [command_history_top], 16
    jbe .history_top_ok
    mov byte [command_history_top], 16
.history_top_ok:
    xor cx, cx
    mov cl, [command_history_top]
    cmp cx, 0
    je .save_input_to_history_store_new
    cmp cx, 16
    jb .history_shift_start_ok
    mov cx, 15
.history_shift_start_ok:
    dec cx
.shift_history_element_loop:
    mov bx, cx
    shl bx, 8
    lea si, [command_history + bx]
    add bx, 256
    lea di, [command_history + bx]
.shift_history_shift_char:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    cmp al, 0
    jne .shift_history_shift_char
    cmp cx, 0
    je .save_input_to_history_store_new
    dec cx
    jmp .shift_history_element_loop

.save_input_to_history_store_new:
    mov di, command_history
    mov si, input
.save_input_loop:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .save_input_to_history_end
    inc si
    inc di
    jmp .save_input_loop
.save_input_to_history_end:
    cmp byte [command_history_top], 16
    jae .save_input_to_history_done
    inc byte [command_history_top]
.save_input_to_history_done:
    popa

.save_input_to_history_skip:
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

    mov ax, command
    call string_string_uppercase

    ; ============ Drive Change Check (A:, B:, C:) ============
    mov si, command
    
    call string_string_length
    cmp ax, 2
    jne .not_drive_change

    cmp byte [si+1], ':'
    jne .not_drive_change

    mov al, [si]
    call fs_change_drive_letter
    call print_newline
    mov si, .success_disk_change_msg
    call print_string_green
    call print_newline
    call print_newline
    jnc get_cmd

    mov si, bad_drive_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.not_drive_change:
    ; ============ kernel shell comands ============
    mov si, command

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

    ; ============ Check File Extension ============

    ; Check if command ends with .COM
    mov ax, command
    call string_string_length
    cmp ax, 4
    jl .check_bin_extension

    mov si, command
    add si, ax
    sub si, 4
    mov di, com_extension
    call string_string_compare
    jc .load_com_program

.check_bin_extension:
    ; Check if command ends with .BIN
    mov ax, command
    call string_string_length
    mov si, command
    add si, ax
    sub si, 4
    mov di, bin_extension
    call string_string_compare
    jc .load_bin_program

    ; ============ Auto-append Extensions ============

    ; No extension found, try .COM first
    mov ax, command
    call string_string_length
    mov si, command
    add si, ax
    mov byte [si], '.'
    mov byte [si+1], 'C'
    mov byte [si+2], 'O'
    mov byte [si+3], 'M'
    mov byte [si+4], 0

    ; Check if .COM file exists
    mov ax, command
    call fs_file_exists
    jnc .load_com_program

    ; .COM not found, try .BIN
    mov ax, command
    call string_string_length
    mov si, command
    add si, ax
    sub si, 4
    mov byte [si], '.'
    mov byte [si+1], 'B'
    mov byte [si+2], 'I'
    mov byte [si+3], 'N'
    mov byte [si+4], 0

.load_bin_program:
    mov si, command
    mov di, kernel_file
    call string_string_compare
    jc no_kernel_allowed

    ; Try to load from current directory
    mov ax, command
    mov bx, 0
    mov cx, program_load_addr
    call fs_load_file
    jnc execute_bin

    ; If not found, try /BIN.DIR on current drive first
    call save_current_dir
    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

    mov ax, bin_dir_name
    call fs_change_directory
    jc .restore_and_try_a_bin

    mov ax, command
    mov bx, 0
    mov cx, program_load_addr
    call fs_load_file
    jc .restore_and_try_a_bin

    call restore_current_dir
    jmp execute_bin

.restore_and_try_a_bin:
    call restore_current_dir
    cmp byte [current_drive_char], 'A'
    je total_fail

    ; Then try A:/BIN.DIR (legacy fallback)
    call save_current_dir
    mov al, 'A'
    call fs_change_drive_letter
    jc .restore_and_fail_a_bin

    mov ax, bin_dir_name
    call fs_change_directory
    jc .restore_and_fail_a_bin

    mov ax, command
    mov bx, 0
    mov cx, program_load_addr
    call fs_load_file
    jc .restore_and_fail_a_bin

    call restore_current_dir
    jmp execute_bin

.restore_and_fail_a_bin:
    call restore_current_dir
    jmp total_fail

.load_com_program:
    mov ax, command
    mov cx, 0x0100
    mov dx, [program_seg_runtime]
    call fs_load_huge_file
    jc .try_bin_dir_com

    jmp execute_com

.try_bin_dir_com:
    call save_current_dir
    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

    mov ax, bin_dir_name
    call fs_change_directory
    jc .restore_and_try_a_com

    mov ax, command
    mov cx, 0x0100
    mov dx, [program_seg_runtime]
    call fs_load_huge_file
    jc .restore_and_try_a_com

    call restore_current_dir
    jmp execute_com

.restore_and_try_a_com:
    call restore_current_dir
    cmp byte [current_drive_char], 'A'
    je total_fail

    call save_current_dir
    mov al, 'A'
    call fs_change_drive_letter
    jc .restore_and_fail_a_com

    mov ax, bin_dir_name
    call fs_change_directory
    jc .restore_and_fail_a_com

    mov ax, command
    mov cx, 0x0100
    mov dx, [program_seg_runtime]
    call fs_load_huge_file
    jc .restore_and_fail_a_com

    call restore_current_dir
    jmp execute_com

.restore_and_fail_a_com:
    call restore_current_dir
    jmp total_fail

.success_disk_change_msg db 'Disk changed', 0

; ============ Execute BIN Program ============

execute_bin:
    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0

    mov ax, [param_list]
    cmp ax, 0
    je .no_params
    mov si, ax
    jmp .continue

.no_params:
    xor si, si

.continue:
    mov di, 0

    ; Save kernel stack in case BIN modifies SS:SP.
    mov [bin_stack_save], sp
    mov [bin_ss_save], ss

    call DisableMouse
    call program_load_addr

    cli
    mov ax, [bin_ss_save]
    mov ss, ax
    mov sp, [bin_stack_save]

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    sti

    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme

    jmp get_cmd

; ============ Execute COM Program ============

execute_com:
    ; Save current stack
    mov [com_stack_save], sp
    mov [com_ss_save], ss

    call api_dos_init

    ; Setup COM program environment
    mov ax, [program_seg_runtime]
    mov ds, ax
    mov es, ax

    mov byte [ds:0x0000], COM_EXIT_OPCODE
    mov byte [ds:0x0001], DOS_INT20_VECTOR

    ; Setup COM program stack
    cli
    mov ss, ax
    mov sp, COM_STACK_TOP
    sti

    call DisableMouse

    push word 0x0000

    ; Jump to COM program entry point (COM_ENTRY_OFFSET).
    ; DS already points to COM segment, so use DS directly as CS.
    push ds                    ; CS
    push word COM_ENTRY_OFFSET ; IP
    retf                       ; Jump

.com_return:
    jmp int20_handler


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
    jmp reboot_system

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

    mov bl, COLOR_WHITE
    mov al, dl
    cmp dl, '0'
    jz skip_fn
    call print_char
skip_fn:
    mov al, dh
    call print_char
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
    jmp reboot_system

reboot_system:
    cli
    mov ax, 0x0040
    mov ds, ax
    ; Force cold boot path so BIOS reinitializes hardware state.
    mov word [0x0072], 0x0000
    jmp 0FFFFh:0000h

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
    call print_drive_prefix

.show_path_done:
    call print_newline
    call print_newline

    mov ax, dirlist
    call fs_get_file_list
    mov word [file_count], dx

    mov si, dirlist
    mov word [.files_in_row], 0

.print_entry:
    cmp byte [si], 0
    je .done_entries

    push si
    mov cx, 12
    mov ah, 0x0E
    mov bl, COLOR_WHITE
.print_name_char:
    lodsb
    int 0x10
    loop .print_name_char
    pop si

    mov ah, 0x0E
    mov al, ' '
    mov bl, 0x0F
    int 0x10
    int 0x10

    test byte [si+16], 0x10
    jnz .print_dir_marker

    mov ax, [si+12]
    call .print_size_decimal
    jmp .after_size

.print_dir_marker:
    push si
    mov si, .dir_marker_str
    call print_string
    pop si
    mov word [.size_digits], 5

.after_size:
    inc word [.files_in_row]
    cmp word [.files_in_row], 3
    je .add_newline

    mov ax, 12
    sub ax, [.size_digits]
    mov cx, ax
    jcxz .next_entry
    mov ah, 0x0E
    mov al, ' '
    mov bl, COLOR_WHITE
.pad_column:
    int 0x10
    loop .pad_column
    jmp .next_entry

.add_newline:
    mov word [.files_in_row], 0
    call print_newline

.next_entry:
    add si, 18
    jmp .print_entry

.done_entries:
    cmp word [.files_in_row], 0
    je .no_final_newline
    call print_newline
.no_final_newline:
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

.print_size_decimal:
    mov word [.size_digits], 0
    push bx
    push cx
    push dx
    mov cx, 0
.sd_push_digits:
    cmp ax, 0
    je .sd_check_zero
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    inc word [.size_digits]
    jmp .sd_push_digits
.sd_check_zero:
    cmp cx, 0
    jne .sd_pop_digits
    mov ah, 0x0E
    mov al, '0'
    mov bl, COLOR_WHITE
    int 0x10
    mov word [.size_digits], 1
    jmp .sd_done
.sd_pop_digits:
    mov ah, 0x0E
    mov bl, COLOR_WHITE
.sd_pop_loop:
    pop dx
    add dl, '0'
    mov al, dl
    int 0x10
    dec cx
    jnz .sd_pop_loop
.sd_done:
    pop dx
    pop cx
    pop bx
    ret

.files_in_row    dw 0
.size_digits     dw 0
.dir_marker_str  db '<DIR>', 0
.free_msg        db ' KB free', 0
.kb_msg          db ' KB', 0
.sep             db '   ', 0
.subdir_prefix   db 'A:/', 0
.freespace       dw 0

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
    jmp .exit_cat

.filename_provided:
    push ax
    call fs_file_exists
    pop ax
    jc .not_found

    mov cx, program_load_addr
    mov dx, ds

    call fs_load_huge_file
    jc .load_fail

    mov word [.rem_size], ax
    mov word [.rem_size+2], dx

    mov cx, ax
    or cx, dx
    jz .empty_file

    mov word [.curr_seg], ds
    mov word [.curr_off], program_load_addr
    mov word [.line_count], 0

.print_loop:
    cmp dword [.rem_size], 0
    je .end_cat

    mov es, [.curr_seg]
    mov si, [.curr_off]
    mov al, [es:si]

    inc word [.curr_off]
    jnz .no_wrap

    add word [.curr_seg], 0x1000
.no_wrap:
    sub dword [.rem_size], 1

    cmp al, 0
    je .end_cat

    cmp al, CHAR_LF
    je .handle_newline

    mov ah, 0x0E
    mov bl, COLOR_WHITE
    int 0x10
    jmp .print_loop

.handle_newline:
    mov al, CHAR_CR
    int 0x10
    mov al, CHAR_LF
    int 0x10

    inc word [.line_count]
    cmp word [.line_count], 23
    jne .print_loop

    push si
    push es
    mov si, .continue_msg
    call print_string_cyan

    mov ah, 0
    int 16h

    mov si, .clear_msg
    call print_string

    mov word [.line_count], 0
    pop es
    pop si
    jmp .print_loop

.end_cat:
    call print_newline
    call print_newline
    jmp .exit_cat

.empty_file:
    mov si, .empty_msg
    call print_string_red
    call print_newline
    jmp .exit_cat

.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp .exit_cat

.load_fail:
    mov si, .load_err_msg
    call print_string_red
    call print_newline

.exit_cat:
    popa
    call print_newline
    jmp get_cmd

.line_count   dw 0
.curr_seg     dw 0
.curr_off     dw 0
.rem_size     dd 0

.continue_msg db 13, ' -- Press key -- ', 0
.clear_msg    db 13, '                 ', 13, 0
.empty_msg    db 'File is empty', 0
.load_err_msg db 'Error loading file', 0

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
    mov cx, program_load_addr
    mov dx, KERNEL_DATA_SEG
    call fs_load_huge_file
    jc .load_fail
    mov cx, bx
    mov bx, program_load_addr
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
    mov ax, bx
    call string_string_length
    mov cx, ax
    mov word ax, [.filename]
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

    ; Check for ".."
    mov si, ax
    mov di, .dotdot_str
    call string_string_compare
    jc .go_parent

    ; Check for "/" or "\" (go to root)
    mov si, ax
    cmp byte [si], '/'
    je .go_root
    cmp byte [si], '\'
    je .go_root

    ; Copy full path to work buffer
    mov si, ax
    mov di, .path_buffer
    call string_string_copy

    ; Save state for rollback on failure
    mov ax, [current_dir_cluster]
    mov [.saved_cluster], ax
    mov si, current_directory
    mov di, .saved_dir
    call string_string_copy

    ; Process path components separated by '/'
    mov si, .path_buffer

.next_path_component:
    cmp byte [si], 0
    je .cd_path_done

    ; Extract next component up to '/' or end
    mov di, .comp_buffer
    xor cx, cx

.copy_comp:
    lodsb
    cmp al, '/'
    je .comp_sep
    cmp al, '\'
    je .comp_sep
    cmp al, 0
    je .comp_end
    stosb
    inc cx
    jmp .copy_comp

.comp_sep:
    mov byte [di], 0
    jmp .process_comp

.comp_end:
    mov byte [di], 0
    dec si                  ; point back at null for loop exit

.process_comp:
    push si                 ; save remaining path position

    ; Skip empty components (e.g., "//")
    cmp cx, 0
    je .skip_empty_comp

    ; Check for ".." component
    cmp word [.comp_buffer], '..'
    jne .not_dotdot_comp
    cmp byte [.comp_buffer + 2], 0
    jne .not_dotdot_comp
    call fs_parent_directory
    jc .cd_rollback
    jmp .skip_empty_comp

.not_dotdot_comp:
    ; Auto-append .DIR if no extension
    mov si, .comp_buffer
    xor bx, bx
.check_comp_dot:
    lodsb
    cmp al, 0
    je .comp_check_dot_done
    cmp al, '.'
    je .comp_has_dot
    jmp .check_comp_dot
.comp_has_dot:
    mov bx, 1
.comp_check_dot_done:
    cmp bx, 0
    jne .comp_has_ext

    ; Append .DIR
    mov si, .comp_buffer
    mov ax, si
    call string_string_length
    mov si, .comp_buffer
    add si, ax
    mov byte [si], '.'
    mov byte [si+1], 'D'
    mov byte [si+2], 'I'
    mov byte [si+3], 'R'
    mov byte [si+4], 0

.comp_has_ext:
    mov ax, .comp_buffer
    call fs_change_directory
    jc .cd_rollback

.skip_empty_comp:
    pop si
    jmp .next_path_component

.cd_path_done:
    mov si, .success_msg
    call print_string_green
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.cd_rollback:
    pop si                  ; clean remaining path from stack
    ; Restore original state
    mov ax, [.saved_cluster]
    mov [current_dir_cluster], ax
    mov si, .saved_dir
    mov di, current_directory
    call string_string_copy
    jmp .failure

.show_current:
    mov si, .current_msg
    call print_string

    cmp byte [current_directory], 0
    jne .show_path

    call print_drive_prefix
    jmp .show_done

.show_path:
    call print_drive_prefix
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
    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

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
.comp_buffer        times 16 db 0
.path_buffer        times 256 db 0
.saved_dir          times 256 db 0
.saved_cluster      dw 0
.current_msg        db 'Current directory: ', 0
.success_msg        db 'Directory changed', 0
.already_root_msg   db 'Already in root directory', 0
.failure_msg        db 'Directory not found or invalid', 0

%INCLUDE "src/kernel/init.asm"                      ; x16-PRos initialisation
%INCLUDE "src/kernel/log.asm"                       ; Log functions
%INCLUDE "src/kernel/features/fs.asm"               ; FAT12 filesystem functions
%INCLUDE "src/kernel/features/string.asm"           ; String functions
%INCLUDE "src/kernel/features/timezone.asm"         ; Timezone config/time helpers
%INCLUDE "src/kernel/features/speaker.asm"          ; PC speaker functions
%INCLUDE "src/kernel/features/bmp_rendering.asm"    ; BMP rendering functions
%INCLUDE "src/kernel/features/themes.asm"           ; Themes
%INCLUDE "src/kernel/features/encrypt.asm"          ; Encryption
%INCLUDE "src/kernel/features/com/com.asm"          ; COM
%INCLUDE "src/kernel/features/cp866.asm"            ; .FNT font loading

; ====== DRIVERS ======
%INCLUDE "src/drivers/ps2_mouse.asm"                ; Mouse driver
; =====================

; ====== API ======
%INCLUDE "src/kernel/features/api/api_output.asm"
%INCLUDE "src/kernel/features/api/api_fs.asm"
; =================

; ===================== Data Section =====================
section .data
; ------ Header ------
header db 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xDB, 0xDB, ' ', 'x16 PRos v0.8', ' ', 0xDB, 0xDB, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB2, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0xB0, 0

; ------ Help ------
kshell_comands db 'HELP               - get list of commands', 10, 13
               db 'INFO               - system information', 10, 13
               db 'VER                - terminal version', 10, 13
               db 'CLS                - clear screen', 10, 13
               db 'SHUT               - shutdown', 10, 13
               db 'REBOOT             - restart', 10, 13
               db 'DATE               - current date (DD/MM/YY)', 10, 13
               db 'TIME               - current time (HH:MM:SS)', 10, 13
               db 'CPU                - CPU info', 10, 13
               db 'DIR                - list files', 10, 13
               db 'SIZE   <f>         - file size', 10, 13
               db 'CAT    <f>         - show file', 10, 13
               db 'DEL    <f>         - delete file', 10, 13
               db 'COPY   <f1> <f2>   - copy file (root only)', 10, 13
               db 'REN    <f1> <f2>   - rename file (root only)', 10, 13
               db 'TOUCH  <f>         - create empty file', 10, 13
               db 'WRITE  <f> <text>  - write to file', 10, 13
               db 'VIEW   <f> <flags> - view BMP image', 10, 13
               db 'CD     <dir>       - change directory', 10, 13
               db 'MKDIR  <dir>       - create directory', 10, 13
               db 'DELDIR <dir>       - delete directory', 10, 13
               db 'EXIT               - exit to bootloader', 10, 13, 0

; ------ About OS ------
info db 10, 13
     db 20 dup(0xC4), ' INFO ', 21 dup(0xC4), 10, 13
     db '  x16 PRos is the simple 16 bit operating', 10, 13
     db '  system written in NASM for x86 PC`s ', 10, 13
     db 47 dup(0xC4), 10, 13
     db '  Author:           PRoX   (https://github.com/PRoX2011)', 10, 13
     db '  Support project:  DALink (https://dalink.to/PRoXdev)', 10, 13
     db '  Source code:      GitHub (https://github.com/PRoX2011/x16-PRos)', 10, 13
     db '  License:          MIT', 10, 13
     db '  OS version:       0.8', 10, 13
     db 0

version_msg db 'PRos Terminal v0.3', 10, 13, 0

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
mkdir_string   db 'MKDIR', 0
deldir_string  db 'DELDIR', 0
cd_string      db 'CD', 0

autocomplete_cmd_table:
    dw exit_string, help_string, info_string, cls_string
    dw dir_string, cd_string, ver_string, time_string, date_string
    dw cat_string, del_string, copy_string, ren_string
    dw size_string, shut_string, reboot_string, cpu_string
    dw touch_string, write_string, view_string, mkdir_string
    dw deldir_string
    dw 0

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
bad_drive_msg     db 'Drive not ready or does not exist!', 0

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

file_size            dw 0
param_list           dw 0

x_offset             dw 0
y_offset             dw 0

bin_extension        db '.BIN', 0
com_extension        db '.COM', 0

total_file_size      dd 0
file_count           dw 0

timezone_offset      dw 0

com_stack_save       dw 0
com_ss_save          dw 0
bin_stack_save       dw 0
bin_ss_save          dw 0
program_seg_runtime  dw program_seg

first_boot_value     db '1', 0

kernel_file          db 'KERNEL.BIN', 0
setup_bin_file       db 'SETUP.BIN', 0
user_cfg_file        db 'USER.CFG', 0
password_cfg_file    db 'PASSWORD.CFG', 0
timezone_cfg_file    db 'TIMEZONE.CFG', 0
theme_cfg_file       db 'THEME.CFG', 0
first_boot_file      db 'FIRST_B.CFG', 0
prompt_cfg_file      db 'PROMPT.CFG', 0
autoexec_file        db 'AUTOEXEC.BIN', 0

system_cfg_file      db 'SYSTEM.CFG', 0
cfg_key_logo         db 'LOGO=', 0
cfg_key_logo_stretch db 'LOGO_STRETCH=', 0
cfg_key_sound        db 'START_SOUND=', 0
default_logo_file    db 'LOGO.BMP', 0
cfg_sound_enabled    db 1  ; 1 = True, 0 = False
cfg_logo_enabled     db 1  ; 1 = True, 0 = False
cfg_logo_stretch     db 0  ; 1 = Stretch, 0 = Centered

bin_dir_name         db 'BIN.DIR', 0
conf_dir_name        db 'CONF.DIR', 0

current_drive_char   db 'A'

login_password_prompt  db 19 dup(' '), 0xC9, 39 dup(0xCD), 0xBB, 10, 13
                       db 19 dup(' '), 0xBA, '        Enter your password:           ', 0xBA, 10, 13
                       db 19 dup(' '), 0xBA, '    _______________________________    ', 0xBA, 10, 13
                       db 19 dup(' '), 0xC0, 39 dup(0xCD), 0xBC, 10, 13, 0

mt                   db '', 10, 13, 0
Sides                dw 2
SecsPerTrack         dw 18
bootdev              db 0
current_disk         db 0 
fmt_date             dw 1
command_history_top  db 0

saved_disk           db 0
saved_drive_char     db 0
autocomplete_enabled db 0
current_dir_cluster  dw 0
saved_dir_cluster    dw 0

section .bss
; ------ Buffers ------
current_logo_file  resb 13
tmp_string         resb 15
command            resb 32
user               resb 32
password           resb 32
decrypted_pass     resb 32
timezone           resb 32
saved_directory    resb 32
final_prompt       resb 64
temp_prompt        resb 64
save_dir_buffer    resb 256
input              resb 256
current_directory  resb 256
temp_saved_dir     resb 256
temp_saved_cluster resw 1
first_boot_buf     resb 8

kernel_end:
; kernel_end MUST stay below PROGRAM_LOAD_OFF (0x8000 = 32 KiB).