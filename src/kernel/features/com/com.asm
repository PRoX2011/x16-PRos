; ==================================================================
; x16-PRos - Compatibility layer with MS DOS programs.
;            Emulates MS DOS system calls through PRos kernel functions
;
; https://wiki.osdev.org/COM
; https://en.wikipedia.org/wiki/COM_file
; https://en.wikipedia.org/wiki/DOS_API
; https://biosprog.narod.ru/real/dos/ints.htm 
;
; ------------ DOS system calls ------------
;  [DONE] Function 00h: Terminate program
;  [DONE] Function 01h: Read character with echo
;  [DONE] Function 02h: Write character
;  [DONE] Function 03h: Read character from COM1 (auxiliary device)
;  [DONE] Function 04h: Write character to COM1 (auxiliary device)
;  [DONE] Function 05h: Print character to printer
;  [DONE] Function 06h: Direct console input/output (unfiltered)
;  [DONE] Function 07h: Direct console input (no echo)
;  [DONE] Function 08h: Console input without echo
;  [DONE] Function 09h: Output string ($-terminated)
;  [DONE] Function 0Ah: Buffered keyboard input
;  [DONE] Function 0Bh: Check keyboard status / input available
;  [DONE] Function 0Ch: Clear keyboard buffer and read input
;  [DONE] Function 0Dh: Disk reset / flush buffers
;  [DONE] Function 0Eh: Select default drive
;  [DONE] Function 0Fh: Open file using FCB
;  [DONE] Function 10h: Close file using FCB
;  Function 11h: Search for first matching file using FCB
;  Function 12h: Search for next matching file using FCB
;  [DONE] Function 13h: Delete file using FCB
;  Function 14h: Sequential read using FCB
;  Function 15h: Sequential write using FCB
;  [DONE] Function 16h: Create file using FCB
;  [DONE] Function 17h: Rename file using FCB
;  Function 18h: [RESERVED]
;  [DONE] Function 19h: Get current default drive
;  [DONE] Function 1Ah: Set DTA (Disk Transfer Area) address
;  Function 1Bh: Get FAT information for default drive
;  Function 1Ch: Get FAT information for any drive
;  Function 1Dh: [RESERVED]
;  Function 1Eh: [RESERVED]
;  Function 1Fh: Get drive parameters (default drive)
;  Function 20h: [RESERVED]
;  Function 21h: Random read using FCB
;  Function 22h: Random write using FCB
;  Function 23h: Get file size using FCB
;  Function 24h: Set random record number in FCB
;  [DONE] Function 25h: Set interrupt vector
;  [DONE] Function 26h/55h: Create PSP (Program Segment Prefix)
;  Function 27h: Random block read using FCB
;  Function 28h: Random block write using FCB
;  [DONE] Function 29h: Parse filename and build FCB
;  [DONE] Function 2Ah: Get system date
;  [DONE] Function 2Bh: Set system date
;  [DONE] Function 2Ch: Get system time
;  [DONE] Function 2Dh: Set system time
;  Function 2Eh: Set/Reset verify switch
;  [DONE] Function 2Fh: Get current DTA address
;  [DONE] Function 30h: Get DOS version number
;  Function 31h: Terminate and stay resident (TSR)
;  Function 32h: Get DOS drive information (undocumented)
;  [DONE] Function 50h: Set current PSP
;  [DONE] Function 51h: Get current PSP
;  [DONE] Function 52h: Get List of Lists (undocumented)
;  [DONE] Function 33h: Get/Set Ctrl+C / Ctrl+Break handling
;  [DONE] Function 34h: Get address of InDOS flag (undocumented)
;  [DONE] Function 35h: Get interrupt vector
;  [DONE] Function 36h: Get free disk space
;  Function 37h: Get/Set switch character (undocumented)
;  Function 38h: Get/Set country information
;  [DONE] Function 39h: Create subdirectory (MKDIR)
;  [DONE] Function 3Ah: Remove subdirectory (RMDIR)
;  [DONE] Function 3Bh: Change current directory (CHDIR)
;  [DONE] Function 3Ch: Create file
;  [DONE] Function 3Dh: Open file
;  [DONE] Function 3Eh: Close file
;  [DONE] Function 3Fh: Read from file/device
;  [DONE] Function 40h: Write to file/device
;  [DONE] Function 41h: Delete file
;  [DONE] Function 42h: Move file pointer (seek)
;  [DONE] Function 43h: Get/Set file attributes
;  [DONE] Function 44h: I/O control for devices (IOCTL)
;  [DONE] Function 45h: Duplicate file handle
;  [DONE] Function 46h: Force duplicate file handle
;  [DONE] Function 47h: Get current directory path
;  [DONE] Function 48h: Allocate memory block
;  [DONE] Function 49h: Free allocated memory block
;  [DONE] Function 4Ah: Resize memory block
;  [DONE] Function 4Bh: Load/Execute program (EXEC)
;  [DONE] Function 4Ch: Terminate program with return code
;  [DONE] Function 4Dh: Get program return code
;  [DONE] Function 4Eh: Find first matching file (FindFirst)
;  [DONE] Function 4Fh: Find next matching file (FindNext)
;  [DONE] Function 54h: Get verify flag
;  [DONE] Function 56h: Rename/move file
;  [DONE] Function 57h: Get/Set file date and time
;  [DONE] Function 59h: Get extended error information
;  [DONE] Function 5Dh: Get swappable data area (DOS 3)
;  [DONE] Function 5Ah: Create a temporary file
;  [DONE] Function 5Bh: Create new file (fails if already exists)
;  Function 5Ch: Lock/Unlock file region (record locking)
;  Function 5Eh: Various network functions
;  Function 5Fh: Network redirection functions
;  [DONE] Function 62h: Get PSP (Program Segment Prefix) address
;  [DONE] Function 68h: Commit file (flush buffers)
;  Function 6Ch: Extended open/create file
; ---------------------------------------------
;
; ==================================================================

int2F_handler:
    xor al, al
    iret

; ==================================================================
; DOS_TERMINATE_TASK - end one process and return to its parent.
; ==================================================================
dos_terminate_task:
    cli

    push ax
    mov ax, [cs:dos_current_psp]
    call dosmem_free_owner
    pop ax

    mov es, [cs:dos_current_psp]

    push es
    mov es, [es:0x16]
    mov ax, [es:0x2E]
    mov [cs:dos_term_sp], ax
    mov ax, [es:0x30]
    mov [cs:dos_term_ss], ax
    pop es

    xor ax, ax
    mov ds, ax

    mov ax, [0x22 * 4]
    mov [cs:dos_term_addr], ax
    mov ax, [0x22 * 4 + 2]
    mov [cs:dos_term_addr + 2], ax

    mov ax, [es:0x16]
    mov [cs:dos_current_psp], ax
    call dosvars_stamp_psp
    mov ds, ax
    mov es, ax

    mov ax, [cs:dos_term_ss]
    test ax, ax
    jz .caller_stack

    mov ss, ax
    mov sp, [cs:dos_term_sp]

    mov bp, sp
    mov ax, [cs:dos_term_addr]
    mov [bp + 18], ax
    mov ax, [cs:dos_term_addr + 2]
    mov [bp + 20], ax
    mov word [bp + 22], 0x0202

    pop ax
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop bp
    pop ds
    pop es
    iret

.caller_stack:
    mov ss, [cs:dos_entry_ss]
    mov sp, [cs:dos_entry_sp]
    add sp, 4
    sti
    jmp far [cs:dos_term_addr]

dos_term_addr dw 0, 0
dos_term_sp   dw 0
dos_term_ss   dw 0
dos_entry_sp  dw 0
dos_entry_ss  dw 0

; ==================================================================
; INT 20h - Terminate program.
; The same ending as AH = 4Ch, so it goes there.
; ==================================================================
int20_handler:
    cli
    cld
    jmp dos_terminate

dos_terminate:
    push ds
    push ax
    mov ds, [cs:dos_current_psp]
    mov ax, [0x16]
    test ax, ax
    jz .decided

    mov ds, ax
    mov ax, [0x16]
    test ax, ax

.decided:
    pop ax
    pop ds
    jnz dos_terminate_task

    cmp byte [cs:com_active], 0
    jne .com_teardown

    mov ax, 0x12
    int 0x10
    jmp launch_bin_program.program_done

.com_teardown:
    mov byte [cs:com_active], 0
    mov word [cs:dos_current_psp], EXE_PSP_SEG

    call dosfile_close_all

    push ds
    push es
    push si
    push di
    push cx

    xor ax, ax
    mov es, ax
    mov ax, 0x2000
    mov ds, ax

    mov si, saved_interrupt_table
    xor di, di
    mov cx, 512
    rep movsw

    pop cx
    pop di
    pop si
    pop es
    pop ds

    mov ax, 0x2000
    mov ds, ax
    mov es, ax

    mov ss, [com_ss_save]
    mov sp, [com_stack_save]

    sti

    call api_output_init

    mov si, .finished_msg
    mov ah, 0x01
    int 0x21

    ; Wait for key press
    mov ah, 0
    int 16h

    call api_output_init
    call set_video_mode
    call string_clear_screen
    call mouse_dos_end

    jmp get_cmd

.finished_msg db 'Program finished. Press any key to continue...', 10, 13, 0

api_dos_init:
    pusha
    push es
    push ds

    call dosmem_init
    call dosfile_init
    call dosvars_init

    xor ax, ax
    mov es, ax
    mov di, 0x0500
    mov cx, 128
    cld
    rep stosw

    push ds
    push es
    push si
    push di
    push cx

    xor ax, ax
    mov ds, ax
    mov ax, 0x2000
    mov es, ax

    xor si, si
    mov di, saved_interrupt_table
    mov cx, 512
    rep movsw

    pop cx
    pop di
    pop si
    pop es
    pop ds

    xor ax, ax
    mov es, ax
    mov word [es:0x21*4], int21_dos_handler
    mov word [es:0x21*4+2], cs

    pop ds
    pop es
    popa
    ret

int21_dos_handler:
    sti

    mov [cs:dos_entry_ss], ss
    mov [cs:dos_entry_sp], sp

    cmp ah, 0x00
    je com_00h
    cmp ah, 0x01
    je com_01h
    cmp ah, 0x02
    je com_02h
    cmp ah, 0x03
    je com_03h
    cmp ah, 0x04
    je com_04h
    cmp ah, 0x05
    je com_05h
    cmp ah, 0x06
    je com_06h
    cmp ah, 0x07
    je com_07h
    cmp ah, 0x08
    je com_08h
    cmp ah, 0x09
    je com_09h
    cmp ah, 0x0A
    je com_0Ah
    cmp ah, 0x0B
    je com_0Bh
    cmp ah, 0x0C
    je com_0Ch
    cmp ah, 0x0D
    je com_0Dh
    cmp ah, 0x0E
    je com_0Eh
    cmp ah, 0x0F
    je com_0Fh
    cmp ah, 0x10
    je com_10h
    cmp ah, 0x13
    je com_13h
    cmp ah, 0x16
    je com_16h
    cmp ah, 0x17
    je com_17h
    cmp ah, 0x19
    je com_19h
    cmp ah, 0x1A
    je com_1Ah
    cmp ah, 0x25
    je com_25h
    cmp ah, 0x26
    je com_26h
    cmp ah, 0x55
    je com_55h
    cmp ah, 0x29
    je com_29h
    cmp ah, 0x2A
    je com_2Ah
    cmp ah, 0x2C
    je com_2Ch
    cmp ah, 0x2F
    je com_2Fh
    cmp ah, 0x30
    je com_30h
    cmp ah, 0x35
    je com_35h
    cmp ah, 0x36
    je com_36h
    cmp ah, 0x39
    je com_39h
    cmp ah, 0x3A
    je com_3Ah
    cmp ah, 0x3B
    je com_3Bh
    cmp ah, 0x3C
    je com_3Ch
    cmp ah, 0x3D
    je com_3Dh
    cmp ah, 0x3E
    je com_3Eh
    cmp ah, 0x3F
    je com_3Fh
    cmp ah, 0x40
    je com_40h
    cmp ah, 0x41
    je com_41h
    cmp ah, 0x42
    je com_42h
    cmp ah, 0x43
    je com_43h
    cmp ah, 0x44
    je com_44h
    cmp ah, 0x45
    je com_45h
    cmp ah, 0x46
    je com_46h
    cmp ah, 0x47
    je com_47h
    cmp ah, 0x48
    je com_48h
    cmp ah, 0x49
    je com_49h
    cmp ah, 0x4A
    je com_4Ah
    cmp ah, 0x4B
    je com_4Bh
    cmp ah, 0x52
    je com_52h
    cmp ah, 0x5A
    je com_5Ah
    cmp ah, 0x56
    je com_56h
    cmp ah, 0x5B
    je com_5Bh
    cmp ah, 0x5D
    je com_5Dh
    cmp ah, 0x34
    je com_34h
    cmp ah, 0x50
    je com_50h
    cmp ah, 0x51
    je com_51h
    cmp ah, 0x4E
    je com_4Eh
    cmp ah, 0x4F
    je com_4Fh
    cmp ah, 0x4C
    je com_4Ch
    cmp ah, 0x4D
    je com_4Dh
    cmp ah, 0x54
    je com_54h
    cmp ah, 0x57
    je com_57h
    cmp ah, 0x59
    je com_59h
    cmp ah, 0x62
    je com_62h
    cmp ah, 0x68
    je com_68h
    cmp ah, 0x2B
    je com_2Bh
    cmp ah, 0x2D
    je com_2Dh
    cmp ah, 0x33
    je com_33h
    jmp com_unsupported


saved_interrupt_table times 1024 db 0
dta_offset            dw 0x0080
dta_segment           dw 0
verify_flag           db 0
last_return_code      db 0
last_return_type      db 0
com_tmp_drive         db 0
com_path_buffer       times 128 db 0
com_path_buffer2      times 128 db 0

; Copy ASCIIZ from caller DS:DX to kernel com_path_buffer.
; Truncates to 127 chars and always null-terminates.
; OUT: AX = com_path_buffer
com_copy_path_from_caller:
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov bx, ds
    mov es, bx
    mov ax, 0x2000
    mov ds, ax

    mov si, dx
    mov di, com_path_buffer
    mov cx, 127

.copy_loop:
    mov al, [es:si]
    mov [di], al
    cmp al, 0
    je .copy_done
    inc si
    inc di
    loop .copy_loop

    mov byte [di], 0

.copy_done:
    mov ax, com_path_buffer

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

bcd_to_bin:
    push cx
    push bx

    mov bl, al
    and bl, 0x0F

    shr al, 4
    mov cl, 10
    mul cl

    add al, bl

    pop bx
    pop cx

    ret

; bcd_to_bin_date: convert BCD date from INT 1Ah AH=04h to binary
; IN:  CL=year(BCD), DH=month(BCD), DL=day(BCD)
; OUT: CL=year(bin), DH=month(bin), DL=day(bin)
bcd_to_bin_date:
    push ax
    mov al, cl
    call bcd_to_bin
    mov cl, al
    mov al, dh
    call bcd_to_bin
    mov dh, al
    mov al, dl
    call bcd_to_bin
    mov dl, al
    pop ax
    ret

; bcd_to_bin_time: convert BCD time from INT 1Ah AH=02h to binary
; IN:  CH=hours(BCD), CL=minutes(BCD), DH=seconds(BCD)
; OUT: CH=hours(bin), CL=minutes(bin), DH=seconds(bin)
bcd_to_bin_time:
    push ax
    mov al, ch
    call bcd_to_bin
    mov ch, al
    mov al, cl
    call bcd_to_bin
    mov cl, al
    mov al, dh
    call bcd_to_bin
    mov dh, al
    pop ax
    ret

com_unsupported:
    push bp
    mov bp, sp
    mov ax, 0x0001
    or word [bp+6], 1
    pop bp
    iret

%include "src/kernel/features/com/00h.asm"
%include "src/kernel/features/com/01h.asm"
%include "src/kernel/features/com/02h.asm"
%include "src/kernel/features/com/03h.asm"
%include "src/kernel/features/com/04h.asm"
%include "src/kernel/features/com/05h.asm"
%include "src/kernel/features/com/06h.asm"
%include "src/kernel/features/com/07h.asm"
%include "src/kernel/features/com/08h.asm"
%include "src/kernel/features/com/09h.asm"
%include "src/kernel/features/com/0Ah.asm"
%include "src/kernel/features/com/0Bh.asm"
%include "src/kernel/features/com/0Ch.asm"
%include "src/kernel/features/com/0Dh.asm"
%include "src/kernel/features/com/0Eh.asm"

%include "src/kernel/features/com/0Fh.asm"
%include "src/kernel/features/com/10h.asm"
%include "src/kernel/features/com/13h.asm"
%include "src/kernel/features/com/16h.asm"
%include "src/kernel/features/com/17h.asm"
%include "src/kernel/features/com/fcb.inc"

%include "src/kernel/features/com/19h.asm"
%include "src/kernel/features/com/1Ah.asm"
%include "src/kernel/features/com/25h.asm"
%include "src/kernel/features/com/2Ah.asm"
%include "src/kernel/features/com/2Ch.asm"
%include "src/kernel/features/com/2Fh.asm"
%include "src/kernel/features/com/30h.asm"
%include "src/kernel/features/com/35h.asm"
%include "src/kernel/features/com/36h.asm"
%include "src/kernel/features/com/39h.asm"
%include "src/kernel/features/com/3Ah.asm"
%include "src/kernel/features/com/3Bh.asm"
%include "src/kernel/features/com/41h.asm"
%include "src/kernel/features/com/4Ch.asm"
%include "src/kernel/features/com/4Dh.asm"
%include "src/kernel/features/com/54h.asm"

%include "src/kernel/features/com/dosmem.asm"
%include "src/kernel/features/com/48h.asm"
%include "src/kernel/features/com/49h.asm"
%include "src/kernel/features/com/4Ah.asm"
%include "src/kernel/features/com/4Bh.asm"
%include "src/kernel/features/com/find.inc"
%include "src/kernel/features/com/4Eh.asm"
%include "src/kernel/features/com/4Fh.asm"
%include "src/kernel/features/com/47h.asm"
%include "src/kernel/features/com/dosvars.asm"
%include "src/kernel/features/com/52h.asm"
%include "src/kernel/features/com/34h.asm"
%include "src/kernel/features/com/50h.asm"
%include "src/kernel/features/com/51h.asm"
%include "src/kernel/features/com/5Dh.asm"

%include "src/kernel/features/com/dosfile.asm"
%include "src/kernel/features/com/3Ch.asm"
%include "src/kernel/features/com/56h.asm"
%include "src/kernel/features/com/5Bh.asm"
%include "src/kernel/features/com/3Dh.asm"
%include "src/kernel/features/com/3Eh.asm"
%include "src/kernel/features/com/3Fh.asm"
%include "src/kernel/features/com/40h.asm"
%include "src/kernel/features/com/42h.asm"
%include "src/kernel/features/com/57h.asm"
%include "src/kernel/features/com/26h.asm"
%include "src/kernel/features/com/55h.asm"
%include "src/kernel/features/com/29h.asm"
%include "src/kernel/features/com/5Ah.asm"

%include "src/kernel/features/com/2Bh.asm"
%include "src/kernel/features/com/2Dh.asm"
%include "src/kernel/features/com/33h.asm"
%include "src/kernel/features/com/43h.asm"
%include "src/kernel/features/com/44h.asm"
%include "src/kernel/features/com/45h.asm"
%include "src/kernel/features/com/46h.asm"
%include "src/kernel/features/com/59h.asm"
%include "src/kernel/features/com/62h.asm"
%include "src/kernel/features/com/68h.asm"

%INCLUDE "src/kernel/features/com/int33h/int33h.asm"