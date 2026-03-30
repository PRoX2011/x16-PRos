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
;  Function 26h: Create PSP (Program Segment Prefix)
;  Function 27h: Random block read using FCB
;  Function 28h: Random block write using FCB
;  Function 29h: Parse filename and build FCB
;  [DONE] Function 2Ah: Get system date
;  Function 2Bh: Set system date
;  [DONE] Function 2Ch: Get system time
;  Function 2Dh: Set system time
;  Function 2Eh: Set/Reset verify switch
;  [DONE] Function 2Fh: Get current DTA address
;  [DONE] Function 30h: Get DOS version number
;  Function 31h: Terminate and stay resident (TSR)
;  Function 32h: Get DOS drive information (undocumented)
;  Function 33h: Get/Set Ctrl+C / Ctrl+Break handling
;  Function 34h: Get address of InDOS flag (undocumented)
;  [DONE] Function 35h: Get interrupt vector
;  [DONE] Function 36h: Get free disk space
;  Function 37h: Get/Set switch character (undocumented)
;  Function 38h: Get/Set country information
;  [DONE] Function 39h: Create subdirectory (MKDIR)
;  [DONE] Function 3Ah: Remove subdirectory (RMDIR)
;  [DONE] Function 3Bh: Change current directory (CHDIR)
;  Function 3Ch: Create file
;  Function 3Dh: Open file
;  Function 3Eh: Close file
;  Function 3Fh: Read from file/device
;  Function 40h: Write to file/device
;  [DONE] Function 41h: Delete file
;  Function 42h: Move file pointer (seek)
;  Function 43h: Get/Set file attributes
;  Function 44h: I/O control for devices (IOCTL)
;  Function 45h: Duplicate file handle
;  Function 46h: Force duplicate file handle
;  Function 47h: Get current directory path
;  [DONE] Function 48h: Allocate memory block
;  [DONE] Function 49h: Free allocated memory block
;  [DONE] Function 4Ah: Resize memory block
;  Function 4Bh: Load/Execute program (EXEC)
;  [DONE] Function 4Ch: Terminate program with return code
;  [DONE] Function 4Dh: Get program return code
;  Function 4Eh: Find first matching file (FindFirst)
;  Function 4Fh: Find next matching file (FindNext)
;  [DONE] Function 54h: Get verify flag
;  Function 56h: Rename/move file
;  Function 57h: Get/Set file date and time
;  Function 59h: Get extended error information
;  Function 5Ah: Create unique temporary file
;  Function 5Bh: Create new file (fails if already exists)
;  Function 5Ch: Lock/Unlock file region (record locking)
;  Function 5Eh: Various network functions
;  Function 5Fh: Network redirection functions
;  Function 62h: Get PSP (Program Segment Prefix) address
;  Function 68h: Commit file (flush buffers)
;  Function 6Ch: Extended open/create file
; ---------------------------------------------
;
; ==================================================================

int20_handler:
    cli
    cld

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
    call string_clear_screen

    jmp get_cmd

.finished_msg db 'Program finished. Press any key to continue...', 10, 13, 0

api_dos_init:
    pusha
    push es
    push ds

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
    cmp ah, 0x2A
    je com_2Ah
    cmp ah, 0x2C
    je com_2Ch
    cmp ah, 0x2F
    je com_2Fh
    cmp ah, 0x30
    je com_30h
    cmp ah, 0x31
    je com_31h
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
    cmp ah, 0x41
    je com_41h
    cmp ah, 0x4C
    je com_4Ch
    cmp ah, 0x4D
    je com_4Dh
    cmp ah, 0x4B
    je com_4Bh
    cmp ah, 0x48
    je com_48h
    cmp ah, 0x49
    je com_49h
    cmp ah, 0x4A
    je com_4Ah
    cmp ah, 0x54
    je com_54h
    cmp ah, 0x5E
    je com_5Eh
    cmp ah, 0x5F
    je com_5Fh
    mov ax, 0x0001
    stc
    iret


saved_interrupt_table resb 1024
dta_offset            dw 0x0080
dta_segment           dw 0
verify_flag           db 0
last_return_code      db 0
last_return_type      db 0
com_tmp_drive         db 0
com_path_buffer       times 128 db 0
com_path_buffer2       times 128 db 0

; simple DOS memory allocator for INT 21h AH=48h/49h/4Ah
; pool: conventional RAM paragraphs from 0x0500..0x7C00
mem_pool_top          dw 0x0500
mem_pool_end          dw 0x7C00

; LIFO free stack, last freed is merged immediately via bump rollback
mem_stack_sp          db 0
mem_stack_seg         times 8 dw 0
mem_stack_size        times 8 dw 0

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

; mem_alloc: allocate BX paragraphs, return AX=segment, CF set on error
; IN:  BX = size in paragraphs
; OUT: AX = start segment (DOS expects segment in AX), CF=0 on success
mem_alloc:
    push ds
    mov ax, 0x2000
    mov ds, ax

    cmp bx, 0
    je .no_mem

    mov ax, [mem_pool_top]
    mov cx, ax                      ; start seg
    add ax, bx                      ; end seg
    jc .no_mem
    cmp ax, [mem_pool_end]
    ja .no_mem

    mov [mem_pool_top], ax

    xor si, si
    mov si, [mem_stack_sp]
    cmp si, 8
    jae .no_mem

    shl si, 1
    mov [mem_stack_seg+si], cx
    mov [mem_stack_size+si], bx
    inc byte [mem_stack_sp]

    mov ax, cx
    clc
    pop ds
    ret

.no_mem:
    mov ax, 0x0008                 ; insufficient memory
    stc
    pop ds
    ret

; mfree: free ES segment, LIFO only, CF set on error
; IN:  ES = segment returned by mem_alloc
; OUT: CF=0 on success
mfree:
    push ds
    mov ax, 0x2000
    mov ds, ax

    cmp byte [mem_stack_sp], 0
    je .invalid

    mov bl, [mem_stack_sp]
    dec bl
    xor bh, bh
    shl bx, 1
    mov ax, [mem_stack_seg+bx]
    mov dx, es
    cmp ax, dx
    jne .invalid

    dec byte [mem_stack_sp]
    mov [mem_pool_top], ax

    clc
    pop ds
    ret

.invalid:
    mov ax, 0x0006                 ; invalid memory block
    stc
    pop ds
    ret

; mem_resize: resize ES segment to BX paragraphs, LIFO only
; IN:  ES = segment, BX = new size (paragraphs)
; OUT: CF=0 on success, AX=ES
mem_resize:
    push ds
    mov ax, 0x2000
    mov ds, ax

    mov di, bx                      ; new size

    cmp byte [mem_stack_sp], 0
    je .invalid

    mov bl, [mem_stack_sp]
    dec bl
    xor bh, bh
    shl bx, 1                       ; offset in bytes

    mov ax, [mem_stack_seg+bx]     ; start seg
    mov dx, es
    cmp ax, dx
    jne .invalid

    mov dx, [mem_stack_size+bx]    ; old size

    cmp di, dx
    jbe .shrink

    ; expand
    add ax, di
    jc .no_mem
    cmp ax, [mem_pool_end]
    ja .no_mem

    mov [mem_pool_top], ax
    mov [mem_stack_size+bx], di
    mov ax, es
    clc
    pop ds
    ret

.shrink:
    add ax, di
    mov [mem_pool_top], ax
    mov [mem_stack_size+bx], di
    mov ax, es
    clc
    pop ds
    ret

.no_mem:
    mov ax, 0x0008                 ; insufficient memory
    stc
    pop ds
    ret

.invalid:
    mov ax, 0x0006                 ; invalid memory block
    stc
    pop ds
    ret

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
%include "src/kernel/features/com/31h.asm"
%include "src/kernel/features/com/35h.asm"
%include "src/kernel/features/com/36h.asm"
%include "src/kernel/features/com/39h.asm"
%include "src/kernel/features/com/3Ah.asm"
%include "src/kernel/features/com/3Bh.asm"
%include "src/kernel/features/com/41h.asm"
%include "src/kernel/features/com/4Ch.asm"
%include "src/kernel/features/com/4Dh.asm"
%include "src/kernel/features/com/4Bh.asm"
%include "src/kernel/features/com/48h.asm"
%include "src/kernel/features/com/49h.asm"
%include "src/kernel/features/com/4Ah.asm"
%include "src/kernel/features/com/54h.asm"
%include "src/kernel/features/com/5Eh.asm"
%include "src/kernel/features/com/5Fh.asm"