; ==================================================================
; x16-PRos -- The x16-PRos Operating System kernel
; Copyright (C) 2025 PRoX2011
;
; This is loaded from disk by BOOT.BIN as KERNEL.BIN
; ==================================================================

[BITS 16]
[ORG 0x0000]

start:
    cli 
    ; ------ Stack installation ------
    mov ax, 0x2000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE

    call set_video_mode  ; Setting up videomode

    sti 

    cld

    mov ax, 2000h
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set up frequency (1193180 Hz / 1193 = ~1000 Hz)
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al

    ; PRoX kernel API initialization
    call api_output_init    ; Output API (INT 21H)
    call api_fs_init        ; File system API (INT 22h)
    call api_string_init    ; String API (INT 23h)

    call print_interface    ; Help menu and header
    mov si, start_melody
    call play_melody        ; Startup melody
    call shell              ; PRos terminal
    jmp $

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

print_interface:
    mov si, header
    call print_string
    call print_newline
    mov si, menu
    call print_string_green
    call print_newline
    ret

print_help:
    mov si, menu
    call print_string_green
    call print_newline
    jmp get_cmd

print_info:
    mov si, info
    call print_string_green
    call print_newline
    jmp get_cmd

; ===================== Command Line Interpreter =====================

shell:
    mov si, version_msg
    call print_string
    call print_newline

get_cmd:
    mov si, prompt
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
    mov si, command
    mov di, kern_file_string
    mov cx, 6
    call string_string_strincmp
    jc no_kernel_allowed

    mov ax, 0
    mov bx, 0
    mov cx, 0
    mov dx, 0
    mov word si, [param_list]
    mov di, 0

    call 32768

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
    pusha
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
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret

do_reboot:
    int 0x19
    ret

; ===================== File Operation Functions =====================

list_directory:
    call print_newline

    mov cx, 0
    mov ax, dirlist
    call fs_get_file_list
    mov word [file_count], dx         ; Store file count

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
    mov bl, 0x0F                      ; Set color to white
    int 10h
    jmp .repeat

.done:
    call print_newline
    call print_newline
    mov ax, [file_count]
    call string_int_to_string
    mov si, ax
    call print_string_cyan
    mov si, files_msg
    call print_string
    call print_newline
    call print_newline
    jmp get_cmd

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
    call fs_remove_file
    jc .failure
    mov si, .success_msg
    call print_string_green
    call print_newline
    jmp get_cmd

.failure:
    mov si, .failure_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.success_msg db 'Deleted file.', 0
.failure_msg db 'Could not delete file - does not exist or write protected', 0

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
    call print_newline
    jmp get_cmd

.failure:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    jmp get_cmd

.size_msg db 'Size (in bytes) is: ', 0

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

%INCLUDE "src/kernel/features/fs.asm"
%INCLUDE "src/kernel/features/string.asm"
%INCLUDE "src/kernel/features/speaker.asm"

; ====== API ======
%INCLUDE "src/kernel/features/api/api_output.asm"
%INCLUDE "src/kernel/features/api/api_fs.asm"
%INCLUDE "src/kernel/features/api/api_string.asm"
; =================

; ===================== Data Section =====================

; ------ Header ------
header db '============================= x16 PRos v0.4 ====================================', 0

; ------ Help menu ------
menu db 0xC9, 76 dup(0xCD), 0xBB, 10, 13
     db 0xBA, ' x16 PRos Commands Manual   ', 48 dup(' '), 0xBA, 10, 13
     db 0xC7, 76 dup(0xC4), 0xB6, 10, 13
     db 0xBA, ' System Commands:                                                           ', 0xBA, 10, 13
     db 0xBA, '   cls           Clear the terminal screen                                  ', 0xBA, 10, 13
     db 0xBA, '   shut          Power off the system                                       ', 0xBA, 10, 13
     db 0xBA, '   reboot        Restart the system                                         ', 0xBA, 10, 13
     db 0xBA, '   exit          Return to boot loader                                      ', 0xBA, 10, 13
     db 0xBA, ' Information Commands:                                                      ', 0xBA, 10, 13
     db 0xBA, '   help          Display this command menu                                  ', 0xBA, 10, 13
     db 0xBA, '   info          Show system information                                    ', 0xBA, 10, 13
     db 0xBA, '   ver           Display PRos terminal version                              ', 0xBA, 10, 13
     db 0xBA, '   cpu           Display CPU details                                        ', 0xBA, 10, 13
     db 0xBA, '   date          Show current date (DD/MM/YY)                               ', 0xBA, 10, 13
     db 0xBA, '   time          Show current time (HH:MM:SS)                               ', 0xBA, 10, 13
     db 0xBA, ' File Operations:                                                           ', 0xBA, 10, 13
     db 0xBA, '   dir           List files on disk                                         ', 0xBA, 10, 13
     db 0xBA, '   cat <file>    Display file contents                                      ', 0xBA, 10, 13
     db 0xBA, '   size <file>   Show file size in bytes                                    ', 0xBA, 10, 13
     db 0xBA, '   touch <file>  Create an empty file                                       ', 0xBA, 10, 13
     db 0xBA, '   del <file>    Delete a file                                              ', 0xBA, 10, 13
     db 0xBA, '   ren <f1> <f2> Rename a file                                              ', 0xBA, 10, 13
     db 0xBA, '   copy <f1> <f2> Copy a file                                               ', 0xBA, 10, 13
     db 0xBA, '   write <file> <text> Write text to a file                                 ', 0xBA, 10, 13
     db 0xC0, 76 dup(0xCD), 0xBC, 10, 13, 0

; ------ About OS ------
info db 10, 13
     db 0xC9, 46 dup(0xCD), 0xBB, 10, 13
     db 0xBA, '  x16 PRos is the simple 16 bit operating     ', 0xBA, 10, 13
     db 0xBA, '  system written in NASM for x86 PC`s         ', 0xBA, 10, 13
     db 0xC3, 46 dup(0xC4), 0xB4, 10, 13
     db 0xBA, '  Autor: PRoX (https://github.com/PRoX2011)   ', 0xBA, 10, 13
     db 0xBA, '  Disk size: 1.44 MB                          ', 0xBA, 10, 13
     db 0xBA, '  Video mode: 0x12 (640x480; 16 colors)       ', 0xBA, 10, 13
     db 0xBA, '  File system: FAT12                          ', 0xBA, 10, 13
     db 0xBA, '  License: MIT                                ', 0xBA, 10, 13
     db 0xBA, '  OS version: 0.4                             ', 0xBA, 10, 13
     db 0xC0, 46 dup(0xCD), 0xBC, 10, 13
     db 0

version_msg db 'PRos terminal v0.2', 10, 13, 0

; ------ Commands ------
exit_string db 'EXIT', 0
help_string db 'HELP', 0
info_string db 'INFO', 0
cls_string db 'CLS', 0
dir_string db 'DIR', 0
ver_string db 'VER', 0
time_string db 'TIME', 0
date_string db 'DATE', 0
cat_string db 'CAT', 0
del_string db 'DEL', 0
copy_string db 'COPY', 0
ren_string db 'REN', 0
size_string db 'SIZE', 0
shut_string db 'SHUT', 0
reboot_string db 'REBOOT', 0
cpu_string db 'CPU', 0
touch_string db 'TOUCH', 0
write_string db 'WRITE', 0

; ------ Errors ------
invalid_msg db 'No such command or program', 0
nofilename_msg db 'No filename or not enough filenames', 0
notfound_msg db 'File not found', 0
writefail_msg db 'Could not write file. Write protected or invalid filename?', 0
exists_msg db 'Target file already exists!', 0
kern_file_string db 'KERNEL', 0
kern_warn_msg db 'Cannot execute kernel file!', 0
notext_msg db 'No text provided for writing', 0

; ------ CPU info ------
cpu_name db '  CPU name: ', 0
cores db '  CPU cores: ', 0
stepping db '  Stepping ID: ', 0
cache_line db '  Cache line: ', 0
time_msg db 'Current time: ', 0
date_msg db 'Current date: ', 0

; ------ Disk usage ------
files_msg db ' files              ', 0
bytes_msg db ' bytes', 0
free_space_msg db '                      ', 0
free_capacity_msg db ' / 1474560 bytes free', 0

; ------ Sounds ------
start_melody:
    dw 1811, 250
    dw 1015, 250
    dw 761, 250
    dw 0, 0

shut_melody:
    dw 761, 250
    dw 1015, 250
    dw 1811, 250
    dw 0, 0

; ------ Buffers ------
input times 256 db 0
command times 32 db 0
dirlist times 1024 db 0
tmp_string times 15 db 0
disk_buffer times 8192 db 0
file_buffer times 32768 db 0

file_size dw 0
param_list dw 0
bin_extension db '.BIN', 0
total_file_size dd 0
file_count dw 0

prompt db '[PRos] > ', 0
mt db '', 10, 13, 0
Sides dw 2
SecsPerTrack dw 18
bootdev db 0
fmt_date dw 1
