; ==================================================================
; x16-PRos - DOS file-handle compatibility functions
; Copyright (C) 2025 PRoX2011
;
; Implements the MS-DOS INT 0x21 file-handle API so DOS programs can
; create, open, read, write and seek files:
;   AH=2Eh Set/Reset verify flag
;   AH=3Ch Create file          AH=3Dh Open file
;   AH=3Eh Close file           AH=3Fh Read file
;   AH=40h Write file           AH=42h Seek file
;   AH=43h Get/set attribute    AH=56h Rename file
;
; Handles: up to MAX_HANDLES files, each loaded into a private 16 KiB
; buffer at HANDLE_BUF_SEG. Reads/writes operate on the in-memory
; copy; Close writes it back to disk when modified.
;
; NOTE: every function pushes exactly 8 registers before exit so the
; DOS_SET_CF / DOS_CLR_CF macros (which patch the caller's saved
; flags at [SP+20]) work correctly.
; ==================================================================

MAX_HANDLES      equ 4
HANDLE_BUF_SIZE  equ 0x4000
HANDLE_BUF_SEG   equ 0x4000

; ---- handle table ----
dos_handle_inuse   times MAX_HANDLES db 0
dos_handle_size    times MAX_HANDLES dw 0
dos_handle_pos     times MAX_HANDLES dw 0
dos_handle_modified times MAX_HANDLES db 0
dos_handle_name    times MAX_HANDLES*16 db 0
dos_caller_ds      dw 0
dos_result         dw 0
dos_tmp            dw 0
dos_tmp2           dw 0

; ==================================================================
; DOS_SET_CF / DOS_CLR_CF - patch the carry flag in the caller's
; saved flags. Assumes exactly 8 pushes (16 bytes) on the stack.
; ==================================================================
%macro dos_set_cf 0
    mov bp, sp
    or word [bp + 20], 0x0001
%endmacro
%macro dos_clr_cf 0
    mov bp, sp
    and word [bp + 20], 0xFFFE
%endmacro

; ------------------------------------------------------------------
; DOS_ALLOC_HANDLE - find a free handle slot.
; OUT: CF=0, BX = handle index; CF=1 if the table is full.
; ------------------------------------------------------------------
dos_alloc_handle:
    push ax
    mov bx, 0
.dh_loop:
    cmp bx, MAX_HANDLES
    jae .dh_full
    cmp byte [cs:dos_handle_inuse + bx], 0
    je .dh_found
    inc bx
    jmp .dh_loop
.dh_full:
    pop ax
    stc
    ret
.dh_found:
    pop ax
    clc
    ret

; ------------------------------------------------------------------
; DOS_COPY_NAME - copy NUL-terminated name from DS:SI to ES:DI,
; bounded to 15 chars + terminator.
; ------------------------------------------------------------------
dos_copy_name:
    push ax
    push cx
    push si
    push di
    mov cx, 15
.dn_loop:
    lodsb
    stosb
    test al, al
    jz .dn_done
    loop .dn_loop
    xor al, al
    stosb
.dn_done:
    pop di
    pop si
    pop cx
    pop ax
    ret

; ------------------------------------------------------------------
; DOS_COPY_NEW_NAME - copy ASCIIZ from segment AX:offset DI to the
; kernel buffer com_path_buffer2.
; ------------------------------------------------------------------
dos_copy_new_name:
    push bx
    push cx
    push si
    push di
    push ds
    push es
    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov es, bx
    mov si, di
    mov di, com_path_buffer2
    mov ds, ax
    mov cx, 63
.dcn_loop:
    lodsb
    stosb
    test al, al
    jz .dcn_done
    loop .dcn_loop
    xor al, al
    stosb
.dcn_done:
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop bx
    ret

; ==================================================================
; AH=2Eh - Set/Reset verify flag. AL = 0 or 1.
; ==================================================================
com_2Eh:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:verify_flag], al
    mov word [cs:dos_result], 0
    dos_clr_cf

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=43h - Get/set file attribute. DS:DX = filename, AL = 0 get / 1 set.
; Always reports the normal archive attribute.
; ==================================================================
com_43h:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    test al, al
    jnz .h43_set
    ; get attribute: return 0x20 (archive) in CX
    mov word [cs:dos_result], 0x20
    dos_clr_cf
    jmp .h43_exit
.h43_set:
    ; set attribute: accept any value but keep the filesystem entry.
    mov word [cs:dos_result], cx
    dos_clr_cf
.h43_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=56h - Rename file. DS:DX = old name, ES:DI = new name.
; ==================================================================
com_56h:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; Remember the caller's new-name offset (DI may be clobbered).
    mov [cs:dos_tmp2], di

    ; old name (DS:DX) -> com_path_buffer
    mov si, dx
    call com_copy_path_from_caller
    mov [cs:dos_tmp], ax

    ; new name (ES:DI) -> com_path_buffer2
    mov ax, es
    mov di, [cs:dos_tmp2]
    call dos_copy_new_name

    ; rename via the filesystem
    push ds
    push es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov ax, [cs:dos_tmp]
    mov bx, com_path_buffer2
    call fs_rename_file
    pop es
    pop ds
    jnc .h56_ok
    mov word [cs:dos_result], 0x0002
    dos_set_cf
    jmp .h56_exit
.h56_ok:
    mov word [cs:dos_result], 0
    dos_clr_cf
.h56_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=3Ch - Create file. DS:DX = filename, CX = attribute.
; OUT: AX = handle.
; ==================================================================
com_3Ch:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov si, dx
    call com_copy_path_from_caller   ; AX = com_path_buffer

    push ds
    push es
    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov es, bx
    call fs_create_file
    pop es
    pop ds
    jc .h3C_create_error

    call dos_alloc_handle
    jc .h3C_no_handles

    ; set up the new handle
    mov si, com_path_buffer
    mov di, dos_handle_name
    push ax
    mov ax, bx
    shl ax, 4
    add di, ax
    pop ax
    push ds
    push es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    call dos_copy_name
    pop es
    pop ds

    mov byte [cs:dos_handle_inuse + bx], 1
    mov ax, bx
    shl ax, 1
    mov si, ax
    mov word [cs:dos_handle_size + si], 0
    mov word [cs:dos_handle_pos + si], 0
    mov byte [cs:dos_handle_modified + bx], 0

    mov [cs:dos_result], bx
    dos_clr_cf
    jmp .h3C_exit

.h3C_create_error:
    mov word [cs:dos_result], 0x0003
    dos_set_cf
    jmp .h3C_exit
.h3C_no_handles:
    mov word [cs:dos_result], 0x0004
    dos_set_cf
.h3C_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=3Dh - Open file. DS:DX = filename, AL = access mode.
; OUT: AX = handle.
; ==================================================================
com_3Dh:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov si, dx
    call com_copy_path_from_caller   ; AX = com_path_buffer

    call dos_alloc_handle
    jc .h3D_no_handles

    ; load the file into the handle buffer
    mov cx, 0                        ; offset
    mov dx, bx
    shl dx, 10
    add dx, HANDLE_BUF_SEG           ; handle buffer segment
    push ds
    push es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov ax, com_path_buffer
    call fs_load_huge_file
    pop es
    pop ds
    jc .h3D_load_error
    ; DX:AX = file size; must fit in the 16 KiB buffer
    cmp dx, 0
    jne .h3D_too_big
    cmp ax, HANDLE_BUF_SIZE
    ja .h3D_too_big

    ; store the name in the handle slot
    mov si, com_path_buffer
    mov di, dos_handle_name
    push ax
    mov ax, bx
    shl ax, 4
    add di, ax
    pop ax
    push ds
    push es
    mov bx, KERNEL_DATA_SEG
    mov ds, bx
    mov es, bx
    call dos_copy_name
    pop es
    pop ds

    ; populate the handle entry
    mov byte [cs:dos_handle_inuse + bx], 1
    push ax
    mov ax, bx
    shl ax, 1
    mov si, ax
    pop ax
    mov [cs:dos_handle_size + si], ax
    mov word [cs:dos_handle_pos + si], 0
    mov byte [cs:dos_handle_modified + bx], 0

    mov [cs:dos_result], bx
    dos_clr_cf
    jmp .h3D_exit

.h3D_no_handles:
    mov word [cs:dos_result], 0x0004
    dos_set_cf
    jmp .h3D_exit
.h3D_load_error:
.h3D_too_big:
    mov word [cs:dos_result], 0x0002
    dos_set_cf
.h3D_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=3Eh - Close file. BX = handle. Writes back if modified.
; ==================================================================
com_3Eh:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    cmp bx, MAX_HANDLES
    jae .h3E_error
    cmp byte [cs:dos_handle_inuse + bx], 0
    je .h3E_error

    cmp byte [cs:dos_handle_modified + bx], 0
    je .h3E_no_write

    ; write the handle buffer back to disk
    ; fs_write_huge_file: AX=filename, BX=size_low, DI=size_high,
    ;                     CX=src_offset, DX=src_segment
    push ds
    push es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    ; AX = name pointer
    mov si, dos_handle_name
    mov ax, bx
    shl ax, 4
    add si, ax
    mov ax, si
    ; DX = handle buffer segment
    mov dx, bx
    shl dx, 10
    add dx, HANDLE_BUF_SEG
    ; BX = size_low
    push ax
    mov ax, bx
    shl ax, 1
    mov si, ax
    mov bx, [cs:dos_handle_size + si]
    pop ax
    xor di, di                     ; size_high = 0
    xor cx, cx                     ; source offset = 0
    call fs_write_huge_file
    pop es
    pop ds
    jc .h3E_write_error

.h3E_no_write:
    mov byte [cs:dos_handle_inuse + bx], 0
    mov word [cs:dos_result], 0
    dos_clr_cf
    jmp .h3E_exit

.h3E_write_error:
.h3E_error:
    mov word [cs:dos_result], 0x0006
    dos_set_cf
.h3E_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=3Fh - Read from file. BX = handle, CX = count, DS:DX = buffer.
; OUT: AX = bytes read (0 at EOF).
; ==================================================================
com_3Fh:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:dos_caller_ds], ds

    cmp bx, MAX_HANDLES
    jae .h3F_error
    cmp byte [cs:dos_handle_inuse + bx], 0
    je .h3F_error

    ; word-array byte index in DI, handle segment in SI
    mov di, bx
    shl di, 1
    mov si, bx
    shl si, 10
    add si, HANDLE_BUF_SEG

    ; available = size - position
    mov ax, [cs:dos_handle_size + di]
    sub ax, [cs:dos_handle_pos + di]
    jbe .h3F_zero
    cmp cx, ax
    jbe .h3F_count_ok
    mov cx, ax
.h3F_count_ok:
    mov ax, cx                     ; bytes to transfer (CX is consumed by movsb)
    mov di, [cs:dos_handle_pos + di]      ; source offset

    push es
    mov es, si                           ; ES = handle buffer (source)
    push ds
    mov ds, [cs:dos_caller_ds]           ; DS = caller (dest)
    mov si, dx                           ; dest offset
    mov cx, ax
    rep movsb
    pop ds
    pop es

    ; advance position (DI holds the byte index again)
    mov di, bx
    shl di, 1
    add [cs:dos_handle_pos + di], ax
    mov [cs:dos_result], ax
    dos_clr_cf
    jmp .h3F_exit
.h3F_zero:
    mov word [cs:dos_result], 0
    dos_clr_cf
    jmp .h3F_exit
.h3F_error:
    mov word [cs:dos_result], 0x0006
    dos_set_cf
.h3F_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=40h - Write to file. BX = handle, CX = count, DS:DX = buffer.
; OUT: AX = bytes written.
; ==================================================================
com_40h:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:dos_caller_ds], ds

    cmp bx, MAX_HANDLES
    jae .h40_error
    cmp byte [cs:dos_handle_inuse + bx], 0
    je .h40_error

    ; word-array byte index in DI, handle segment in SI
    mov di, bx
    shl di, 1
    mov si, bx
    shl si, 10
    add si, HANDLE_BUF_SEG

    ; Cap the write so we never overflow the 16 KiB handle buffer.
    mov ax, HANDLE_BUF_SIZE
    sub ax, [cs:dos_handle_pos + di]     ; free space from the position
    jbe .h40_buffer_full
    cmp cx, ax
    jbe .h40_count_ok
    mov cx, ax
.h40_count_ok:
    mov ax, cx                     ; bytes to write

    push es
    mov es, si                           ; ES = handle buffer (dest)
    push ds
    mov ds, [cs:dos_caller_ds]           ; DS = caller (source)
    mov si, dx                           ; source offset
    mov di, [cs:dos_handle_pos + di]     ; dest offset
    mov cx, ax
    rep movsb
    pop ds
    pop es

    ; advance position and grow the size if needed
    mov di, bx
    shl di, 1
    add [cs:dos_handle_pos + di], ax
    mov cx, [cs:dos_handle_pos + di]
    cmp cx, [cs:dos_handle_size + di]
    jbe .h40_size_ok
    mov [cs:dos_handle_size + di], cx
.h40_size_ok:
    mov byte [cs:dos_handle_modified + bx], 1
    mov [cs:dos_result], ax
    dos_clr_cf
    jmp .h40_exit
.h40_buffer_full:
    ; the buffer is full at this position: write 0 bytes
    mov word [cs:dos_result], 0
    dos_clr_cf
    jmp .h40_exit
.h40_error:
    mov word [cs:dos_result], 0x0006
    dos_set_cf
.h40_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ==================================================================
; AH=42h - Seek. BX = handle, CX:DX = offset, AL = origin.
; OUT: DX:AX = new position.
; ==================================================================
com_42h:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    cmp bx, MAX_HANDLES
    jae .h42_error
    cmp byte [cs:dos_handle_inuse + bx], 0
    je .h42_error

    ; only 16-bit offsets are supported (CX must be 0)
    test cx, cx
    jnz .h42_error

    mov di, bx
    shl di, 1

    cmp al, 0
    je .h42_from_start
    cmp al, 1
    je .h42_from_current
    cmp al, 2
    je .h42_from_end
    jmp .h42_error

.h42_from_start:
    mov [cs:dos_handle_pos + di], dx
    jmp .h42_done
.h42_from_current:
    add [cs:dos_handle_pos + di], dx
    jmp .h42_done
.h42_from_end:
    mov ax, [cs:dos_handle_size + di]
    add ax, dx
    mov [cs:dos_handle_pos + di], ax
.h42_done:
    mov ax, [cs:dos_handle_pos + di]
    mov [cs:dos_result], ax
    xor dx, dx
    dos_clr_cf
    jmp .h42_exit
.h42_error:
    mov word [cs:dos_result], 0x0006
    dos_set_cf
.h42_exit:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret
