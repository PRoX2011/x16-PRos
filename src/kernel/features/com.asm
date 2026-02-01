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

    mov dx, .finished_msg
    mov ah, 0x09
    int 0x21

    ; Wait for key press
    mov ah, 0
    int 16h

    call api_output_init
    call string_clear_screen

    jmp get_cmd

.finished_msg db 'Program finished. Press any key to continue...', 10, 13, '$'

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
    enable_interrupts:
    sti

    cmp ah, 0x00
    je .terminate
    cmp ah, 0x01
    je .input_char_echo
    cmp ah, 0x02
    je .output_char
    cmp ah, 0x03
    je .aux_input
    cmp ah, 0x04
    je .aux_output
    cmp ah, 0x06
    je .direct_console_io
    cmp ah, 0x07
    je .input_char_no_echo
    cmp ah, 0x08
    je .input_char_no_echo
    cmp ah, 0x09
    je .output_string_dollar
    cmp ah, 0x0A
    je .buffered_input
    cmp ah, 0x0B
    je .check_input_status
    cmp ah, 0x2A
    je .get_system_date
    cmp ah, 0x2C
    je .get_system_time
    cmp ah, 0x25
    je .set_interrupt
    cmp ah, 0x35
    je .get_interrupt
    cmp ah, 0x4C
    je .terminate

    iret

.input_char_echo:
    mov ah, 0x00
    int 0x16
    push ax
    mov dl, al
    mov ah, 0x02
    int 0x21
    pop ax
    iret

.output_char:
    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    pop bx
    pop ax
    iret

.aux_input:
    xor dx, dx
    mov ah, 02h
    int 14h

    test ah, 80h
    jnz .aux_read_error

    clc
    iret

.aux_read_error:
    xor al, al
    stc
    iret

.aux_output:
    xor dx, dx
    mov ah, 01h
    mov al, dl
    int 14h

    test ah, 80h
    jnz .aux_write_timeout
    clc
    iret

.aux_write_timeout:
    stc
    iret

.input_char_no_echo:
    mov ah, 0x00
    int 0x16
    iret

.check_input_status:
    mov ah, 0x01
    int 0x16
    jz .no_key_available
    mov al, 0xFF
    iret
.no_key_available:
    mov al, 0x00
    iret

.direct_console_io:
    cmp dl, 0xFF
    je .direct_input

    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    pop bx
    pop ax
    iret

.direct_input:
    mov ah, 0x01
    int 0x16
    jz .no_char_ready

    mov ah, 0x00
    int 0x16
    clc
    iret

.no_char_ready:
    xor al, al
    or al, al
    iret

.output_string_dollar:
    push ax
    push bx
    push si

    mov si, dx
.dos_print_loop:
    lodsb
    cmp al, '$'
    je .dos_print_done

    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    jmp .dos_print_loop

.dos_print_done:
    pop si
    pop bx
    pop ax
    iret

.buffered_input:
    pusha
    mov si, dx

    xor cx, cx
    mov cl, [si]
    cmp cl, 0
    je .buf_done

    mov di, dx
    add di, 2
    xor bx, bx

.buf_input_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D
    je .buf_enter

    cmp al, 0x08
    je .buf_backspace

    cmp bl, cl
    jae .buf_input_loop

    mov ah, 0x0E
    push bx
    mov bl, 0x0F
    int 0x10
    pop bx

    mov [di + bx], al
    inc bx
    jmp .buf_input_loop

.buf_backspace:
    cmp bx, 0
    je .buf_input_loop

    dec bx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .buf_input_loop

.buf_enter:
    mov byte [di + bx], 0x0D

    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10

    mov [si + 1], bl

.buf_done:
    popa
    iret

.get_system_time:
    push bx
    push ax

    mov ah, 0x02
    int 0x1A

    mov al, ch
    call bcd_to_bin
    mov ch, al

    mov al, cl
    call bcd_to_bin
    mov cl, al

    mov al, dh
    call bcd_to_bin
    mov dh, al

    push es
    xor bx, bx
    mov es, bx
    mov al, [es:0x046C]
    pop es
    and al, 99
    mov dl, al

    pop ax
    pop bx
    iret

.get_system_date:
    push bx
    push ax

    mov ah, 0x04
    int 0x1A

    mov al, cl
    call bcd_to_bin
    mov cl, al

    mov al, ch
    call bcd_to_bin
    mov ch, al

    mov al, dh
    call bcd_to_bin
    mov dh, al

    mov al, dl
    call bcd_to_bin
    mov dl, al

    mov al, 0

    pop ax
    pop bx
    iret

.set_interrupt:
    push es
    push bx
    push ax

    xor bx, bx
    mov es, bx

    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1

    mov word [es:bx], dx
    mov word [es:bx+2], ds

    pop ax
    pop bx
    pop es
    iret

.get_interrupt:
    push ds
    push ax

    xor bx, bx
    mov ds, bx

    mov bl, al
    xor bh, bh
    shl bx, 1
    shl bx, 1

    mov bx, word [ds:bx]
    mov es, word [ds:bx+2]

    pop ax
    pop ds
    iret

.terminate:
    int 0x20
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