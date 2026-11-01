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

    call smbios_host
    mov si, host_buf
    jnc .print_host

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

    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov dl, 40
    mov ah, 0x02
    xor bh, bh
    int 0x10

    ; ---------------- Resolution--------------
    mov ah, 0x03
    mov si, bios_release_msg
    int 0x21

    call print_bios_release

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

    ; ---------------- Memory -----------------
    mov ah, 0x03
    mov si, memory_msg
    int 0x21

    mov ah, 0x03
    int 0x23
    mov cl, 10
    shr ax, cl
    mov cl, 6
    shl dx, cl
    or ax, dx
    mov [mem_free_kb], ax

    int 0x12
    mov [mem_total_kb], ax

    call add_xms_memory

    mov cx, [mem_total_kb]
    sub cx, [mem_free_kb]
    call print_number

    mov ah, 0x01
    mov si, kib_sep_str
    int 0x21

    mov cx, [mem_total_kb]
    call print_number

    mov ah, 0x01
    mov si, kib_str
    int 0x21
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

SMB_MAX         equ 4096
HOST_MAX        equ 33

smbios_host:
    pushad
    push es
    mov ax, 0xF000
    mov es, ax
    xor di, di
.scan:
    cmp dword [es:di], 0x5F4D535F
    jne .next
    mov cl, [es:di + 5]
    cmp cl, 0x1E
    jb .next
    xor ch, ch
    xor al, al
    mov si, di
.sum:
    add al, [es:si]
    inc si
    loop .sum
    test al, al
    jz .found
.next:
    add di, 16
    jnz .scan
    jmp .fail

.found:
    mov eax, [es:di + 0x18]
    mov cx, [es:di + 0x16]
    cmp cx, SMB_MAX
    jbe .len_ok
    mov cx, SMB_MAX
.len_ok:
    mov [smb_len], cx
    push cs
    pop es
    movzx ecx, cx
    add ecx, eax
    cmp ecx, 0x100000
    ja .high

    mov si, ax
    and si, 0x000F
    shr eax, 4
    mov cx, [smb_len]
    mov di, smb_buf
    push ds
    mov ds, ax
    rep movsb
    pop ds
    jmp .parse

.high:
    mov word [smb_gdt + 0x10], 0xFFFF
    mov [smb_gdt + 0x12], ax
    shr eax, 16
    mov [smb_gdt + 0x14], al
    mov byte [smb_gdt + 0x15], 0x93
    mov [smb_gdt + 0x17], ah
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, smb_buf
    mov word [smb_gdt + 0x18], 0xFFFF
    mov [smb_gdt + 0x1A], ax
    shr eax, 16
    mov [smb_gdt + 0x1C], al
    mov byte [smb_gdt + 0x1D], 0x93
    mov [smb_gdt + 0x1F], ah
    mov cx, [smb_len]
    inc cx
    shr cx, 1
    mov si, smb_gdt
    mov ah, 0x87
    int 0x15
    jc .fail

.parse:
    mov si, smb_buf
    mov bx, si
    add bx, [smb_len]
.struct:
    lea ax, [si + 4]
    cmp ax, bx
    ja .fail
    cmp byte [si], 127
    je .fail
    movzx cx, byte [si + 1]
    cmp cx, 4
    jb .fail
    cmp byte [si], 1
    je .type1
    add si, cx
.skip:
    lea ax, [si + 1]
    cmp ax, bx
    jae .fail
    cmp word [si], 0
    je .skipped
    inc si
    jmp .skip
.skipped:
    add si, 2
    jmp .struct

.type1:
    cmp cx, 7
    jb .fail
    mov dx, [si + 5]
    add si, cx
    mov di, host_buf
    mov al, dl
    call smb_string
    jc .fail
    call smb_append
    mov al, dh
    call smb_string
    jc .trim
    push bp
    mov bp, space_str
    call smb_append
    pop bp
    call smb_append
.trim:
    cmp di, host_buf
    jbe .ok
    cmp byte [di - 1], ' '
    jne .ok
    dec di
    mov byte [di], 0
    jmp .trim
.ok:
    clc
    jmp .out
.fail:
    stc
.out:
    pop es
    popad
    ret

smb_string:
    push ax
    push cx
    push si
    test al, al
    jz .none
    movzx cx, al
.find:
    dec cx
    jz .got
.skip:
    cmp si, bx
    jae .none
    lodsb
    test al, al
    jnz .skip
    cmp byte [si], 0
    je .none
    jmp .find
.got:
    cmp si, bx
    jae .none
    cmp byte [si], 0
    je .none
    mov bp, si
    call smb_placeholder
    jc .none
    clc
    jmp .out
.none:
    stc
.out:
    pop si
    pop cx
    pop ax
    ret

smb_placeholder:
    push ax
    push si
    push di
    mov di, smb_placeholders
.entry:
    cmp byte [di], 0
    je .no
    mov si, bp
.cmp:
    mov al, [si]
    cmp al, 'a'
    jb .upper
    cmp al, 'z'
    ja .upper
    sub al, 0x20
.upper:
    cmp al, [di]
    jne .skip_entry
    test al, al
    jz .yes
    inc si
    inc di
    jmp .cmp
.skip_entry:
    cmp byte [di], 0
    je .next_entry
    inc di
    jmp .skip_entry
.next_entry:
    inc di
    jmp .entry
.yes:
    stc
    jmp .out
.no:
    clc
.out:
    pop di
    pop si
    pop ax
    ret

smb_append:
    push ax
    push si
    mov si, bp
.copy:
    cmp di, host_buf + HOST_MAX
    jae .end
    lodsb
    test al, al
    jz .end
    mov [di], al
    inc di
    jmp .copy
.end:
    mov byte [di], 0
    pop si
    pop ax
    ret

add_xms_memory:
    pushad
    push es
    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne .done
    mov ax, 0x4310
    int 0x2F
    mov [xms_entry], bx
    mov [xms_entry + 2], es
    mov ah, 0x88
    call far [xms_entry]
    cmp bl, 0x80
    je .done
    cmp bl, 0x81
    je .done
    add [mem_free_kb], dx
    mov eax, ecx
    inc eax
    shr eax, 10
    sub ax, 1024
    add [mem_total_kb], ax
.done:
    pop es
    popad
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

print_bios_release:
    push es
    pusha
    mov ax, 0xF000
    mov es, ax
    mov di, 0xFFF5
    mov cx, 8
.read_char:
    push cx
    mov al, [es:di]     
    
    mov [bios_char_tmp], al 
    
    mov si, bios_char_tmp
    mov ah, 0x01
    int 0x21

    inc di
    pop cx
    loop .read_char

    popa
    pop es
    ret

user_cfg         db 'USER.CFG', 0

sep              db '---------------', 0
dog_symbol       db '@', 0

os_msg           db 'OS: ', 0
host_name_msg    db 'Host: ', 0
kernel_msg       db 'Kernel: ', 0
shell_msg        db 'Shell: ', 0
cpu_msg          db 'CPU: ', 0
vesa_msg         db 'VESA: ', 0
resolution_msg   db 'Resolution: ', 0
bios_release_msg db 'BIOS release date: ', 0
memory_msg       db 'Memory: ', 0

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
kib_sep_str    db 'KiB / ', 0
kib_str        db 'KiB', 0
mem_free_kb    dw 0
mem_total_kb   dw 0
xms_entry      dd 0

host_buf       times HOST_MAX + 1 db 0
space_str      db ' ', 0
smb_len        dw 0
smb_gdt        times 48 db 0
smb_placeholders db 'TO BE FILLED BY O.E.M.', 0, 'DEFAULT STRING', 0, 'SYSTEM PRODUCT NAME', 0
                 db 'SYSTEM VERSION', 0, 'NOT SPECIFIED', 0, 'NOT APPLICABLE', 0, 'NONE', 0, 0

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

bios_char_tmp db 0, 0

buffer resb 32
vesa_buffer resb 512
smb_buf:
