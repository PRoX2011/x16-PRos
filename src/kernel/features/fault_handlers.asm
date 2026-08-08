; ==================================================================
; x16-PRos - CPU exception handlers
; Copyright (C) 2025 PRoX2011
;
; Installs handlers for the fault vectors that a crashing program can
; trigger in REAL MODE. IMPORTANT: vectors 0x08-0x0F are hardware
; IRQs in real mode (0x08=timer, 0x09=keyboard, 0x0E=floppy), so we
; only hook vectors that are pure CPU exceptions in real mode:
;   #DE (vector 0x00, divide error)
;   #UD (vector 0x06, invalid opcode)
;
; Instead of the machine triple-faulting / rebooting, the fault is
; reported with the faulting CS:IP and control returns to the shell.
; A fault inside kernel code (CS = KERNEL_DATA_SEG) or more than
; MAX_FAULTS consecutive faults halts the machine to avoid an
; infinite fault loop.
; ==================================================================

MAX_FAULTS equ 8

fault_ss_save dw 0
fault_sp_save dw 0
fault_cs      dw 0
fault_ip      dw 0
fault_count   db 0

; ==================================================================
; INIT_FAULT_HANDLERS - installs the fault vectors and saves the
; kernel recovery stack. Called once during init.
; ==================================================================
init_fault_handlers:
    push ax
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x00*4], fault_handler_de
    mov word [es:0x00*4+2], cs
    mov word [es:0x06*4], fault_handler_ud
    mov word [es:0x06*4+2], cs
    sti
    mov [fault_ss_save], ss
    mov [fault_sp_save], sp
    pop es
    pop ax
    ret

fault_handler_de:
    mov si, .de_msg
    jmp fault_handler_common
.de_msg db 'Fault: Divide error (#DE)', 0

fault_handler_ud:
    mov si, .ud_msg
    jmp fault_handler_common
.ud_msg db 'Fault: Invalid opcode (#UD)', 0

fault_handler_gp:
    mov si, .gp_msg
    jmp fault_handler_common
.gp_msg db 'Fault: General protection (#GP)', 0

fault_handler_pf:
    mov si, .pf_msg
    jmp fault_handler_common
.pf_msg db 'Fault: Page fault (#PF)', 0

; ==================================================================
; FAULT_HANDLER_COMMON - SI = fault message.
; Entry stack (pushed by the INT n): [SP] = IP, [SP+2] = CS, [SP+4] = FLAGS
; ==================================================================
fault_handler_common:
    mov bp, sp
    mov ax, [ss:bp]          ; faulting IP
    mov [fault_ip], ax
    mov bx, [ss:bp+2]        ; faulting CS
    mov [fault_cs], bx

    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    sti

    ; A fault inside the kernel would only recur; halt in that case.
    cmp bx, KERNEL_DATA_SEG
    je .halt_kernel_fault

    inc byte [fault_count]
    cmp byte [fault_count], MAX_FAULTS
    jae .halt_kernel_fault

    call print_string_red
    call print_newline

    mov si, .at_msg
    call print_string
    mov ax, [fault_cs]
    call print_hex_word
    mov al, ':'
    mov bl, COLOR_WHITE
    call print_char
    mov ax, [fault_ip]
    call print_hex_word
    call print_newline
    call print_newline

    mov si, .return_msg
    call print_string_yellow
    call print_newline

    pop es
    pop ds
    popa

    ; Re-establish a sane execution environment.
    mov byte [current_program_type], 0
    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme

    cli
    mov ss, [fault_ss_save]
    mov sp, [fault_sp_save]
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    sti

    jmp get_cmd

.halt_kernel_fault:
    mov si, .kernel_fault_msg
    call print_string_red
    call print_newline
    mov si, .at_msg
    call print_string
    mov ax, [fault_cs]
    call print_hex_word
    mov al, ':'
    mov bl, COLOR_WHITE
    call print_char
    mov ax, [fault_ip]
    call print_hex_word
    call print_newline
    cli
    hlt
    jmp $

.at_msg          db '  at ', 0
.return_msg      db 'Program terminated. Returning to shell...', 0
.kernel_fault_msg db 'Kernel fault - system halted', 0

; ==================================================================
; ABORT_PROGRAM_TO_SHELL - Ctrl+Shift+F1 was pressed while a program
; was running. Abandons the program's context and returns to the
; shell. Called from check_abort_hotkey (INT 0x16 hook) or the
; INT 0x1C timer hook.
; IN : AL = previous program type (1 = BIN/PLE, 2 = COM/EXE)
; OUT: never returns (jumps to get_cmd)
; ==================================================================
abort_program_to_shell:
    mov dl, al                  ; remember the program type
    cli
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov byte [current_program_type], 0
    mov ss, [fault_ss_save]
    mov sp, [fault_sp_save]
    sti

    mov si, .msg
    call print_string_yellow
    call print_newline

    ; COM/EXE programs install the DOS INT 0x21 hook; remove it.
    cmp dl, 2
    jne .no_ivt
    push es
    push si
    push di
    push cx
    xor ax, ax
    mov es, ax
    mov si, saved_interrupt_table
    xor di, di
    mov cx, 512
    rep movsw
    pop cx
    pop di
    pop si
    pop es
.no_ivt:

    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme
    call api_output_init

    jmp get_cmd
.msg db 'Program aborted. Returning to shell...', 0

; ==================================================================
; PRINT_HEX_WORD - prints AX as 4 hex digits (no prefix).
; ==================================================================
print_hex_word:
    push ax
    push bx
    push cx
    push di
    mov cx, 4
    mov di, .hex_buf + 3
.hex_loop:
    mov bx, ax
    and bx, 0x000F
    mov dl, [.hex_chars + bx]
    mov [di], dl
    dec di
    shr ax, 4
    loop .hex_loop
    mov si, .hex_buf
    call print_string
    pop di
    pop cx
    pop bx
    pop ax
    ret

.hex_chars db '0123456789ABCDEF'
.hex_buf times 5 db 0
