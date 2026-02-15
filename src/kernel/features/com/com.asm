; ==================================================================
; x16-PRos - Compatibility layer with MS DOS programs.
;            Emulates MS DOS system calls through PRos kernel functions
;
;
; ------------ DOS system calls ------------
;  [DONE] Function 00h: Terminate program
;  [DONE] Function 01h: Read character with echo
;  [DONE] Function 02h: Write character
;  [DONE] Function 03h: Read character from COM1 (auxiliary device)
;  [DONE] Function 04h: Write character to COM1 (auxiliary device)
;  Function 05h: Print character to printer
;  [DONE] Function 06h: Direct console input/output (unfiltered)
;  [DONE] Function 07h: Direct console input (no echo)
;  [DONE] Function 08h: Console input without echo
;  [DONE] Function 09h: Output string ($-terminated)
;  [DONE] Function 0Ah: Buffered keyboard input
;  [DONE] Function 0Bh: Check keyboard status / input available
;  Function 0Ch: Clear keyboard buffer and read input
;  Function 0Dh: Disk reset / flush buffers
;  Function 0Eh: Select default drive
;  Function 0Fh: Open file using FCB
;  Function 10h: Close file using FCB
;  Function 11h: Search for first matching file using FCB
;  Function 12h: Search for next matching file using FCB
;  Function 13h: Delete file using FCB
;  Function 14h: Sequential read using FCB
;  Function 15h: Sequential write using FCB
;  Function 16h: Create file using FCB
;  Function 17h: Rename file using FCB
;  Function 18h: [RESERVED]
;  Function 19h: Get current default drive
;  Function 1Ah: Set DTA (Disk Transfer Area) address
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
;  Function 2Ah: Get system date
;  Function 2Bh: Set system date
;  Function 2Ch: Get system time
;  Function 2Dh: Set system time
;  Function 2Eh: Set/Reset verify switch
;  Function 2Fh: Get current DTA address
;  Function 30h: Get DOS version number
;  Function 31h: Terminate and stay resident (TSR)
;  Function 32h: Get DOS drive information (undocumented)
;  Function 33h: Get/Set Ctrl+C / Ctrl+Break handling
;  Function 34h: Get address of InDOS flag (undocumented)
;  [DONE] Function 35h: Get interrupt vector
;  Function 36:  Get free disk space
;  Function 37h: Get/Set switch character (undocumented)
;  Function 38h: Get/Set country information
;  Function 39h: Create subdirectory (MKDIR)
;  Function 3Ah: Remove subdirectory (RMDIR)
;  Function 3Bh: Change current directory (CHDIR)
;  Function 3Ch: Create file
;  Function 3Dh: Open file
;  Function 3Eh: Close file
;  Function 3Fh: Read from file/device
;  Function 40h: Write to file/device
;  Function 41h: Delete file
;  Function 42h: Move file pointer (seek)
;  Function 43h: Get/Set file attributes
;  Function 44h: I/O control for devices (IOCTL)
;  Function 45h: Duplicate file handle
;  Function 46h: Force duplicate file handle
;  Function 47h: Get current directory path
;  Function 48h: Allocate memory block
;  Function 49h: Free allocated memory block
;  Function 4Ah: Resize memory block
;  Function 4Bh: Load/Execute program (EXEC)
;  [DONE] Function 4Ch: Terminate program with return code
;  Function 4Dh: Get program return code
;  Function 4Eh: Find first matching file (FindFirst)
;  Function 4Fh: Find next matching file (FindNext)
;  Function 54h: Get verify flag
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
    cmp ah, 0x25
    je com_25h
    cmp ah, 0x2A
    je com_2Ah
    cmp ah, 0x2C
    je com_2Ch
    cmp ah, 0x35
    je com_35h
    cmp ah, 0x4C
    je com_4Ch
    iret


saved_interrupt_table resb 1024

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

%include "src/kernel/features/com/00h.asm"
%include "src/kernel/features/com/01h.asm"
%include "src/kernel/features/com/02h.asm"
%include "src/kernel/features/com/03h.asm"
%include "src/kernel/features/com/04h.asm"
%include "src/kernel/features/com/06h.asm"
%include "src/kernel/features/com/07h.asm"
%include "src/kernel/features/com/08h.asm"
%include "src/kernel/features/com/09h.asm"
%include "src/kernel/features/com/0Ah.asm"
%include "src/kernel/features/com/0Bh.asm"
%include "src/kernel/features/com/25h.asm"
%include "src/kernel/features/com/2Ah.asm"
%include "src/kernel/features/com/2Ch.asm"
%include "src/kernel/features/com/35h.asm"
%include "src/kernel/features/com/4Ch.asm"