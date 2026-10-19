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
;  Function 11h: Search for first matching file using FCB (never finds one)
;  Function 12h: Search for next matching file using FCB (never finds one)
;  [DONE] Function 13h: Delete file using FCB
;  Function 14h: Sequential read using FCB
;  Function 15h: Sequential write using FCB
;  [DONE] Function 16h: Create file using FCB
;  [DONE] Function 17h: Rename file using FCB
;  Function 18h: [RESERVED]
;  [DONE] Function 19h: Get current default drive
;  [DONE] Function 1Ah: Set DTA (Disk Transfer Area) address
;  [DONE] Function 1Bh: Get FAT information for default drive
;  [DONE] Function 1Ch: Get FAT information for any drive
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
;  [DONE] Function 32h: Get DOS drive information (undocumented)
;  [DONE] Function 50h: Set current PSP
;  [DONE] Function 51h: Get current PSP
;  [DONE] Function 52h: Get List of Lists (undocumented)
;  [DONE] Function 33h: Get/Set Ctrl+C / Ctrl+Break handling
;  [DONE] Function 34h: Get address of InDOS flag (undocumented)
;  [DONE] Function 35h: Get interrupt vector
;  [DONE] Function 36h: Get free disk space
;  Function 37h: Get/Set switch character (undocumented)
;  [DONE] Function 38h: Get/Set country information
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
;  [DONE] Function 58h: Get/Set memory allocation strategy and UMB link
;  [DONE] Function 5Dh: Get swappable data area (DOS 3)
;  [DONE] Function 5Ah: Create a temporary file
;  [DONE] Function 5Bh: Create new file (fails if already exists)
;  [DONE] Function 5Ch: Lock/Unlock file region (record locking)
;  Function 5Eh: Various network functions
;  Function 5Fh: Network redirection functions
;  [DONE] Function 62h: Get PSP (Program Segment Prefix) address
;  [DONE] Function 66h: Get/Set global code page
;  [DONE] Function 67h: Set handle count (up to 20)
;  [DONE] Function 68h: Commit file (flush buffers)
;  Function 6Ch: Extended open/create file
; ---------------------------------------------
;
; ==================================================================

int2F_handler:
    cmp ax, 0x1000
    je .share
    xor al, al
    iret
.share:
    mov al, 0xFF
    iret

; ==================================================================
; DOS_LEAVE_PSP - release what an ending process holds, restore its
;                 INT 0x23/0x24 and make its parent the current process
; IN : ES = the ending PSP
;      AX = its parent
;      DS = KERNEL_DATA_SEG
; ==================================================================
dos_leave_psp:
    push ax
    mov ax, [dos_current_psp]
    call dosfile_close_psp
    call dosmem_free_owner
    mov ax, es
    call dosfile_close_psp
    call dosmem_free_owner

    push ds
    push es
    push es
    pop ds
    mov si, 0x0E
    xor di, di
    mov es, di
    mov di, 0x23 * 4
    mov cx, 4
    rep movsw
    pop es
    pop ds

    pop ax
    mov [dos_current_psp], ax
    mov [dta_segment], ax
    mov word [dta_offset], 0x0080
    jmp dosvars_stamp_psp

; ==================================================================
; DOS_TERMINATE_CHILD - end a process and resume its parent
; IN : ES = the ending PSP
;      AX = its parent
; ==================================================================
dos_terminate_child:
    call dos_leave_psp
    mov bx, [es:0x0A]
    mov cx, [es:0x0C]
    mov es, ax
    xor dx, dx
    mov ss, [es:0x30]
    mov sp, [es:0x2E]
    mov [es:0x30], dx
    mov bp, sp
    mov [bp + 18], bx
    mov [bp + 20], cx
    and word [bp + 22], 0xFFFE
    jmp dos_frame_iret

; ==================================================================
; DOS_TERMINATE_OWN - end a process no parent waits for in AH = 4Bh
;                     and go to the terminate address at its PSP:0Ah
; IN : ES = the ending PSP
;      AX = its parent
; ==================================================================
dos_terminate_own:
    call dos_leave_psp
    add sp, 18
    mov bp, sp
    mov bx, [es:0x0A]
    mov [bp], bx
    mov bx, [es:0x0C]
    mov [bp + 2], bx
    mov ds, ax
    mov es, ax
    iret

int26_handler:
    mov ax, 0x0300
    stc
    retf

int25_handler:
    cmp byte [cs:dos_stack_busy], 0
    jne .nested
    call dos_stack_enter
    call int25_read
    cli
    dec byte [cs:dos_stack_busy]
    mov ss, [cs:dos_user_ss]
    mov sp, [cs:dos_user_sp]
    sti
    retf
.nested:
    call int25_read
    retf

int25_read:
    push bx
    push cx
    push dx
    push ds
    push es
    cmp cx, 0xFFFF
    jne .direct
    mov dx, [bx]
    mov cx, [bx + 4]
    les bx, [bx + 6]
    jmp .have_args
.direct:
    push ds
    pop es
.have_args:
    push ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    call save_current_dir
    pop ax
    add al, 'A'
    call fs_change_drive_letter
    jc .done
    mov ax, dx
    mov dh, 2
    call fs_sector_run
.done:
    pushf
    call restore_current_dir
    popf
    mov ax, 0
    jnc .read
    mov ax, 0x080C
.read:
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    ret

; ==================================================================
; INT 20h - Terminate program.
; The same ending as AH = 4Ch, so it goes there.
; ==================================================================
int20_handler:
    xor al, al
    jmp com_4Ch

; ==================================================================
; DOS_TERMINATE - end the current process. A child of AH = 4Bh goes
;                 back into that call, the program the shell started
;                 goes back to the shell.
; ==================================================================
dos_terminate:
    cli
    cld
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov byte [dos_stack_busy], 0
    cmp byte [com_active], 0
    jne .dos

    mov ax, 0x12
    int 0x10
    jmp launch_bin_program.program_done

.dos:
    mov es, [dos_current_psp]
    mov cx, 8
.up:
    mov ax, [es:0x16]
    test ax, ax
    jz .com_teardown
    mov bx, es
    cmp ax, bx
    je .com_teardown
    push ds
    mov ds, ax
    cmp word [0x30], 0
    pop ds
    jne dos_terminate_child
    cmp cx, 8
    jne .next
    mov bx, [es:0x0C]
    test bx, bx
    jz .next
    cmp bx, KERNEL_DATA_SEG
    jne dos_terminate_own
.next:
    mov es, ax
    loop .up

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
    mov ax, DOSDATA_SEG
    mov ds, ax

    xor si, si
    xor di, di
    mov cx, 512
    rep movsw

    pop cx
    pop di
    pop si
    pop es
    pop ds

    mov ax, KERNEL_DATA_SEG
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

    mov byte [cs:dos_stack_busy], 0
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
    mov ax, DOSDATA_SEG
    mov es, ax

    xor si, si
    xor di, di
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
    mov word [es:0x25*4], int25_handler
    mov word [es:0x25*4+2], cs
    mov word [es:0x26*4], int26_handler
    mov word [es:0x26*4+2], cs

    pop ds
    pop es
    popa
    ret

int21_dos_handler:
    sti

    cmp byte [cs:dos_stack_busy], 0
    jne int21_handles
    cmp ah, 0x00
    je int21_handles
    cmp ah, 0x31
    je int21_handles
    cmp ah, 0x4B
    je int21_handles
    cmp ah, 0x4C
    je int21_handles
    call dos_stack_enter
    pushf
    push cs
    push word dos_stack_back

int21_handles:
    cmp ah, 0x3F
    je dos_by_handle
    cmp ah, 0x40
    je dos_by_handle
    cmp ah, 0x42
    je dos_by_handle
    cmp ah, 0x57
    je dos_by_handle
    cmp ah, 0x68
    je dos_by_handle
    cmp ah, 0x5C
    je dos_by_handle
    cmp ah, 0x44
    jne int21_route
    cmp al, 0x08
    jb dos_by_handle
    cmp al, 0x0A
    je dos_by_handle

int21_route:
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
    cmp ah, 0x11
    je com_11h
    cmp ah, 0x12
    je com_12h
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
    cmp ah, 0x1B
    je com_1Bh
    cmp ah, 0x1C
    je com_1Ch
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
    cmp ah, 0x32
    je com_32h
    cmp ah, 0x36
    je com_36h
    cmp ah, 0x38
    je com_38h
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
    cmp ah, 0x5C
    je com_5Ch
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
    cmp ah, 0x58
    je com_58h
    cmp ah, 0x66
    je com_66h
    cmp ah, 0x67
    je com_67h
    cmp ah, 0x68
    je com_68h
    cmp ah, 0x2B
    je com_2Bh
    cmp ah, 0x2D
    je com_2Dh
    cmp ah, 0x33
    je com_33h
    jmp com_unsupported

; ==================================================================
; DOS_STACK_ENTER - move onto the DOS stack, the part of the kernel stack
;                   below the shell that waits for the DOS program; the
;                   near return lands there
; ==================================================================
dos_stack_enter:
    pop word [cs:dos_stack_ret]
    mov [cs:dos_user_ss], ss
    mov [cs:dos_user_sp], sp
    cli
    mov ss, [cs:com_ss_save]
    mov sp, [cs:com_stack_save]
    sub sp, 0x20
    sti
    inc byte [cs:dos_stack_busy]
    jmp [cs:dos_stack_ret]

; ==================================================================
; DOS_STACK_BACK - an INT 0x21 call that ran on the DOS stack returns here
; ==================================================================
dos_stack_back:
    jnc .no_error
    mov [cs:dos_last_error], ax
.no_error:
    pushf
    pop word [cs:dos_result_flags]
    cli
    dec byte [cs:dos_stack_busy]
    mov ss, [cs:dos_user_ss]
    mov sp, [cs:dos_user_sp]
    push bp
    mov bp, sp
    push ax
    mov ax, [cs:dos_result_flags]
    and ax, 0x08D5
    and word [bp + 6], 0xF72A
    or [bp + 6], ax
    pop ax
    pop bp
    iret

dos_user_sp      dw 0
dos_user_ss      dw 0
dos_stack_ret    dw 0
dos_last_error   dw 0
dos_result_flags dw 0
dos_stack_busy   db 0

; ==================================================================
; DOS_BY_HANDLE - run a call that takes a handle in BX with BX turned
;                 into the system file number the handle stands for
; ==================================================================
dos_by_handle:
    push bx
    call dosfile_handle
    jc .bad
    push ax
    call dosfile_drive_of
    call dos_drive_select
    push bp
    mov bp, sp
    xchg al, [bp + 2]
    pop bp
    pushf
    push cs
    push word .back
    jmp int21_route
.back:
    pushf
    push ax
    push bp
    mov bp, sp
    mov al, [bp + 6]
    call dos_drive_back
    mov ax, [bp + 4]
    mov [bp + 6], ax
    pop bp
    pop ax
    add sp, 2
    popf
    pop bx
    push bp
    mov bp, sp
    jc .cf
    and word [bp + 6], 0xFFFE
    pop bp
    iret
.bad:
    pop bx
    mov ax, 0x0006
    push bp
    mov bp, sp
.cf:
    or word [bp + 6], 1
    pop bp
    iret

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
    mov ax, KERNEL_DATA_SEG
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
%include "src/kernel/features/com/11h.asm"
%include "src/kernel/features/com/13h.asm"
%include "src/kernel/features/com/16h.asm"
%include "src/kernel/features/com/17h.asm"
%include "src/kernel/features/com/fcb.inc"

%include "src/kernel/features/com/19h.asm"
%include "src/kernel/features/com/1Ah.asm"
%include "src/kernel/features/com/1Ch.asm"
%include "src/kernel/features/com/25h.asm"
%include "src/kernel/features/com/2Ah.asm"
%include "src/kernel/features/com/2Ch.asm"
%include "src/kernel/features/com/2Fh.asm"
%include "src/kernel/features/com/30h.asm"
%include "src/kernel/features/com/35h.asm"
%include "src/kernel/features/com/32h.asm"
%include "src/kernel/features/com/36h.asm"
%include "src/kernel/features/com/38h.asm"
%include "src/kernel/features/com/58h.asm"
%include "src/kernel/features/com/66h.asm"
%include "src/kernel/features/com/67h.asm"
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
%include "src/kernel/features/com/5Ch.asm"
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