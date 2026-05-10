; ==================================================================
; x16-PRos -- CPU. Utility to show CPU info for x16-PRos
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

start:
    mov ah, 0x05
    int 0x21

    pusha

    ; Print FLAGS register
    mov ah, 0x01
    mov si, flags_str
    int 0x21

    xor ax, ax
    lahf
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Control Register (CR0)
    mov ah, 0x01
    mov si, control_reg
    int 0x21

    mov eax, cr0
    call print_decimal

    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    ; Print Code Segment (CS)
    mov ah, 0x01
    mov si, code_segment
    int 0x21

    mov ax, cs
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Data Segment (DS)
    mov ah, 0x01
    mov si, data_segment
    int 0x21

    mov ax, ds
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Extra Segment (ES)
    mov ah, 0x01
    mov si, extra_segment
    int 0x21

    mov ax, es
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Stack Segment (SS)
    mov ah, 0x01
    mov si, stack_segment
    int 0x21

    mov ax, ss
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Base Pointer (BP)
    mov ah, 0x01
    mov si, base_pointer
    int 0x21

    mov ax, bp
    call print_decimal

    mov ah, 0x05
    int 0x21

    ; Print Stack Pointer (SP)
    mov ah, 0x01
    mov si, stack_pointer
    int 0x21

    mov ax, sp
    call print_decimal

    mov ah, 0x05
    int 0x21

    mov ah, 0x05
    int 0x21

    popa
    pusha

    ; Print CPU Family name
    mov ah, 0x01
    mov si, family_str
    int 0x21

    mov eax, 1
    cpuid
    mov ebx, eax
    shr eax, 8
    and eax, 0x0F

    mov ecx, ebx
    shr ecx, 20
    and ecx, 0xFF
    add eax, ecx

    mov si, family_table

.lookup_loop:
    cmp word [si], 0
    je .unknown_family
    cmp ax, word [si]
    je .found_family
    add si, 4
    jmp .lookup_loop

.found_family:
    mov si, word [si + 2]
    mov ah, 0x03
    int 0x21
    jmp .family_done

.unknown_family:
    mov si, unknown_family_str
    mov ah, 0x03
    int 0x21

.family_done:
    mov ah, 0x05
    int 0x21

    ; Print CPU name
    mov ah, 0x01
    mov si, cpu_name
    int 0x21

    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part

    mov ah, 0x05
    int 0x21

    call print_cores

    mov ah, 0x05
    int 0x21

    call print_cache_line

    mov ah, 0x05
    int 0x21

    call print_stepping

    mov ah, 0x05
    int 0x21

    popa

    mov ah, 0x05
    int 0x21

    ret

; =========================

print_edx:
    mov ah, 0eh
    mov bx, 4
.loop4r:
    mov al, dl
    int 10h
    ror edx, 8
    dec bx
    jnz .loop4r
    ret

print_full_name_part:
    cpuid
    push edx
    push ecx
    push ebx
    push eax
    mov cx, 4
.loop4n:
    pop edx
    call print_edx
    loop .loop4n
    ret

print_cores:
    mov ah, 0x01
    mov si, cores
    int 0x21

    mov eax, 1
    cpuid
    ror ebx, 16
    mov al, bl
    call print_al
    ret

print_cache_line:
    mov ah, 0x01
    mov si, cache_line
    int 0x21

    mov eax, 1
    cpuid
    ror ebx, 8
    mov al, bl
    mov bl, 8
    mul bl
    call print_al
    ret

print_stepping:
    mov ah, 0x01
    mov si, stepping
    int 0x21

    mov eax, 1
    cpuid
    and al, 15
    call print_al
    ret

print_al:
    mov ah, 0
    mov dl, 10
    div dl
    add ax, '00'
    mov dx, ax

    mov al, dl
    cmp dl, '0'
    jz .skip_tens
    mov ah, 0x0E
    xor bh, bh
    int 0x10

.skip_tens:
    mov al, dh
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret

; =========================

print_decimal:
    pusha
    mov cx, 0
    cmp ax, 0
    jne .divloop
    mov ah, 0x0E
    mov al, '0'
    mov bl, 0x0B
    int 0x10
    jmp .pddone
.divloop:
    cmp ax, 0
    je .printdigits
    mov bx, 10
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .divloop
.printdigits:
    mov ah, 0x0E
    mov bl, 0x0B
.digitloop:
    pop dx
    mov al, dl
    add al, '0'
    int 0x10
    dec cx
    jnz .digitloop
.pddone:
    popa
    ret
    
section .data

flags_str          db '  FLAGS: ', 0
control_reg        db '  Control Reg   (CR) : ', 0
stack_segment      db '  Stack Seg     (SS) : ', 0
code_segment       db '  Code Seg      (CS) : ', 0
data_segment       db '  Data Seg      (DS) : ', 0
extra_segment      db '  Extra Seg     (ES) : ', 0
base_pointer       db '  Base Pointer  (BP) : ', 0
stack_pointer      db '  Stack Pointer (SP) : ', 0

family_str         db '  CPU Family         : ', 0
unknown_family_str db 'Unknown', 0
intel_core_str     db 'Intel', 0
intel_pentium_str  db 'Intel Pentium', 0
amd_ryzen_str      db 'AMD Ryzen', 0
amd_athlon_str     db 'AMD Athlon', 0

family_table:
    dw 6, intel_core_str
    dw 5, intel_pentium_str
    dw 15, amd_athlon_str
    dw 21, amd_ryzen_str
    dw 0, 0

cpu_name           db '  CPU name           : ', 0
cores              db '  CPU cores          : ', 0
stepping           db '  Stepping ID        : ', 0
cache_line         db '  Cache line         : ', 0