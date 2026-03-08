; ==================================================================
; x16-PRos -- FETCH. Neofetch-like fetch tool for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
start:
    ; ------ Read USER config file to get user name ------

    ; Save current directory
    mov ah, 0x0E
    int 0x22

    ; Go to root
    mov ah, 0x0A
    int 0x22

    ; Switch to /CONF directory
    mov ah, 0x09
    mov si, conf_dir
    int 0x22

    ; Load username
    mov ah, 0x02
    mov si, user_cfg
    mov cx, buffer
    int 0x22

    ; Restore current directory
    mov ah, 0x0F
    int 0x22

    ; -----------------------------------------------------

    mov ah, 0x01
    mov si, ascii_art
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10

    mov [cursor_y], dh
    mov [cursor_x], dl

    sub dh, 25
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ------ The top of the fetch output ------
    mov ah, 0x01
    mov si, buffer
    int 0x21

    mov ah, 0x01
    mov si, dog_symbol
    int 0x21

    mov ah, 0x01
    mov si, os_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    mov ah, 0x01
    mov si, sep
    int 0x21

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ------------------ OS name --------------
    mov ah, 0x03
    mov si, os_msg
    int 0x21

    mov ah, 0x01
    mov si, os_full_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Host name --------------
    mov ah, 0x03
    mov si, host_name_msg
    int 0x21

    ; Get PC type
    push es
    mov ax, 0F000h
    mov es, ax
    mov al, [es:0FFFEh]
    mov [model_byte], al
    pop es

    ; Try INT 15/C0
    mov ah, 0C0h
    int 15h
    jc .use_model_only
    cmp ah, 0
    jne .use_model_only
    mov al, [es:bx+2]
    mov [model_byte], al
    mov al, [es:bx+3]
    mov [submodel_byte], al
    jmp .use_model_submodel

.use_model_only:
    mov al, [model_byte]
    cmp al, 0FFh
    je .set_pc
    cmp al, 0FEh
    je .set_xt
    cmp al, 0FDh
    je .set_pcjr
    cmp al, 0FCh
    je .set_at
    cmp al, 0FBh
    je .set_xt2
    cmp al, 0FAh
    je .set_ps2_30
    cmp al, 0F9h
    je .set_convertible
    cmp al, 0F8h
    je .set_ps2_80_16
    cmp al, 0B6h
    je .set_hp110
    cmp al, 0x9A
    je .set_compaq_plus
    cmp al, 0x2D
    je .set_compaq_pc
    jmp .set_unknown

.set_pc:
    mov si, pc_str
    jmp .print_host
.set_xt:
    mov si, xt_str
    jmp .print_host
.set_pcjr:
    mov si, pcjr_str
    jmp .print_host
.set_at:
    mov si, at_str
    jmp .print_host
.set_xt2:
    mov si, xt2_str
    jmp .print_host
.set_ps2_30:
    mov si, ps2_30_str
    jmp .print_host
.set_convertible:
    mov si, convertible_str
    jmp .print_host
.set_ps2_80_16:
    mov si, ps2_80_16_str
    jmp .print_host
.set_hp110:
    mov si, hp110_str
    jmp .print_host
.set_compaq_plus:
    mov si, compaq_plus_str
    jmp .print_host
.set_compaq_pc:
    mov si, compaq_pc_str
    jmp .print_host
.set_unknown:
    mov si, unknown_str
    jmp .print_host

.use_model_submodel:
    mov al, [model_byte]
    cmp al, 0FCh
    je .fc
    cmp al, 0FAh
    je .fa
    cmp al, 0F8h
    je .f8
    cmp al, 0F9h
    je .f9
    cmp al, 0FBh
    je .fb
    jmp .set_unknown

.fc:
    mov al, [submodel_byte]
    cmp al, 0
    je .fc_00
    cmp al, 1
    je .fc_01
    cmp al, 2
    je .fc_02
    cmp al, 4
    je .fc_04
    cmp al, 5
    je .fc_05
    cmp al, 0Bh
    je .fc_0b
    cmp al, 0Ch
    je .fc_0c
    cmp al, 0Dh
    je .fc_0d
    cmp al, 0Eh
    je .fc_0e
    cmp al, 0Fh
    je .fc_0f
    cmp al, 10h
    je .fc_10
    jmp .set_unknown

.fc_00:
    mov si, at_str
    jmp .print_host
.fc_01:
    mov si, at8_str
    jmp .print_host
.fc_02:
    mov si, xt286_str
    jmp .print_host
.fc_04:
    mov si, ps2_50_str
    jmp .print_host
.fc_05:
    mov si, ps2_60_str
    jmp .print_host
.fc_0b:
    mov si, ps1_str
    jmp .print_host
.fc_0c:
    mov si, ps2_55_sx_str
    jmp .print_host
.fc_0d:
    mov si, ps2_40_sx_str
    jmp .print_host
.fc_0e:
    mov si, ps2_35_sx_str
    jmp .print_host
.fc_0f:
    mov si, ps2_35_s_str
    jmp .print_host
.fc_10:
    mov si, ps2_90_xp
    jmp .print_host

.fa:
    mov al, [submodel_byte]
    cmp al, 0
    je .fa_00
    cmp al, 1
    je .fa_01
    cmp al, 4
    je .fa_04
    cmp al, 5
    je .fa_05
    jmp .set_unknown

.fa_00:
    mov si, ps2_30_str
    jmp .print_host
.fa_01:
    mov si, ps2_25_str
    jmp .print_host
.fa_04:
    mov si, ps2_30_286_str
    jmp .print_host
.fa_05:
    mov si, ps2_25_286_str
    jmp .print_host

.f8:
    mov al, [submodel_byte]
    cmp al, 0
    je .f8_00
    cmp al, 1
    je .f8_01
    cmp al, 4
    je .f8_04
    cmp al, 9
    je .f8_09
    cmp al, 0Bh
    je .f8_0b
    cmp al, 0Dh
    je .f8_0d
    cmp al, 0Eh
    je .f8_0e
    cmp al, 11h
    je .f8_11
    jmp .set_unknown

.f8_00:
    mov si, ps2_80_16_str
    jmp .print_host
.f8_01:
    mov si, ps2_80_20_str
    jmp .print_host
.f8_04:
    mov si, ps2_70_20_str
    jmp .print_host
.f8_09:
    mov si, ps2_70_16_str
    jmp .print_host
.f8_0b:
    mov si, ps2_65_sx_str
    jmp .print_host
.f8_0d:
    mov si, ps2_p70_str
    jmp .print_host
.f8_0e:
    mov si, ps2_p75_str
    jmp .print_host
.f8_11:
    mov si, ps2_95_xp
    jmp .print_host

.f9:
    mov al, [submodel_byte]
    cmp al, 0
    je .f9_00
    jmp .set_unknown
.f9_00:
    mov si, convertible_str
    jmp .print_host

.fb:
    mov al, [submodel_byte]
    cmp al, 0
    je .fb_00
    jmp .set_unknown
.fb_00:
    mov si, xt2_str
    jmp .print_host

.print_host:
    mov ah, 0x01
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; --------------- Kernel name -------------
    mov ah, 0x03
    mov si, kernel_msg
    int 0x21

    mov ah, 0x01
    mov si, kernel_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Shell name -------------
    mov ah, 0x03
    mov si, shell_msg
    int 0x21

    mov ah, 0x01
    mov si, shell_name
    int 0x21
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- CPU name ---------------
    mov ah, 0x03
    mov si, cpu_msg
    int 0x21

    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part
    ; -----------------------------------------

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- VESA support -----------
    mov ah, 0x03
    mov si, vesa_msg
    int 0x21

    ; Check VESA support
    push es
    mov ax, ds
    mov es, ax
    mov di, vesa_buffer
    mov ax, 0x4F00
    int 0x10
    pop es

    cmp al, 0x4F
    je .vesa_yes

    mov ah, 0x04
    mov si, no_str
    int 0x21
    jmp .after_vesa

.vesa_yes:
    mov ah, 0x02
    mov si, yes_str
    int 0x21

.after_vesa:
    ; -----------------------------------------
    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Resolution--------------
    mov ah, 0x03
    mov si, resolution_msg
    int 0x21

    mov ax, 0x4F03
    int 0x10
    cmp ax, 0x004F
    jne .resolution_unknown

    push es
    mov ax, ds
    mov es, ax
    mov di, vesa_buffer
    mov cx, bx
    mov ax, 0x4F01
    int 0x10
    pop es

    cmp ax, 0x004F
    jne .resolution_unknown

    mov ax, [vesa_buffer + 12h]
    mov bx, [vesa_buffer + 14h]

    call print_resolution
    jmp .after_resolution

.resolution_unknown:
    mov ah, 0x04
    mov si, unknown_str
    int 0x21

.after_resolution:
    ; -----------------------------------------
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Color blocks -----------
    mov cx, 16
    mov bl, 0
.color_blocks:
    push cx
    mov ah, 0x07
    int 0x21
    mov ah, 0x08
    mov si, block_char
    int 0x21
    inc bl
    pop cx
    loop .color_blocks
    ; -----------------------------------------

    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x02
    xor bh, bh
    mov dh, [cursor_y]
    mov dl, [cursor_x]
    int 0x10

    ret

.copy_user:
    rep movsb
    mov byte [di], 0

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

print_edx:
    mov ah, 0x0E
    mov bx, 4
.loop4r:
    mov al, dl
    int 0x10
    ror edx, 8
    dec bx
    jnz .loop4r
    ret


print_resolution:
    push ax
    push bx
    push cx
    push dx

    mov cx, ax
    call print_number

    mov ah, 0x01
    mov si, x_char
    int 0x21

    mov cx, bx
    call print_number

    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_number:
    push ax
    push bx
    push cx
    push dx

    mov ax, cx
    mov bx, 10
    mov cx, 0

.digit_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .digit_loop

.output_loop:
    pop ax
    add al, '0'
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    loop .output_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

user_cfg       db 'USER.CFG', 0

sep            db '---------------', 0
dog_symbol     db '@', 0

os_msg         db 'OS: ', 0
host_name_msg  db 'Host: ', 0
kernel_msg     db 'Kernel: ', 0
shell_msg      db 'Shell: ', 0
cpu_msg        db 'CPU: ', 0
vesa_msg       db 'VESA: ', 0
resolution_msg db 'Resolution: ', 0

os_name        db 'PRos', 0
os_full_name   db 'x16-PRos', 0
kernel_name    db 'PRos Kernel', 0
shell_name     db 'PRos Terminal', 0
yes_str        db 'Yes', 0
no_str         db 'No', 0

unknown_str    db 'Unknown PC Compatible', 0

cursor_x       db 0
cursor_y       db 0

conf_dir       db 'CONF.DIR', 0

block_char     db 0xDB, 0
x_char         db 'x', 0

ascii_art      db '                   .l.    lo,                 ', 13, 10
               db '                   ;ll.  ,lll.                ', 13, 10
               db '                   ,lllc lc .lll;             ', 13, 10
               db '                   .lllloll   clll            ', 13, 10
               db '                .ccllllll. , ;ll;             ', 13, 10
               db '               ccllllllllllo ,loll            ', 13, 10
               db '             lllllllllllloolllc               ', 13, 10
               db '           llllllllllllllllll:lc              ', 13, 10
               db '           llllllllllllllllllllll.            ', 13, 10
               db '         cllllllllllllllllllllllll            ', 13, 10
               db '     :clllllllllllllllllllllllllllo.          ', 13, 10
               db 'ccllll:      .ll ;lllllllllllllllllo          ', 13, 10
               db 'lllllll        .;  cllllllllllllllll,         ', 13, 10
               db ' llll.           .  ,lllllllllllllllo         ', 13, 10
               db ' ;llolc: c;         .llllllllllllllll,        ', 13, 10
               db '  lcllllolll  ,   . .lllllllllllllllll        ', 13, 10
               db '     ;c .lllo ., .: lllllllllllllllll;        ', 13, 10
               db '      ;:, ,lloo; cool. ;lllllllllllllll.      ', 13, 10
               db '       ;o:.llllolll.   ,lllllllllllllll:      ', 13, 10
               db '        llollll.      .lllllllllllllll.       ', 13, 10
               db '         :ll         .ollllllllllll           ', 13, 10
               db '                    :llllllll:                ', 13, 10
               db '                    lllll,                    ', 13, 10
               db '                    ;ll:                      ', 13, 10
               db '                     l                        ', 13, 10, 0

model_byte     db 0
submodel_byte  db 0

pc_str         db 'IBM PC 5150', 0
xt_str         db 'IBM PC XT 5160', 0
pcjr_str       db 'IBM PCjr 4860', 0
at_str         db 'IBM PC AT 5170', 0
xt286_str      db 'IBM XT-286 5162', 0
ps2_50_str     db 'IBM PS/2 Model 50', 0
ps2_60_str     db 'IBM PS/2 Model 60', 0
ps1_str        db 'IBM PS/1', 0
xt2_str        db 'IBM XT 256/640K', 0
ps2_30_str     db 'IBM PS/2 Model 30', 0
ps2_25_str     db 'IBM PS/2 Model 25', 0
convertible_str db 'IBM PC Convertible', 0
ps2_80_16_str  db 'IBM PS/2 Model 80 (16MHz)', 0
ps2_80_20_str  db 'IBM PS/2 Model 80 (20MHz)', 0
ps2_70_20_str  db 'IBM PS/2 Model 70 (20MHz)', 0
ps2_70_16_str  db 'IBM PS/2 Model 70 (16MHz)', 0
hp110_str      db 'Hewlett Packard 110', 0
compaq_plus_str db 'Compaq Plus', 0
compaq_pc_str  db 'Compaq PC', 0
at8_str        db 'IBM PC AT 5170 (8MHz)', 0
ps2_30_286_str db 'IBM PS/2 Model 30-286', 0
ps2_25_286_str db 'IBM PS/2 Model 25-286', 0
ps2_65_sx_str  db 'IBM PS/2 Model 65 SX', 0
ps2_p70_str    db 'IBM PS/2 Model P70', 0
ps2_55_sx_str  db 'IBM PS/2 Model 55SX', 0
ps2_40_sx_str  db 'IBM PS/2 Model 40SX', 0
ps2_35_sx_str  db 'IBM PS/2 Model 35SX', 0
ps2_35_s_str   db 'IBM PS/2 Model 35S', 0
ps2_p75_str    db 'IBM PS/2 Model P75', 0
ps2_90_xp      db 'IBM PS/2 Model 90 XP 486', 0
ps2_95_xp      db 'IBM PS/2 Model 95 XP 486', 0

buffer resb 32
vesa_buffer resb 512