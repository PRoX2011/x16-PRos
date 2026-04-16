; ========================================================================
; x16-PRos - MZ EXE file loader for x16-PRos.
;            Loads and executes 16-bit real-mode MZ EXE files
; ========================================================================
 
EXE_LOAD_SEG        equ 0x3000
 
; MZ header offsets
MZ_SIGNATURE        equ 0x00    ; 'MZ'
MZ_LAST_PAGE_BYTES  equ 0x02    ; Bytes on last page
MZ_PAGE_COUNT       equ 0x04    ; Pages in file (512 bytes each)
MZ_RELOC_COUNT      equ 0x06    ; Number of relocation entries
MZ_HEADER_PARAS     equ 0x08    ; Header size in paragraphs
MZ_MIN_ALLOC        equ 0x0A    ; Min extra paragraphs
MZ_MAX_ALLOC        equ 0x0C    ; Max extra paragraphs
MZ_INIT_SS          equ 0x0E    ; Initial SS
MZ_INIT_SP          equ 0x10    ; Initial SP
MZ_CHECKSUM         equ 0x12    ; Checksum (ignored)
MZ_INIT_IP          equ 0x14    ; Initial IP
MZ_INIT_CS          equ 0x16    ; Initial CS
MZ_RELOC_TABLE_OFF  equ 0x18    ; Offset of relocation table in file
MZ_OVERLAY_NUM      equ 0x1A    ; Overlay number
 
; ========================================================================
; exe_execute - Load and run an MZ EXE file
; IN:  AX = pointer (offset) to filename string (in DS=0x2000)
; OUT: CF set on error
; ========================================================================
exe_execute:
    push ax
 
    ; --- Step 1: Load file directly to EXE_LOAD_SEG:0x0000 ---
    xor cx, cx
    mov dx, EXE_LOAD_SEG
    call fs_load_huge_file
    jnc .file_loaded
 
    pop ax
    mov si, exe_load_failed_msg
    call print_string_red
    call print_newline
    stc
    ret
 
.file_loaded:
    pop ax
 
    ; --- Step 2: Validate MZ signature ---
    mov ax, EXE_LOAD_SEG
    mov es, ax
 
    mov ax, [es:MZ_SIGNATURE]
    cmp ax, 0x5A4D
    je .signature_ok
    cmp ax, 0x4D5A
    je .signature_ok
 
    mov si, exe_bad_sig_msg
    call print_string_red
    call print_newline
    stc
    ret
 
.signature_ok:
    ; --- Step 3: Check overlay number (must be 0) ---
    mov ax, [es:MZ_OVERLAY_NUM]
    test ax, ax
    jz .overlay_ok
 
    mov si, exe_bad_sig_msg
    call print_string_red
    call print_newline
    stc
    ret
 
.overlay_ok:
    ; --- Step 4: Compute code base segment ---
    ;   exe_code_seg = EXE_LOAD_SEG + header_paragraphs
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
 
    ; --- Step 5: Apply relocations ---
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
 
    ; --- Step 6: Setup and jump to EXE program ---
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
 
    mov ax, [exe_code_seg]
    mov ds, ax
    mov es, ax
    sti
 
    push word 0x0000
 
    push dx
    push cx
    retf
 
.exe_return:
    cli
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    mov ax, [exe_ss_save]
    mov ss, ax
    mov sp, [exe_stack_save]
    sti
 
    call fs_reset_floppy
    call EnableMouse
    call font_reinstall
    call load_and_apply_theme
 
    jmp get_cmd
 
exe_bad_sig_msg     db 'Not an EXE file (bad signature)', 10, 13, 0
exe_load_failed_msg db 'EXE load failed', 10, 13, 0
 
exe_extension       db '.EXE', 0
 
exe_code_seg        dw 0
exe_init_ss         dw 0
exe_init_sp         dw 0
exe_init_ip         dw 0
exe_init_cs         dw 0
exe_stack_save      dw 0
exe_ss_save         dw 0