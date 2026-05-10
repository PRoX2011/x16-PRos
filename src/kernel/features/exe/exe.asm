; ==================================================================
; x16-PRos - MZ EXE file loader for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

EXE_PSP_SEG         equ 0x3000
EXE_LOAD_SEG        equ 0x3010

; MZ header offsets
MZ_SIGNATURE        equ 0x00
MZ_LAST_PAGE_BYTES  equ 0x02
MZ_PAGE_COUNT       equ 0x04
MZ_RELOC_COUNT      equ 0x06
MZ_HEADER_PARAS     equ 0x08
MZ_MIN_ALLOC        equ 0x0A
MZ_MAX_ALLOC        equ 0x0C
MZ_INIT_SS          equ 0x0E
MZ_INIT_SP          equ 0x10
MZ_CHECKSUM         equ 0x12
MZ_INIT_IP          equ 0x14
MZ_INIT_CS          equ 0x16
MZ_RELOC_TABLE_OFF  equ 0x18
MZ_OVERLAY_NUM      equ 0x1A

; =======================================================================
; EXE_EXECUTE - Loads and executes an MZ EXE file
; IN : AX = pointer to filename (ASCIIZ, in DS=KERNEL_DATA_SEG)
; OUT : CF = 1 on error
; =======================================================================
exe_execute:
    push ax

    xor cx, cx
    mov dx, EXE_LOAD_SEG
    call fs_load_huge_file
    jnc .loaded

    pop ax
    mov si, exe_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret

.loaded:
    pop ax

    mov ax, EXE_LOAD_SEG
    mov es, ax

    mov ax, [es:MZ_SIGNATURE]
    cmp ax, 0x5A4D
    je .sig_ok
    cmp ax, 0x4D5A
    je .sig_ok
    jmp .bad_sig

.sig_ok:
    mov ax, [es:MZ_OVERLAY_NUM]
    test ax, ax
    jnz .bad_sig

    mov ax, [es:MZ_HEADER_PARAS]
    add ax, EXE_LOAD_SEG
    mov [exe_code_seg], ax

    mov ax, [es:MZ_INIT_SS]
    mov [exe_init_ss], ax
    mov ax, [es:MZ_INIT_SP]
    mov [exe_init_sp], ax
    mov ax, [es:MZ_INIT_IP]
    mov [exe_init_ip], ax
    mov ax, [es:MZ_INIT_CS]
    mov [exe_init_cs], ax

    mov cx, [es:MZ_RELOC_COUNT]
    test cx, cx
    jz .reloc_done

    mov si, [es:MZ_RELOC_TABLE_OFF]
    mov bp, [exe_code_seg]

.reloc_loop:
    mov bx, [es:si]
    mov dx, [es:si+2]
    add si, 4

    push es
    mov ax, bp
    add ax, dx
    mov es, ax
    add [es:bx], bp
    pop es

    loop .reloc_loop

.reloc_done:
    mov ax, KERNEL_DATA_SEG
    mov es, ax

    mov ax, EXE_PSP_SEG
    mov si, [param_list]
    call exe_build_psp

    mov [com_stack_save], sp
    mov [com_ss_save], ss

    call api_dos_init
    call DisableMouse

    mov ax, [exe_code_seg]
    add ax, [exe_init_ss]
    mov bx, [exe_init_sp]

    mov dx, [exe_code_seg]
    add dx, [exe_init_cs]
    mov cx, [exe_init_ip]

    cli
    mov ss, ax
    mov sp, bx

    mov ax, EXE_PSP_SEG
    mov ds, ax
    mov es, ax
    sti

    push dx
    push cx
    retf

.bad_sig:
    mov si, exe_bad_sig_msg
    call print_string_red
    call print_newline
    stc
    ret

; =======================================================================
; EXE_BUILD_PSP - Constructs a 256-byte PSP at PSP_seg:0000
; IN : AX = PSP segment
;      SI = pointer to ASCIIZ command line (kernel DS), 0 = none
; OUT : (none)
; =======================================================================
exe_build_psp:
    pusha
    push es
    push ds

    mov es, ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    xor di, di
    xor ax, ax
    mov cx, 128
    rep stosw

    mov word [es:0x00], 0x20CD
    mov word [es:0x02], 0xA000
    mov word [es:0x2C], 0x0000

    mov byte [es:0x50], 0xCD
    mov byte [es:0x51], 0x21
    mov byte [es:0x52], 0xCB

    mov di, 0x81
    xor cx, cx

    test si, si
    jz .cmd_done

.cmd_loop:
    lodsb
    test al, al
    jz .cmd_done
    cmp cx, 126
    jae .cmd_done
    stosb
    inc cx
    jmp .cmd_loop

.cmd_done:
    mov [es:0x80], cl
    mov byte [es:di], 0x0D

    pop ds
    pop es
    popa
    ret

exe_bad_sig_msg     db 'Not an EXE file (bad signature)', 10, 13, 0
exe_load_failed_msg db 'EXE load failed', 10, 13, 0

exe_extension       db '.EXE', 0

exe_code_seg        dw 0
exe_init_ss         dw 0
exe_init_sp         dw 0
exe_init_ip         dw 0
exe_init_cs         dw 0