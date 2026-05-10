; ==================================================================
; x16-PRos - Kernel File System API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Function codes in AH:
;   0x00: Re-Initialize file system
;   0x01: Get file list (SI = buffer for 18-byte entries, returns BX = size low, CX = size high, DX = file count)
;         NOTE: writes to caller's DS:SI buffer.
;   0x02: Load file (SI = filename, CX = load position, returns BX = file size).
;         File contents are loaded into caller's segment at offset CX.
;   0x03: Write file (SI = filename, BX = buffer in caller seg, CX = size)
;   0x04: Check if file exists (SI = filename)
;   0x05: Create empty file (SI = filename)
;   0x06: Remove file (SI = filename)
;   0x07: Rename file (SI = old name, DI = new name)
;   0x08: Get file size (SI = filename, returns BX = size)
;   0x09: Change current directory (SI = dirname, returns CF flag)
;   0x0A: Go to parent directory (returns CF flag)
;   0x0B: Create directory (SI = dirname, returns CF flag)
;   0x0C: Remove directory (SI = dirname, returns CF flag)
;   0x0D: Check if directory (SI = name, returns CF flag)
;   0x0E: Save current directory
;   0x0F: Restore current directory
;   0x10: Load huge file (SI = filename, CX = load offset, DX = load segment)
;   0x11: List drives
;   0x12: Change drive (SI = Drive letter pointer)
;   0x13: Write huge file (SI = filename, CX = source offset, DX = source segment, BX = size low, DI = size high)
;   0x14: Get current drive letter (returns AL = drive letter)
; ==================================================================

[BITS 16]

api_fs_init:
    pusha
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x22*4], int22_handler
    mov word [es:0x22*4+2], cs
    sti
    xor ax, ax
    call fs_reset_floppy
    pop es
    popa
    ret

int22_handler:
    pusha
    push ds
    push es

    mov [cs:caller_ds_save_22], ds

    mov bp, cs
    mov ds, bp
    mov es, bp
    cld

    mov al, ah

    ; ---- Pre-process string arguments for functions that take them ----
    cmp al, 0x02
    jb .no_si_str
    cmp al, 0x0D
    jbe .copy_si_str
    cmp al, 0x10
    je .copy_si_str
    cmp al, 0x12
    je .copy_si_str
    cmp al, 0x13
    je .copy_si_str
    jmp .no_si_str
.copy_si_str:
    call copy_caller_string_si
.no_si_str:
    cmp al, 0x07
    jne .no_di_str
    call copy_caller_string_di
.no_di_str:
    cmp al, 0x00
    je .init
    cmp al, 0x01
    je .get_file_list
    cmp al, 0x02
    je .load_file
    cmp al, 0x03
    je .write_file
    cmp al, 0x04
    je .file_exists
    cmp al, 0x05
    je .create_file
    cmp al, 0x06
    je .remove_file
    cmp al, 0x07
    je .rename_file
    cmp al, 0x08
    je .get_file_size
    cmp al, 0x09
    je .change_directory
    cmp al, 0x0A
    je .parent_directory
    cmp al, 0x0B
    je .create_directory
    cmp al, 0x0C
    je .remove_directory
    cmp al, 0x0D
    je .is_directory
    cmp al, 0x0E
    je .save_directory
    cmp al, 0x0F
    je .restore_directory
    cmp al, 0x10
    je .load_huge_file
    cmp al, 0x11
    je .list_drives
    cmp al, 0x12
    je .change_drive
    cmp al, 0x13
    je .write_huge_file
    cmp al, 0x14
    je .get_current_drive
    stc
    jmp .done

.init:
    xor ax, ax
    call fs_reset_floppy
    jmp .done

.get_file_list:
    mov ax, [cs:caller_ds_save_22]
    cmp ax, KERNEL_DATA_SEG
    jne .gfl_cross_seg

    mov ax, si
    call fs_get_file_list
    jc .done
    mov [.saved_bx], bx
    mov [.saved_cx], cx
    mov [.saved_dx], dx

    mov bp, sp
    mov bx, [.saved_bx]
    mov [bp+12], bx
    mov cx, [.saved_cx]
    mov [bp+16], cx
    mov dx, [.saved_dx]
    mov [bp+14], dx
    jmp .done

.gfl_cross_seg:
    push si
    mov ax, dirlist
    call fs_get_file_list
    pop di
    jc .done

    mov [.saved_bx], bx
    mov [.saved_cx], cx
    mov [.saved_dx], dx

    push es
    mov ax, dx
    mov bx, 18
    mul bx
    inc ax
    mov cx, ax
    mov si, dirlist
    mov ax, [cs:caller_ds_save_22]
    mov es, ax
    rep movsb
    pop es

    mov bp, sp
    mov bx, [.saved_bx]
    mov [bp+12], bx
    mov cx, [.saved_cx]
    mov [bp+16], cx
    mov dx, [.saved_dx]
    mov [bp+14], dx
    jmp .done

.load_file:
    mov ax, si
    mov dx, [cs:caller_ds_save_22]
    call fs_load_huge_file
    jc .done

    mov bp, sp
    mov [bp+12], ax
    jmp .done

.write_file:
    mov ax, si
    push cx
    mov cx, bx
    mov dx, [cs:caller_ds_save_22]
    pop bx
    xor di, di
    call fs_write_huge_file
    jmp .done

.file_exists:
    mov ax, si
    call fs_file_exists
    jmp .done

.create_file:
    mov ax, si
    call fs_create_file
    jmp .done

.remove_file:
    mov ax, si
    call fs_remove_file
    jmp .done

.rename_file:
    mov ax, si
    mov bx, di
    call fs_rename_file
    jmp .done

.get_file_size:
    mov ax, si
    call fs_get_file_size
    mov bp, sp
    mov [bp+12], bx
    jmp .done

.change_directory:
    mov ax, si
    call fs_change_directory
    jmp .done

.parent_directory:
    call fs_parent_directory
    jmp .done

.create_directory:
    mov ax, si
    call fs_create_directory
    jmp .done

.remove_directory:
    mov ax, si
    call fs_remove_directory
    jmp .done

.is_directory:
    mov ax, si
    call fs_is_directory
    jmp .done

.save_directory:
    call save_current_dir
    jmp .done

.restore_directory:
    call restore_current_dir
    jmp .done

.load_huge_file:
    mov ax, si
    call fs_load_huge_file
    jmp .done

.list_drives:
    call fs_list_drives
    jmp .done

.change_drive:
    mov al, [si]
    call fs_change_drive_letter
    jmp .done

.write_huge_file:
    mov ax, si
    call fs_write_huge_file
    jmp .done

.get_current_drive:
    mov al, [current_drive_char]
    mov bp, sp
    mov [bp+18], al
    jmp .done

.done:
    jc .set_cf
    push bp
    mov bp, sp
    and word [bp+26], 0xFFFE
    pop bp
    jmp .do_iret
.set_cf:
    push bp
    mov bp, sp
    or word [bp+26], 0x0001
    pop bp
.do_iret:
    pop es
    pop ds
    popa
    iret

; ==================================================================
; copy_caller_string_si -- copy NUL-terminated string from
;     [caller_ds_save_22:SI] into kernel scratch and update SI.
; OUT: SI = offset of scratch (in kernel DS).
; Preserves: AX, BX, CX, DX, DI.
; ==================================================================
copy_caller_string_si:
    push ax
    push di
    push es
    push ds

    push cs
    pop es
    mov di, .si_scratch

    mov ax, [cs:caller_ds_save_22]
    mov ds, ax
.cl:
    lodsb
    stosb
    test al, al
    jnz .cl

    pop ds
    pop es
    pop di
    pop ax
    mov si, .si_scratch
    ret

.si_scratch times 64 db 0

; ==================================================================
; copy_caller_string_di -- like copy_caller_string_si but for DI.
; OUT: DI = offset of scratch.
; Preserves: AX, BX, CX, DX, SI.
; ==================================================================
copy_caller_string_di:
    push ax
    push si
    push es
    push ds

    mov si, di

    push cs
    pop es
    mov di, .di_scratch

    mov ax, [cs:caller_ds_save_22]
    mov ds, ax
.cl:
    lodsb
    stosb
    test al, al
    jnz .cl

    pop ds
    pop es
    pop si
    pop ax
    mov di, .di_scratch
    ret

.di_scratch times 64 db 0

caller_ds_save_22 dw 0

int22_handler.saved_bx dw 0
int22_handler.saved_cx dw 0
int22_handler.saved_dx dw 0