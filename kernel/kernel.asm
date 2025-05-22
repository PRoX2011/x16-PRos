; ==================================================================
; x16-PRos -- The x16-PRos Operating System kernel
; Copyright (C) 2025 PRoX2011
;
; This is loaded from the second disk sector by boot.bin
; ==================================================================

; %include "../fs.inc"

[BITS 16]
[ORG 500h]

%include "fs.inc"

start:
    cli
    call set_video_mode 

    ; Set up frequency (1193180 Hz / 1193 = ~1000 Hz)
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al

    call print_interface ; Help menu and headler

    mov si, start_melody
    call play_melody     ; Sturtup sound

    call shell           ; PRos terminal
    jmp $

set_video_mode:
    ; VGA 640*460, 16 colors
    mov ax, 0x12
    int 0x10
    ret

print_string:
    mov ah, 0x0E
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ------ Wait 1 second using BIOS delay (CX:DX = microseconds) ------
one_sec_dealy:
    mov cx, 0x000F
    mov dx, 0x4240
    mov ah, 0x86
    int 0x15
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
    ret

shell:
    mov si, prompt
    call print_string
    call read_command
    call print_newline
    call execute_command
    jmp shell

; ===================== Shell =====================

read_command:
    mov di, command_buffer
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, 255
    jge .done_read
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp di, command_buffer
    je .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0
    ret

execute_command:
    mov si, command_buffer
    ; Checking the command "help"
    mov di, help_str
    call compare_strings
    je do_help
    
    mov si, command_buffer
    ; Checking the command "info"
    mov di, info_str
    call compare_strings
    je print_OS_info

    mov si, command_buffer
    ; Checking the command "cls"
    mov di, cls_str
    call compare_strings
    je do_cls
    
    mov si, command_buffer
    ; Checking the command "CPU"
    mov di, CPU_str
    call compare_strings
    je do_CPUinfo

    mov si, command_buffer
    ; Checking the command "disk-i"
    mov di, disk_info_str
    call compare_strings
    je display_disk_info
    
    mov si, command_buffer
    ; Checking the command "date"
    mov di, date_str
    call compare_strings
    je print_date
    
    mov si, command_buffer
    ; Checking the command "time"
    mov di, time_str
    call compare_strings
    je print_time

    mov si, command_buffer
    ; Checking the command "shut"
    mov di, shut_str
    call compare_strings
    je do_shutdown
    
    mov si, command_buffer
    ; Checking the command "reboot"
    mov di, reboot_str
    call compare_strings
    je do_reboot
   
    mov si, command_buffer
    ; Checking the command "writer"
    mov di, writer_str
    call compare_strings
    je start_writer
    
    mov si, command_buffer
    ; Checking the command "brainf"
    mov di, brainf_str
    call compare_strings
    je start_brainf
    
    mov si, command_buffer
    ; Checking the command "barchart"
    mov di, barchart_str
    call compare_strings
    je start_barchart
    
    mov si, command_buffer
    ; Checking the command "snake"
    mov di, snake_str
    call compare_strings
    je start_snake
    
    mov si, command_buffer
    ; Checking the command "calc"
    mov di, calc_str
    call compare_strings
    je start_calc
    
    mov si, command_buffer
    ; Checking the command "disk-tools"
    mov di, disk_tools_str
    call compare_strings
    je start_disk_tools
    
    mov si, command_buffer
    ; Checking the command "BASIC"
    mov di, BASIC_str
    call compare_strings
    je start_BASIC

    mov si, command_buffer
    ; Checking the command "mine"
    mov di, mine_str
    call compare_strings
    je start_mine

    mov si, command_buffer
    ; Checking the command "memory"
    mov di, memory_str
    call compare_strings
    je start_memory

    mov si, command_buffer
    ; Checking the command "space"
    mov di, space_str
    call compare_strings
    je start_space

    mov si, command_buffer
    ; Checking the command "piano"
    mov di, piano_str
    call compare_strings
    je start_piano
    
    mov si, command_buffer
    ; Checking the command "load"
    mov di, load_str
    call compare_strings
    je load_program

    call unknown_command
    ret

compare_strings:
    xor cx, cx
.next_char:
    lodsb
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal
    inc di
    jmp .next_char
.not_equal:
    ret
.equal:
    ret

; ===================== Other =====================

do_banner:
    call print_interface
    call print_newline
    ret

do_help:
    call print_newline
    call print_help
    call print_newline
    ret

do_cls:
    pusha
    mov ax, 0x12
    int 0x10
    popa
    ret

unknown_command:
    mov si, unknown_msg
    call print_string_red
    call print_newline
    ret

do_shutdown:
    mov si, shut_melody
    call play_melody     ; Shutdown sound
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret
    
do_reboot:
    int 0x19
    ret

; ------ Print information about OS ------   
print_OS_info:
    mov si, info
    call print_string_green
    call print_newline
    ret
       
;===================== Functions for running programs =====================

; AL - number of disk sectors to read
; CH - track number
; DH - head number
; CL - disk sector number
; BX - download adress

; ------ Writer program (write.asm) ------
start_writer:
    pusha
    mov ah, 0x02
    mov al, SIZE_WRITER
    mov ch, 0
    mov dh, 0
    mov cl, START_WRITER
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Brainf program (brainf.asm) ------   
start_brainf:
    pusha
    mov ah, 0x02
    mov al, SIZE_BRAINF
    mov ch, 0
    mov dh, 0
    mov cl, START_BRAINF
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Barchart program (barchart.asm) ------  
start_barchart:
    pusha
    mov ah, 0x02
    mov al, SIZE_BARCHART
    mov ch, 0
    mov dh, 0
    mov cl, START_BARCHART
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Snake game (snake.asm) ------  
start_snake:
    pusha
    mov ah, 0x02
    mov al, SIZE_SNAKE
    mov ch, 0
    mov dh, 0
    mov cl, START_SNAKE
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Calculator program (calc.asm) ------   
start_calc:
    pusha
    mov ah, 0x02
    mov al, SIZE_CALC
    mov ch, 0
    mov dh, 0
    mov cl, START_CALC
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Disk-tools utility (disk-tools.asm) ------   
start_disk_tools:
    push bx
    mov ah, 0x02
    mov al, SIZE_DISK_TOOLS
    mov ch, 0
    mov dh, 0
    mov cl, START_DISK_TOOLS
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    pop bx
    ret

; ------ micro BASIC programing language (https://github.com/PRoX2011/micro-BASIC/blob/main/SRC/ILM.ASM) ------  
start_BASIC:
    mov ax, 0x02
    int 0x10
    pusha
    mov ah, 0x02
    mov al, 9
    mov ch, 0
    mov dh, 0
    mov cl, 27
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Minesweeper game (mine.asm) ------
start_mine:
    mov ax, 0x02
    int 0x10
    pusha
    mov ah, 0x02
    mov al, SIZE_MINE
    mov ch, 0
    mov dh, 0
    mov cl, START_MINE
    mov bx, 900h
    int 0x13
    jc .disk_error
    jmp 900h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Memory viewer program (memory.asm) ------
start_memory:
    mov ax, 0x02
    int 0x10
    pusha
    mov ah, 0x02
    mov al, SIZE_MEMORY
    mov ch, 0
    mov dh, 0
    mov cl, START_MEMORY
    mov bx, 900h ; I use specical program offset. It doesn't work any other way. Idk why
    int 0x13
    jc .disk_error
    jmp 900h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Space arcade game (space.asm) ------
start_space:
    pusha
    mov ah, 0x02
    mov al, SIZE_SPACE
    mov ch, 0
    mov dh, 0
    mov cl, START_SPACE
    mov bx, 900h
    int 0x13
    jc .disk_error
    jmp 900h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ------ Piano program (piano.asm) ------
start_piano:
    pusha
    mov ah, 0x02
    mov al, SIZE_PIANO
    mov ch, 0
    mov dh, 0
    mov cl, START_PIANO
    mov bx, 900h
    int 0x13
    jc .disk_error
    jmp 900h
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ===================== CPU info functions ===================== 
print_edx:
    mov ah, 0eh
    ; mov bh, 0 (Use it for very old BIOS)
    mov bx, 4
    loop4r:
        mov al, dl
        int 10h
        ror edx, 8

        dec bx
        cmp bx, 0
        jne loop4r
    ret
    
print_full_name_part:
    cpuid
    push edx
    push ecx
    push ebx
    push eax

    mov cx, 4
loop4n:
    pop edx
    call print_edx

    dec cx
    cmp cx, 0
    jne loop4n

    ret

; ------ Print CPU cores number ------
print_cores:
    mov si, cores
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 16
    mov al, bl
    call print_al
    ret

; ------ Print CPU cache line ------
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

; ------ Print CPU stepping ID ------
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

; ------- Print all CPU information ------   
do_CPUinfo:
    pusha
    mov si, cpu_name
    call print_string
    ; Displaying information about the CPU
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
    ret

; ------ CPU ------
cpu_name       db '  CPU name: ', 0
cores          db '  CPU cores: ', 0
stepping       db '  Stepping ID: ', 0
cache_line     db '  Cache line: ', 0

; ===================== Date and time functions =====================

; Function for displaying date
; Displays date in DD.MM.YY format
print_date:
    mov si, date_msg
    call print_string
    
    pusha
    ; Get the date: ch - century, cl - year, dh - month, dl - day
    mov ah, 0x04
    int 0x1a

    mov ah, 0x0e

    ; Print day (dl)
    mov al, dl
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, dl
    and al, 0x0F
    add al, '0'
    int 0x10

    ; Print dot
    mov al, '.'
    mov bl, 0x0B
    int 0x10

    ; Print mounth (dh)
    mov al, dh
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, dh
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10

    ; Print dot
    mov al, '.'
    mov bl, 0x0B
    int 0x10

    ; Print year (cl)
    mov al, cl
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, cl
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10
    
    mov si, mt
    call print_string
    
    popa
    ret
    

; Function for displaying time
; Displays date in HH.MM.SS format
print_time:
    mov si, time_msg
    call print_string
    
    pusha
    ; Get time: ch - hours, cl - minutes, dh - seconds
    mov ah, 0x02
    int 0x1a

    mov ah, 0x0e 

    ; Print hours (ch)
    mov al, ch
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, ch
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10

    ; Print separator
    mov al, ':'
    mov bl, 0x0B
    int 0x10

    ; Print minutes (cl)
    mov al, cl
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, cl
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10

    ; Print separator
    mov al, ':'
    mov bl, 0x0B
    int 0x10

    ; Print seconds (dh)
    mov al, dh
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, dh
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10
    
    mov si, mt
    call print_string
    
    popa
    ret

; ------ Date & time ------
time_msg       db 'Current time: ', 0
date_msg       db 'Current date: ', 0
    

; ===================== Load Command functions =====================

load_program:
    mov si, load_prompt
    call print_string
    call read_number
    call print_newline

    call start_program
    ret

; ------ Read number input ------

read_number:
    mov di, number_buffer
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, 5
    jge .read_loop
    cmp al, '0'
    jb .read_loop
    cmp al, '9'
    ja .read_loop
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp cx, 0
    je .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08 
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0
    call convert_to_number
    ret

; ------ Convert ASCII to number ------

convert_to_number:
    mov si, number_buffer
    xor ax, ax
    xor cx, cx
.convert_loop:
    lodsb
    cmp al, 0
    je .done_convert
    sub al, '0'
    imul cx, 10
    add cx, ax
    jmp .convert_loop
.done_convert:
    mov [sector_number], cx
    ret

convert_ah_to_hex:
    push ax
    push bx
    mov bx, hex_nums

    ; Convert high nibble
    mov al, ah
    shr al, 4
    xlatb
    mov [error_code_hex], al

    ; Convert low nibble
    mov al, ah
    and al, 0x0F
    xlatb
    mov [error_code_hex+1], al

    pop bx
    pop ax
    ret

; ------ Start program from the disk sec ------

start_program:
    pusha
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, [sector_number]
    mov bx, 800h
    int 0x13
    jc .disk_error
    jmp 800h
    ret

.disk_error:
    mov si, error_sound
    call play_melody

    push ax
    call convert_ah_to_hex
    mov si, disk_error_msg
    call print_string_red
    mov al, [error_code_hex]
    call print_char_red
    mov al, [error_code_hex+1]
    call print_char_red
    call print_newline
    pop ax
    popa
    ret

print_char_red:
    mov ah, 0x0E
    mov bl, 0x0C
    int 0x10
    ret

load_prompt    db 'Enter sector number: ', 0
disk_error_msg db 'Disk error! Error code: 0x', 0
error_code_hex db '00', 0
hex_nums db "0123456789ABCDEF"
number_buffer  db 6 dup(0)
sector_number  dw 0

; ===================== Colored prints =====================

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

; ------ Print decimal number ------
print_number:
    pusha
    xor cx, cx
    mov bx, 10
    xor dx, dx
.next_digit:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .next_digit
.print_digits:
    pop dx
    add dl, '0'
    mov ah, 0x0E
    mov al, dl
    int 0x10
    loop .print_digits
    mov ah, 0x0E
    mov al, ' '
    int 0x10
    popa
    ret

; Print AL as 2-digit hex number
print_hex_byte:
    push ax
    push cx
    
    mov cl, 4
    mov ah, al
    
    shr al, cl
    call .print_nibble
    
    mov al, ah
    and al, 0x0F
    call .print_nibble
    
    pop cx
    pop ax
    ret
    
.print_nibble:
    cmp al, 10
    jl .digit
    add al, 'A' - 10 - '0'
.digit:
    add al, '0'
    call print_char
    ret

print_char:
    pusha 
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    popa
    ret

; ===================== Disk information =====================

; ------------------------------------------
; Get Disk Parameters
; Input: DL = drive number (0x80, etc.)
; Output: CF=0 on success, CF=1 on error
;         On success:
;           - [lba_support] = 1 if LBA supported
;           - CHS params filled (if available)
; Modifies: AX, BX, CX, DX
; ------------------------------------------
get_disk_params:
    push es
    push di
    push si

    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc .no_lba
    
    mov byte [lba_support], 1
    
    mov ah, 0x48
    mov si, disk_parameters_packet
    int 0x13
    jnc .lba_success
    
.no_lba:
    mov byte [lba_support], 0
    mov ah, 0x08
    int 0x13
    jc .error
    
    mov [disk_count], dl
    
    mov al, ch
    mov ah, cl
    shr ah, 6
    mov [cylinder], ax
    
    xor ax, ax
    mov al, dh
    inc ax
    mov [heads], ax
    
    mov al, cl
    and al, 0x3F
    mov [sectors], ax
    
    mul word [heads]
    mul word [cylinder]
    mov [total_sectors], ax
    mov [total_sectors+2], dx
    
    clc
    jmp .done

.lba_success:
    mov eax, [disk_parameters_packet+4]
    mov [cylinder], ax
    mov eax, [disk_parameters_packet+8]
    mov [heads], ax
    mov eax, [disk_parameters_packet+12]
    mov [sectors], ax
    
    cmp word [cylinder], 0
    jne .done
    mov word [cylinder], 1024
    mov word [heads], 16
    mov word [sectors], 63

.error:
    stc

.done:
    pop si
    pop di
    pop es
    ret

; ------ Display Disk Information ------
display_disk_info:
    mov si, disk_info_msg
    call print_string
    
    call get_disk_params
    jc .error
    
    mov si, lba_support_msg
    call print_string
    cmp byte [lba_support], 1
    je .lba_yes
    mov si, no_msg
    call print_string_red
    jmp .show_chs
.lba_yes:
    mov si, yes_msg
    call print_string_green
.show_chs:
    mov si, chs_params_msg
    call print_string
    mov si, cylinders_msg
    call print_string
    mov ax, [cylinder]
    call print_number
    mov si, heads_msg
    call print_string
    mov ax, [heads]
    call print_number
    mov si, sectors_msg
    call print_string
    mov ax, [sectors]
    call print_number
    call print_newline
    ret

.error:
    mov si, error_sound
    call play_melody

    mov si, disk_info_error_msg
    call print_string_red
    call print_newline
    ret

disk_info_msg      db " Disk Information:", 13, 10, 0

lba_support_msg    db "  LBA Supported: ", 0
yes_msg            db "Yes",13,10,0
no_msg             db "No",13,10,0
total_sectors_msg  db "  Total Sectors: ",0
chs_params_msg     db "  CHS Parameters:",13,10,0
cylinders_msg      db "   Cylinders: ",0
heads_msg          db 13,10,"   Heads: ",0

sectors_msg        db 13,10,"   Sectors per track: ", 0
                   

disk_info_error_msg     db "Error reading disk parameters!",0

disk_parameters_packet:
    dw 0x001A      ; Size of packet
    dw 0           ; Information flags
    dd 0           ; Number of cylinders
    dd 0           ; Number of heads
    dd 0           ; Sectors per track
    dq 0           ; Total sectors (TODO)
    dw 0           ; Bytes per sector

lba_support      db 0
disk_count       db 0
cylinder         dw 0
heads            dw 0
sectors          dw 0
total_sectors    dd 0

; ===================== PC speaker functions =====================

; ------ Turn on the speaker ------
on_pc_speaker:
    pusha
    in al, 0x61
    or al, 0x03
    out 0x61, al
    popa
    ret

; ------ Turn off the speaker ------
off_pc_speaker:
    pusha
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

; ------ Startup sound ------
play_melody:
    pusha
    ; mov si, melody
.next_note:
    mov ax, [si]
    cmp ax, 0
    je .done
    mov dx, [si+2]
    add si, 4
    call set_frequency
    call on_pc_speaker
    call delay_ms
    call off_pc_speaker
    jmp .next_note
.done:
    popa
    ret

set_frequency:
    push ax
    mov al, 0xB6
    out 0x43, al
    pop ax
    out 0x42, al
    mov al, ah
    out 0x42, al
    ret

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

; ------ Sounds ------
start_melody:
    dw 1811, 250   ; E5
    dw 1015, 250   ; D6
    dw 761, 250    ; G6
    dw 0, 0        ; Melody end

shut_melody:
    dw 761, 250    ; G6
    dw 1015, 250   ; D6
    dw 1811, 250   ; E5
    dw 0, 0        ; Melody end

error_sound:
    dw 2415, 250   ; B4
    dw 2415, 250   ; B4
    dw 0, 0        ; Melody end

; ===================== Data section =====================

; ------ Help menu and headler ------
header db '============================= x16 PRos v0.3 ====================================', 0
menu db 0xC9, 47 dup(0xCD), 0xBB, 10, 13  ; ╔═══════════════════════════════════════════════╗
     db 0xBA, 'Commands:                                      ', 0xBA, 10, 13  ; ║ ... ║
     db 0xBA, '  help - get list of the commands              ', 0xBA, 10, 13
     db 0xBA, '  info - print information about OS            ', 0xBA, 10, 13
     db 0xBA, '  cls - clear terminal                         ', 0xBA, 10, 13
     db 0xBA, '  shut - shutdown PC                           ', 0xBA, 10, 13
     db 0xBA, '  reboot - go to bootloader (restart system)   ', 0xBA, 10, 13
     db 0xBA, '  date - print current date (DD.MM.YY)         ', 0xBA, 10, 13
     db 0xBA, '  time - print current time (HH.MM.SS)         ', 0xBA, 10, 13
     db 0xBA, '  CPU - print CPU info                         ', 0xBA, 10, 13
     db 0xBA, '  disk-i - print disk info                     ', 0xBA, 10, 13
     db 0xBA, '  load - load program from disk sector         ', 0xBA, 10, 13
     db 0xBA, '  writer - text editor                         ', 0xBA, 10, 13
     db 0xBA, '  brainf - brainf IDE                          ', 0xBA, 10, 13
     db 0xBA, '  barchart - charting soft (by Loxsete)        ', 0xBA, 10, 13
     db 0xBA, '  snake - snake game                           ', 0xBA, 10, 13
     db 0xBA, '  calc - calculator program (by Saeta)         ', 0xBA, 10, 13
     db 0xBA, '  disk-tools - disk utility (disk 0x80)        ', 0xBA, 10, 13
     db 0xBA, '  BASIC - start micro-BASIC interpriter        ', 0xBA, 10, 13
     db 0xBA, '  mine - minesweeper game                      ', 0xBA, 10, 13
     db 0xBA, '  memory - memory viewer program               ', 0xBA, 10, 13
     db 0xBA, '  space - space arcade game (by Qwez)          ', 0xBA, 10, 13
     db 0xBA, '  piano - simple piano program                 ', 0xBA, 10, 13
     db 0xC8, 47 dup(0xCD), 0xBC, 10, 13  ; ╚══════════════════════════════════════════════╝
     db 0

; ------ About OS ------
info db 10, 13
     db 0xC9, 46 dup(0xCD), 0xBB, 10, 13  ; ╔══════════════════════════════════════════════╗
     db 0xBA, '  x16 PRos is the simple 16 bit operating     ', 0xBA, 10, 13  ; ║ ... ║
     db 0xBA, '  system written in NASM for x86 PC`s         ', 0xBA, 10, 13
     db 0xC7, 46 dup(0xC4), 0xB6, 10, 13  ; ╟──────────────────────────────────────────────╢
     db 0xBA, '  Autor: PRoX (https://github.com/PRoX2011)   ', 0xBA, 10, 13
     db 0xBA, '  Amount of disk sectors: 50                  ', 0xBA, 10, 13
     db 0xBA, '  Video mode: 0x12 (640x480; 16 colors)       ', 0xBA, 10, 13
     db 0xBA, '  License: MIT                                ', 0xBA, 10, 13
     db 0xBA, '  OS version: 0.3.7 (Graphic & Sound)         ', 0xBA, 10, 13
     db 0xC8, 46 dup(0xCD), 0xBC, 10, 13  ; ╚══════════════════════════════════════════════╝
     db 0

; ------ Comands -------
help_str       db 'help', 0
info_str       db 'info', 0
cls_str        db 'cls', 0
shut_str       db 'shut', 0
reboot_str     db 'reboot', 0
CPU_str        db 'CPU', 0
disk_info_str  db 'disk-i', 0
date_str       db 'date', 0
time_str       db 'time', 0
load_str       db 'load', 0
writer_str     db 'writer', 0
brainf_str     db 'brainf', 0
barchart_str   db 'barchart', 0
snake_str      db 'snake', 0
calc_str       db 'calc', 0
disk_tools_str db 'disk-tools', 0
BASIC_str      db 'BASIC', 0
mine_str       db 'mine', 0
memory_str     db 'memory', 0
space_str      db 'space', 0
piano_str      db 'piano', 0

; ------ Other ------
unknown_msg    db 'Unknown command.', 0
prompt         db '[PRos] > ', 0
mt             db '', 10, 13, 0
buffer         db 512 dup(0)
command_buffer db 128 dup(0)