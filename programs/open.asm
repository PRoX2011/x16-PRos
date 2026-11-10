; ==================================================================
; x16-PRos -- OPEN. Launching programs based on file associations.
;
; Usage: OPEN <file>
;
; Made by NXFORGE
; ==================================================================

[BITS 16]
[ORG 0x8000]

; === Constants ===

TRAMPOLINE_ADDR equ 0xFC00
TRAMPOLINE_DIR  equ 0xFD00
TRAMPOLINE_BIN  equ 0xFD20
TRAMPOLINE_ERR  equ 0xFD40 ; for program error
TRAMPOLINE_ARGS equ 0xFD70

start:
    mov ax, cs
    mov ds, ax

    mov [file], si

    test si, si
    jz .usage

    jmp open

.usage:
    mov ah, 0x04
    mov si, usage_msg
    int 0x21
    ret

open:
    call get_type
    
    cmp word [type], 0 ; type check
    je .type_err


    ; === Comparison with basic types ===

    ; For Developer:
    ; -----------------------
    ;    mov di, <type>
    ;    mov bx, <program>
    ;    call check_type
    ; -----------------------
    ; To add your association,
    ; you need to enter the name of the variable 
    ; containing the association name into `<type>`
    ; (e.g., `type_str db 'TYP', 0`;
    ;  it must be exactly 3 characters long),
    ; and the name of the variable
    ; containing the program name into `<program>`
    ; (e.g., `type_bin db 'PROGRAM.BIN', 0`;
    ;  it must end with '.BIN').

    mov di, txt_str
    mov bx, txt_bin
    call check_type

    mov di, imf_str
    mov bx, imf_bin
    call check_type

    mov di, wav_str
    mov bx, wav_bin
    call check_type

    mov di, asm_str
    mov bx, asm_bin
    call check_type

    jmp .type_err

.type_err:
    mov ah, 0x04
    mov si, type_err_msg
    int 0x21
    ret

; ==================================================================
;  get_type - Return the file type in uppercase
;  IN:  SI = file name
;  OUT: TYPE = file type
; ==================================================================
get_type:
    lodsb

    cmp al, '.'
    je .found_dot

    test al, al
    jz .done

    jmp get_type

.found_dot:
    mov [type], si
    mov cx, 3

.loop:
    mov al, [si]
    test al, al
    jz .done

    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next

    sub byte [si], 32

.next:
    inc si
    loop .loop

.done:
    ret

; ==================================================================
;  check_type - Check the file type and launch the program
;  IN: DI = file type to check
;      BX = program name
; ==================================================================
check_type:
    mov si, [type]
    mov cx, 3

    repe cmpsb
    jne .done

    mov si, bx
    jmp run_program

.done:
    ret

; ==================================================================
;  run_program - Trampoline-based launch of a sibling .BIN
;  IN: SI = program name
;
;  NOTE: This function is called from check_type
; ==================================================================
run_program:
    pop ax ; reset return .check_type

    mov di, TRAMPOLINE_BIN
    call copy_str

    mov si, bin_dir_name
    mov di, TRAMPOLINE_DIR
    call copy_str

    mov si, [file]
    mov di, TRAMPOLINE_ARGS
    call copy_str

    mov si, prog_err_msg
    mov di, TRAMPOLINE_ERR
    call copy_str

    mov si, trampoline_code
    mov di, TRAMPOLINE_ADDR
    mov cx, trampoline_end - trampoline_code
    rep movsb

    jmp TRAMPOLINE_ADDR

trampoline_code:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov ah, 0x09
    mov si, TRAMPOLINE_DIR
    int 0x22

    mov ah, 0x02
    mov si, TRAMPOLINE_BIN
    mov cx, 0x8000
    int 0x22
    jc .t_fail

    mov ah, 0x0F
    int 0x22

    mov ax, 0x8000
    mov si, TRAMPOLINE_ARGS
    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor di, di
    jmp ax

.t_fail:
    mov ah, 0x0F ; restore current directory after an error
    int 0x22

    mov ah, 0x04
    mov si, TRAMPOLINE_ERR
    int 0x21

    ret

trampoline_end:

copy_str:
    lodsb
    stosb
    test al, al
    jne copy_str
    ret

; === Variables ===

usage_msg    db 'Usage: OPEN <file>', 10, 13, 0
type_err_msg db 'Error: Unknown type', 10, 13, 0
prog_err_msg db 'Error: Program not found', 10, 13, 0

bin_dir_name db 'BIN.DIR', 0

txt_str db 'TXT', 0
imf_str db 'IMF', 0
wav_str db 'WAV', 0
asm_str db 'ASM', 0

txt_bin db 'WRITER.BIN', 0
imf_bin db 'IMFPLAY.BIN', 0
wav_bin db 'WAVPLAY.BIN', 0
asm_bin db 'PRASM.BIN', 0

file dw 0
type dw 0