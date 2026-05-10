; ==================================================================
; x16-PRos - PLE (PRos Large Executable) loader
; Copyright (C) 2026 PRoX2011
; ==================================================================

PLE_BASE_SEG        equ 0x3000       ; whole file is loaded here; segments
                                     ; live at PLE_BASE_SEG + (foff >> 4)
PLE_TEMP_SEG        equ PLE_BASE_SEG ; alias used by splash / logo readers

; PLE header field offsets
PLE_OFF_MAGIC       equ 0x00
PLE_OFF_VERSION     equ 0x04
PLE_OFF_ENTRY_SEG   equ 0x06
PLE_OFF_ENTRY_IP    equ 0x08
PLE_OFF_STACK_SEG   equ 0x0A
PLE_OFF_STACK_SP    equ 0x0C
PLE_OFF_INSN_COUNT  equ 0x0E
PLE_OFF_DESC        equ 0x10
PLE_OFF_AUTHOR      equ 0x30
PLE_OFF_LOGO        equ 0x40
PLE_OFF_TABLE       equ 0x1040

; Load instruction field offsets
PLE_INSN_TARGET     equ 0
PLE_INSN_FOFF       equ 2
PLE_INSN_SIZE       equ 6
PLE_INSN_SIZE_BYTES equ 8

; =======================================================================
; PLE_EXECUTE - Loads and executes a PLE file
; IN : AX = pointer to filename
; OUT : CF = 1 on error, otherwise does not return until program ends
; =======================================================================
ple_execute:
    push ax

    xor cx, cx
    mov dx, PLE_TEMP_SEG
    call fs_load_huge_file
    jnc .loaded

    pop ax
    mov si, ple_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret

.loaded:
    pop ax
    mov [ple_filename], ax

    push es
    push ds

    mov bx, PLE_BASE_SEG
    mov es, bx

    ; ---- Magic 'PLE',0 ----
    cmp word [es:PLE_OFF_MAGIC],     0x4C50    ; 'P','L'
    jne .bad_sig
    cmp word [es:PLE_OFF_MAGIC + 2], 0x0045    ; 'E', 0
    jne .bad_sig

    ; ---- Version ----
    cmp word [es:PLE_OFF_VERSION], 1
    jne .bad_version

    ; ---- Entry IP / SP / segment ids ----
    mov ax, [es:PLE_OFF_ENTRY_SEG]
    mov [ple_entry_seg_id], ax
    mov ax, [es:PLE_OFF_ENTRY_IP]
    mov [ple_entry_ip], ax
    mov ax, [es:PLE_OFF_STACK_SEG]
    mov [ple_stack_seg_id], ax
    mov ax, [es:PLE_OFF_STACK_SP]
    mov [ple_stack_sp], ax

    ; ---- Instruction count ----
    mov bx, [es:PLE_OFF_INSN_COUNT]
    test bx, bx
    jz  .bad_table
    mov [ple_insn_count], bx

    mov word [ple_entry_cs], 0
    mov word [ple_stack_ss], 0

    mov cx, [ple_insn_count]
    mov si, PLE_OFF_TABLE

.lookup_loop:
    mov bx, [es:si + PLE_INSN_TARGET]
    mov di, [es:si + PLE_INSN_FOFF]
    mov ax, [es:si + PLE_INSN_FOFF + 2]

    test di, 0x000F
    jnz .bad_align

    shl ax, 12
    shr di, 4
    or  di, ax
    add di, PLE_BASE_SEG

    cmp bx, [ple_entry_seg_id]
    jne .not_entry
    mov [ple_entry_cs], di
.not_entry:
    cmp bx, [ple_stack_seg_id]
    jne .not_stack
    mov [ple_stack_ss], di
.not_stack:

    add si, PLE_INSN_SIZE_BYTES
    loop .lookup_loop

    cmp word [ple_entry_cs], 0
    je  .bad_table
    cmp word [ple_stack_ss], 0
    je  .bad_table

    ; ---- Splash screen ----
    pop ds
    pop es
    call ple_show_splash

    mov [com_stack_save], sp
    mov [com_ss_save], ss

    call DisableMouse

    mov ax, [ple_stack_ss]
    mov bx, [ple_stack_sp]
    mov dx, [ple_entry_cs]
    mov cx, [ple_entry_ip]

    cli
    mov ss, ax
    mov sp, bx

    push cs
    push word .ple_done

    mov ax, [ple_entry_cs]
    mov ds, ax
    mov es, ax
    sti

    push dx                       ; entry CS
    push cx                       ; entry IP
    retf

.ple_done:
    cli
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, [com_ss_save]
    mov sp, [com_stack_save]
    sti

    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme
    ret

; ---- Error paths ----

.bad_sig:
    pop ds
    pop es
    mov si, ple_bad_sig_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_version:
    pop ds
    pop es
    mov si, ple_bad_version_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_table:
    pop ds
    pop es
    mov si, ple_bad_table_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_align:
    pop ds
    pop es
    mov si, ple_bad_align_msg
    call print_string_red
    call print_newline
    stc
    ret

; =======================================================================
; PLE_SHOW_SPLASH - Draws the splash and waits for any key.
; Uses ES = PLE_TEMP_SEG to read description / author / logo from the
; loaded file. Preserves all registers visible to the loader.
; =======================================================================
ple_show_splash:
    pusha
    push es
    push ds

    call print_newline

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    call ple_indent_text
    mov si, ple_label_name
    call print_string

    push ds
    mov ax, PLE_TEMP_SEG
    mov ds, ax
    mov si, PLE_OFF_DESC
    call print_string
    pop ds

    call print_newline

    call ple_indent_text
    mov si, ple_label_author
    call print_string

    push ds
    mov ax, PLE_TEMP_SEG
    mov ds, ax
    mov si, PLE_OFF_AUTHOR
    call print_string
    pop ds

    call print_newline

    call ple_indent_text
    mov si, ple_label_file
    call print_string
    mov si, [ple_filename]
    call print_string
    call print_newline

    call print_newline

    mov si, ple_press_key_msg
    call print_string

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov al, dh
    sub al, 4
    xor ah, ah
    mov bl, 16
    mul bl
    sub ax, 8
    mov [ple_logo_y0], ax
    mov word [ple_logo_x0], 0

    call ple_draw_logo

    ; ---- Wait for key ----
    xor ax, ax
    int 0x16

    call print_newline

    pop ds
    pop es
    popa
    ret

; =======================================================================
; PLE_INDENT_TEXT - Moves the BIOS text cursor on the current row to
; column 10, leaving room for the 64-px-wide logo on the left.
; =======================================================================
ple_indent_text:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x03
    xor bh, bh
    int 0x10                      ; DH = row, DL = col
    mov dl, 10
    mov ah, 0x02
    xor bh, bh
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ple_draw_logo:
    pusha
    push es
    push ds

    mov si, PLE_OFF_LOGO
    xor bp, bp

.row_loop:
    cmp bp, 64
    jae .done

    push ds
    mov ax, PLE_TEMP_SEG
    mov ds, ax
    mov ax, KERNEL_DATA_SEG
    mov es, ax
    mov di, ple_logo_row_buf
    mov cx, 64
    cld
    rep movsb
    pop ds

    xor di, di
.col_loop:
    cmp di, 64
    jae .row_done

    mov bx, ple_logo_row_buf
    add bx, di
    mov al, [bx]
    and al, 0x0F

    push ds
    push es
    push si
    push di
    push bp

    mov ah, 0x0C
    xor bh, bh
    mov cx, [ple_logo_x0]
    add cx, di
    mov dx, [ple_logo_y0]
    add dx, bp
    int 0x10

    pop bp
    pop di
    pop si
    pop es
    pop ds

    inc di
    jmp .col_loop

.row_done:
    inc bp
    jmp .row_loop

.done:
    pop ds
    pop es
    popa
    ret

ple_load_failed_msg  db 'PLE load failed', 10, 13, 0
ple_bad_sig_msg      db 'Not a PLE file (bad signature)', 10, 13, 0
ple_bad_version_msg  db 'Unsupported PLE version', 10, 13, 0
ple_bad_table_msg    db 'PLE: bad load table', 10, 13, 0
ple_bad_align_msg    db 'PLE: segment not paragraph aligned', 10, 13, 0
ple_press_key_msg    db 'Press any key to run...', 0

ple_label_name       db 'Name:    ', 0
ple_label_author     db 'Author:  ', 0
ple_label_file       db 'File:    ', 0

ple_extension        db '.PLE', 0

ple_filename         dw 0
ple_entry_seg_id     dw 0
ple_stack_seg_id     dw 0
ple_entry_cs         dw 0
ple_entry_ip         dw 0
ple_stack_ss         dw 0
ple_stack_sp         dw 0
ple_insn_count       dw 0

ple_splash_row       db 0
ple_logo_x0          dw 0
ple_logo_y0          dw 0
ple_row_off          dw 0
ple_pix_color        db 0
ple_logo_row_buf     resb 64