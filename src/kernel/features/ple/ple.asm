; ==================================================================
; x16-PRos - PLE (PRos Large Executable) loader
; Copyright (C) 2026 PRoX2011
; ==================================================================

PLE_MAX_PARAS       equ 0x2000

; PLE header field offsets
PLE_OFF_MAGIC       equ 0x00          ; 'P','L','E' (3 bytes)
PLE_OFF_FLAGS       equ 0x03          ; flags byte (see PLE_HF_* below)
PLE_OFF_VERSION     equ 0x04

; Header flag bits
PLE_HF_NO_SPLASH    equ 0x01
PLE_HF_NO_WAIT      equ 0x02
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
; PLE_LOAD - allocates memory, loads file, validates the header, and
; resolves entry/stack segment ids into absolute segments.
; IN : AX = pointer to filename
; OUT : CF = 0 on success, with ple_base_seg / ple_entry_cs / ple_entry_ip
;            / ple_stack_ss / ple_stack_sp / ple_filename filled in.
;       CF = 1 on any failure. On error the arena (if allocated) is freed
;            and a red diagnostic message is printed.
; =======================================================================
ple_load:
    mov [ple_filename], ax

    mov ax, [ple_filename]
    call fs_get_file_size
    jc .alloc_failed
    add ebx, 15
    shr ebx, 4
    add ebx, 0x1000
    cmp ebx, PLE_MAX_PARAS
    jbe .have_paras
    mov ebx, PLE_MAX_PARAS
.have_paras:
    call mem_alloc
    jc .alloc_failed
    mov [ple_base_seg], ax

    mov ax, [ple_filename]
    xor cx, cx
    mov dx, [ple_base_seg]
    call fs_load_huge_file
    jnc .loaded

    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret

.alloc_failed:
    mov si, ple_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret

.loaded:
    push es
    push ds

    mov bx, [ple_base_seg]
    mov es, bx

    ; ---- Magic 'PLE' (byte at +3 is the flags byte) ----
    cmp word [es:PLE_OFF_MAGIC], 0x4C50        ; 'P','L'
    jne .bad_sig
    cmp byte [es:PLE_OFF_MAGIC + 2], 'E'
    jne .bad_sig

    ; ---- Header flags ----
    mov al, [es:PLE_OFF_FLAGS]
    mov [ple_hdr_flags], al

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
    jz .bad_table
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
    or di, ax
    add di, [ple_base_seg]

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
    je .bad_table
    cmp word [ple_stack_ss], 0
    je .bad_table

    pop ds
    pop es
    clc
    ret

.bad_sig:
    pop ds
    pop es
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_bad_sig_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_version:
    pop ds
    pop es
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_bad_version_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_table:
    pop ds
    pop es
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_bad_table_msg
    call print_string_red
    call print_newline
    stc
    ret

.bad_align:
    pop ds
    pop es
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_bad_align_msg
    call print_string_red
    call print_newline
    stc
    ret

; =======================================================================
; PLE_EXECUTE - foreground launch.
; IN : AX = pointer to filename
;      BL = launch flags (bit 0 = show splash + wait for key; 0 = silent)
; OUT : CF = 1 on load failure, otherwise 0.
; =======================================================================
ple_execute:
    mov [ple_exec_flags], bl
    call ple_load
    jc .load_failed
    mov bl, [ple_exec_flags]
    jmp ple_run_loaded

.load_failed:
    ret

; =======================================================================
; PLE_RUN_LOADED - runs an already-loaded PLE (skips ple_load).
; IN : BL = launch flags (bit 0 = show splash + wait for key; 0 = silent)
;      ple_base_seg / ple_filename / ple_entry_* already populated by
;      a prior ple_load.
; OUT : CF = 0 on success, CF = 1 if no task slot was free.
; =======================================================================
ple_run_loaded:
    mov [ple_exec_flags], bl

    test byte [ple_exec_flags], 0x01
    jz .skip_splash
    test byte [ple_hdr_flags], PLE_HF_NO_SPLASH
    jnz .skip_splash
    call ple_show_splash
.skip_splash:

    call DisableMouse

    xor al, al
    call sched_task_create_from_ple
    jc .no_slot

    push ax
    mov si, [ple_filename]
    call sched_task_set_name
    pop ax

    mov [sched_disp_child], al
    push bx
    xor bh, bh
    mov bl, al
    shl bx, 4
    mov al, [sched_cur_task]
    mov [sched_tasks + bx + TASK_PARENT], al
    pop bx

    call sched_dispatch

    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme
    clc
    ret

.no_slot:
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_no_slot_msg
    call print_string_red
    call print_newline
    stc
    ret

; =======================================================================
; PLE_EXECUTE_BG - background launch.
; IN : AX = pointer to filename
; OUT : CF = 1 on failure, otherwise 0. AX = new task id on success.
; =======================================================================
ple_execute_bg:
    call ple_load
    jc .load_failed

    mov al, TASK_F_BACKGROUND
    call sched_task_create_from_ple
    jc .no_slot

    push ax
    mov si, [ple_filename]
    call sched_task_set_name
    pop ax

    xor ah, ah
    clc
    ret

.no_slot:
    mov ax, [ple_base_seg]
    call mem_free
    mov si, ple_no_slot_msg
    call print_string_red
    call print_newline
    stc
    ret

.load_failed:
    ret

ple_task_done:
    cli
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    sti

    call fs_reset_floppy

    pushf
    push cs
    push word .never
    pusha
    push ds
    push es

    jmp sched_exit

.never:
    ret

; =======================================================================
; PLE_SHOW_SPLASH - Draws the splash and waits for any key.
; Uses DS = [ple_base_seg] to read description / author / logo from the
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
    mov ax, [ple_base_seg]
    mov ds, ax
    mov si, PLE_OFF_DESC
    call print_string
    pop ds

    call print_newline

    call ple_indent_text
    mov si, ple_label_author
    call print_string

    push ds
    mov ax, [ple_base_seg]
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

    test byte [ple_hdr_flags], PLE_HF_NO_WAIT
    jnz .skip_press_msg
    mov si, ple_press_key_msg
    call print_string
.skip_press_msg:

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
    test byte [ple_hdr_flags], PLE_HF_NO_WAIT
    jnz .skip_wait
    xor ax, ax
    int 0x16
.skip_wait:

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
    mov ax, [ple_base_seg]
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
ple_no_slot_msg      db 'PLE: no task slot available', 10, 13, 0
ple_press_key_msg    db 'Press any key to run...', 0

ple_label_name       db 'Name:    ', 0
ple_label_author     db 'Author:  ', 0
ple_label_file       db 'File:    ', 0

ple_extension        db '.PLE', 0

ple_filename         dw 0
ple_base_seg         dw 0
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
ple_logo_row_buf     times 64 db 0
ple_exec_flags       db 0
ple_hdr_flags        db 0