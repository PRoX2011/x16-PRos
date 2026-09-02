; ==================================================================
; x16-PRos - MZ EXE file loader for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

EXE_PSP_SEG         equ 0x3040
EXE_LOAD_SEG        equ 0x3050

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
    mov [exe_name_ptr], ax
    cmp byte [exe_nested], 0
    jne .layout_ready
    mov word [exe_psp_seg], EXE_PSP_SEG
    mov word [exe_load_seg], EXE_LOAD_SEG
    mov word [exe_parent_psp], 0
    mov word [exe_tail_seg], 0
.layout_ready:

    xor cx, cx
    mov dx, [exe_load_seg]
    call fs_load_huge_file
    jnc .loaded

    pop ax
    mov si, exe_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret

.loaded:
    add ax, 15
    adc dx, 0
    mov cl, 4
    shr ax, cl
    mov bx, dx
    mov cl, 12
    shl bx, cl
    or ax, bx
    mov [exe_total_paras], ax

    pop ax

    mov ax, [exe_load_seg]
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
    mov [exe_hdr_paras], ax
    add ax, [exe_load_seg]
    mov [exe_image_seg], ax

    mov ax, [exe_load_seg]
    mov [exe_code_seg], ax

    mov ax, [exe_total_paras]
    sub ax, [exe_hdr_paras]
    add ax, 0x10
    mov [exe_prog_base], ax

    mov bx, [dosmem_top_seg]
    sub bx, [exe_psp_seg]

    mov ax, [es:MZ_MAX_ALLOC]
    test ax, ax
    jz .prog_all
    add ax, [exe_prog_base]
    jc .prog_all
    cmp ax, bx
    jae .prog_all
    mov [dosmem_prog_paras], ax
    jmp .prog_done
.prog_all:
    mov word [dosmem_prog_paras], 0
.prog_done:

    mov ax, [exe_psp_seg]
    mov [dosmem_prog_base], ax

    mov ax, [dosmem_prog_paras]
    test ax, ax
    jz .top_is_arena
    add ax, [exe_psp_seg]
    jmp short .top_done
.top_is_arena:
    mov ax, [dosmem_top_seg]
.top_done:
    mov [exe_mem_top], ax

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
    mov bp, [exe_image_seg]
    mov di, [exe_code_seg]

.reloc_loop:
    mov bx, [es:si]
    mov dx, [es:si+2]
    add si, 4

    push es
    mov ax, bp
    add ax, dx
    mov es, ax
    add [es:bx], di
    pop es

    loop .reloc_loop

.reloc_done:
    call exe_strip_header

    mov ax, KERNEL_DATA_SEG
    mov es, ax

    mov ax, [exe_psp_seg]
    mov si, [param_list]
    call exe_build_psp

    mov ax, [exe_psp_seg]
    mov [dos_current_psp], ax

    cmp byte [exe_nested], 0
    jne .nested_ctx

    mov [com_stack_save], sp
    mov [com_ss_save], ss
    mov byte [com_active], 1

    call api_dos_init
    call mouse_dos_begin

    mov ah, 0x00
    mov al, 0x03
    int 0x10
    jmp short .ctx_ready

.nested_ctx:
    mov byte [exe_nested], 0
    call dosmem_init

.ctx_ready:

    mov ax, [exe_code_seg]
    add ax, [exe_init_ss]
    mov bx, [exe_init_sp]

    mov dx, [exe_code_seg]
    add dx, [exe_init_cs]
    mov cx, [exe_init_ip]

    cli
    mov ss, ax
    mov sp, bx

    mov ax, [exe_psp_seg]
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

exe_strip_header:
    pusha
    push ds
    push es

    mov bx, [exe_hdr_paras]
    test bx, bx
    jz .done

    mov ax, [exe_total_paras]
    sub ax, bx
    jbe .done

    mov si, [exe_load_seg]
    add si, bx
    mov di, [exe_load_seg]
    mov bx, ax

.slide:
    mov cx, 0x0800
    cmp bx, cx
    jae .have_chunk
    mov cx, bx
.have_chunk:
    sub bx, cx

    push bx
    push cx
    push si
    push di

    mov ds, si
    mov es, di
    xor si, si
    xor di, di
    add cx, cx
    add cx, cx
    add cx, cx
    cld
    rep movsw

    pop di
    pop si
    pop cx
    pop bx

    add si, cx
    add di, cx
    test bx, bx
    jnz .slide

.done:
    pop es
    pop ds
    popa
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
    mov ax, [exe_parent_psp]
    test ax, ax
    jz .blank_psp

    push si
    push ds
    mov ds, ax
    xor si, si
    mov cx, 128
    cld
    rep movsw
    pop ds
    pop si
    jmp short .psp_ready

.blank_psp:
    xor ax, ax
    mov cx, 128
    cld
    rep stosw

.psp_ready:
    mov word [es:0x00], 0x20CD
    mov ax, [exe_mem_top]
    mov [es:0x02], ax
    mov ax, [exe_parent_psp]
    mov [es:0x16], ax
    push ds
    push si
    xor si, si
    mov ds, si
    mov si, [0x22 * 4]
    mov [es:0x0A], si
    mov si, [0x22 * 4 + 2]
    mov [es:0x0C], si
    mov si, [0x23 * 4]
    mov [es:0x0E], si
    mov si, [0x23 * 4 + 2]
    mov [es:0x10], si
    mov si, [0x24 * 4]
    mov [es:0x12], si
    mov si, [0x24 * 4 + 2]
    mov [es:0x14], si
    pop si
    pop ds
    push di
    mov di, 0x18
    xor al, al
.jft:
    cmp al, SFT_COUNT
    jae .jft_free
    mov [es:di], al
    jmp short .jft_step
.jft_free:
    mov byte [es:di], 0xFF
.jft_step:
    inc al
    inc di
    cmp al, 20
    jb .jft
    pop di

    mov word [es:0x32], 20
    mov word [es:0x34], 0x0018
    mov ax, es
    mov [es:0x36], ax
    mov ax, [dosmem_env_seg]
    mov [es:0x2C], ax
    call exe_build_env

    mov byte [es:0x50], 0xCD
    mov byte [es:0x51], 0x21
    mov byte [es:0x52], 0xCB

    cmp word [exe_tail_seg], 0
    je .plain_tail

    push ds
    push si
    mov si, [exe_tail_off]
    mov ds, [exe_tail_seg]
    mov di, 0x0080
    mov cx, 64
    cld
    rep movsw
    pop si
    pop ds
    jmp short .cmd_ready

.plain_tail:
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

.cmd_ready:
    pop ds
    pop es
    popa
    ret

exe_build_env:
    pusha
    push es

    mov ax, [dosmem_env_seg]
    mov es, ax
    xor di, di
    cld

    mov si, exe_env_strings
    mov cx, exe_env_strings_len
    rep movsb

    push ds
    pop es
    mov al, [current_drive_char]
    mov [cs:exe_env_drive], al
    mov ax, [dosmem_env_seg]
    mov es, ax
    xor di, di
    mov cx, exe_env_strings_len
.stamp:
    cmp byte [es:di + 1], ':'
    jne .stamp_next
    mov al, [cs:exe_env_drive]
    mov [es:di], al
.stamp_next:
    inc di
    loop .stamp
    mov di, exe_env_strings_len

    mov ax, 1
    stosw

    mov si, [exe_name_ptr]
    test si, si
    jz .no_name
.copy_name:
    lodsb
    stosb
    test al, al
    jnz .copy_name
    jmp .done

.no_name:
    xor al, al
    stosb

.done:
    pop es
    popa
    ret

exe_env_strings:
    db 'COMSPEC=A:\COMMAND.COM', 0
    db 'PATH=A:\', 0
    db 'TEMP=C:\', 0
    db 'TMP=C:\', 0
    db 0
exe_env_strings_len equ $ - exe_env_strings

exe_bad_sig_msg     db 'Not an EXE file (bad signature)', 10, 13, 0
exe_load_failed_msg db 'EXE load failed', 10, 13, 0

exe_env_drive       db 'A'

exe_extension       db '.EXE', 0

exe_code_seg        dw 0
exe_image_seg       dw 0
exe_hdr_paras       dw 0
exe_prog_base       dw 0
exe_total_paras     dw 0
exe_name_ptr        dw 0
exe_init_ss         dw 0
exe_init_sp         dw 0
exe_init_ip         dw 0
exe_init_cs         dw 0

exe_psp_seg         dw EXE_PSP_SEG
exe_load_seg        dw EXE_LOAD_SEG
exe_nested          db 0
exe_parent_psp      dw 0
exe_tail_seg        dw 0
exe_tail_off        dw 0
exe_mem_top         dw 0