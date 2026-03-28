; ==================================================================
; x16-PRos - Font loading (.FNT) support
; Copyright (C) 2025 PRoX2011
;
; Loads 8x16 bitmap fonts (4096 bytes, 256 chars) from FONTS.DIR/.
; Hooks INT 43h so BIOS TTY and programs pick up the custom font.
; Font data lives at FONT_SEG:0000 (physical 0x10000)
;
; https://wikipedia.org/wiki/CP866
; ==================================================================

font_loaded    db 0
fnt_dir_name   db 'FONTS.DIR', 0
fnt_default    db 'DEFAULT.FNT', 0
fnt_cfg_name   db 'FONT.CFG', 0
fnt_load_name  dw 0
fnt_cfg_buf    times 16 db 0

; ========================================================================
; FONT_LOAD_FROM_CFG - Read CONF.DIR/FONT.CFG, then load that .FNT
; Falls back to DEFAULT.FNT if config missing or empty.
; OUT : CF = 0 success, CF = 1 error
; ========================================================================
font_load_from_cfg:
    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call save_current_dir

    mov al, 'A'
    call fs_change_drive_letter
    call fs_parent_directory

    mov ax, conf_dir_name
    call fs_change_directory
    jc .cfg_fail

    mov ax, fnt_cfg_name
    mov cx, program_load_addr
    call fs_load_file
    jc .cfg_fail

    test bx, bx
    je .cfg_fail

    ; Null-terminate at file size
    mov si, program_load_addr
    add si, bx
    mov byte [si], 0

    ; Strip CR/LF/spaces, copy to fnt_cfg_buf
    mov si, program_load_addr
    mov di, fnt_cfg_buf
    mov cx, 15
.copy_cfg:
    lodsb
    cmp al, 0x0D
    je .copy_done
    cmp al, 0x0A
    je .copy_done
    cmp al, 0
    je .copy_done
    stosb
    dec cx
    jnz .copy_cfg
.copy_done:
    mov byte [di], 0

    cmp byte [fnt_cfg_buf], 0
    je .cfg_fail

    call restore_current_dir
    pop es
    pop ds
    popa

    mov si, fnt_cfg_buf
    jmp font_load_file

.cfg_fail:
    call restore_current_dir
    pop es
    pop ds
    popa
    jmp font_load_default

; ========================================================================
; FONT_LOAD_DEFAULT - Load FONTS.DIR/DEFAULT.FNT into FONT_SEG
; OUT : CF = 0 success, CF = 1 file missing / error
; ========================================================================
font_load_default:
    mov word [fnt_load_name], fnt_default
    jmp short font_load_core

; ========================================================================
; FONT_LOAD_FILE - Load an arbitrary .FNT from FONTS.DIR/
; IN  : SI = pointer to filename
; OUT : CF = 0 success, CF = 1 error
; ========================================================================
font_load_file:
    mov word [fnt_load_name], si

font_load_core:
    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call save_current_dir

    mov al, 'A'
    call fs_change_drive_letter

    call fs_parent_directory

    mov ax, fnt_dir_name
    call fs_change_directory
    jc .fail

    ; Load .FNT file into FONT_SEG:0000 via fs_load_huge_file
    mov ax, [fnt_load_name]
    xor cx, cx
    mov dx, FONT_SEG
    call fs_load_huge_file
    jc .fail

    ; Verify size: DX:AX = file size, expect exactly 4096
    test dx, dx
    jne .fail
    cmp ax, 4096
    jne .fail

    call font_install_from_buf

    call restore_current_dir
    pop es
    pop ds
    popa
    clc
    ret

.fail:
    call restore_current_dir
    pop es
    pop ds
    popa
    stc
    ret

; ========================================================================
; FONT_INSTALL_FROM_BUF - Hook INT 43h to point at FONT_SEG:0000
; ========================================================================
font_install_from_buf:
    push es
    push ax

    cli
    xor ax, ax
    mov es, ax
    mov word [es:0x43*4],   0x0000
    mov word [es:0x43*4+2], FONT_SEG
    sti

    mov byte [font_loaded], 1

    pop ax
    pop es
    ret

; ========================================================================
; FONT_REINSTALL - Re-hook INT 43h from existing buffer (no disk I/O).
; Used after video mode resets to restore the loaded font.
; ========================================================================
font_reinstall:
    cmp byte [font_loaded], 1
    jne short .skip
    call font_install_from_buf
.skip:
    ret

; ========================================================================
; FONT_RESTORE - Restore BIOS ROM 8x16 font
; ========================================================================
font_restore:
    pusha
    push es

    mov ax, 1114h
    mov bl, 0
    int 10h

    pop es
    mov byte [font_loaded], 0
    popa
    ret
