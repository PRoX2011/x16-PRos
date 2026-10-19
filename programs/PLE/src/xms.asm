; ==================================================================
; x16-PRos -- XMS. Extended memory driver
; Copyright (C) 2026 PRoX2011
;
; Usage: xms < ON | OFF >
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "XMS extended memory driver", "PRoX-dev" ;, PLE_FLAG_NO_SPLASH
PLE_LOGO   "logo/xms.raw"

XMS_MAX_KB       equ 15360
XMS_HMA_KB       equ 64
XMS_EMB_BASE_KB  equ 1024 + XMS_HMA_KB

XMSD_HANDLES     equ 32
XMSD_ENT         equ 8
XE_FLAGS         equ 0
XE_LOCKS         equ 1
XE_BASE          equ 2
XE_SIZE          equ 4
XE_UNUSED        equ 0
XE_FREE          equ 1
XE_USED          equ 2

XF_EDI           equ 0
XF_ESI           equ 4
XF_EBX           equ 16
XF_EDX           equ 20
XF_ECX           equ 24
XF_EAX           equ 28
XF_DS            equ 34

start:
    push cs
    pop ds
    cld
    mov [args], si
    mov [args + 2], es
    push cs
    pop es

    call xms_find

    mov di, word_load
    mov cx, 4
    call arg_is
    jc .load
    mov di, word_on
    mov cx, 2
    call arg_is
    jc .on
    mov di, word_off
    mov cx, 3
    call arg_is
    jc .off

    mov si, msg_usage
    mov ah, 0x01
    int 0x21
    retf

.load:
    cmp word [drv_seg], 0
    jne .quit
    call xms_install
    jnc .quit
    call show_error
.quit:
    retf

.on:
    cmp word [drv_seg], 0
    jne .on_saved
    call xms_install
    jc .error
.on_saved:
    mov si, cfg_on
    mov cx, cfg_on_len
    call save_cfg
    jc .cfg_error
    mov si, msg_enabled
    mov ah, 0x02
    int 0x21
    mov ah, 0x05
    int 0x21
    call show_memory
    retf

.off:
    cmp word [drv_seg], 0
    je .off_saved
    call xms_remove
    jc .error
.off_saved:
    mov si, cfg_off
    mov cx, cfg_off_len
    call save_cfg
    jc .cfg_error
    mov si, msg_disabled

.done:
    mov ah, 0x02
    int 0x21
    mov ah, 0x05
    int 0x21
    retf

.cfg_error:
    mov ax, msg_cfg_fail
    xor bx, bx
.error:
    call show_error
    retf

arg_is:
    pusha
    push es
    les si, [args]
    test si, si
    jz .no
.skip:
    cmp byte [es:si], ' '
    jne .cmp
    inc si
    jmp .skip
.cmp:
    mov al, [es:si]
    and al, 0xDF
    cmp al, [di]
    jne .no
    inc si
    inc di
    loop .cmp
    mov al, [es:si]
    test al, al
    jz .yes
    cmp al, ' '
    je .yes
.no:
    pop es
    popa
    clc
    ret
.yes:
    pop es
    popa
    stc
    ret

; ========================================================================
; xms_find -- Look for this driver among the installed XMS drivers
; OUT: [drv_seg] = its segment, 0 when it is not installed
; ========================================================================
xms_find:
    pusha
    push es
    mov word [drv_seg], 0
    mov ax, 0x4300
    int 0x2F
    cmp al, 0x80
    jne .done
    mov ax, 0x4310
    int 0x2F
    test bx, bx
    jnz .done
    mov si, sig_text
    mov di, xmsd_sig
    mov cx, sig_text_len
    repe cmpsb
    jne .done
    mov [drv_seg], es
    mov [xms_entry + 2], es
.done:
    pop es
    popa
    ret

; ========================================================================
; xms_install -- Put the resident driver at the top of memory and hook
;                INT 0x2F and INT 0x15
; OUT: CF = 0 on success, [drv_seg] set
;      CF = 1, AX/BX = message lines for the user
; ========================================================================
xms_install:
    push cx
    push dx
    push si
    push di
    push es

    mov ah, 0x88
    int 0x15
    jc .no_ext
    cmp ax, XMS_HMA_KB
    jb .no_ext
    cmp ax, XMS_MAX_KB
    jbe .size_ok
    mov ax, XMS_MAX_KB
.size_ok:
    mov [ext_kb], ax

    mov bx, xmsd_end
    add bx, 15
    shr bx, 4
    mov ah, 0x04
    int 0x23
    jc .no_mem
    mov es, ax

    push ds
    PLE_LOAD_SEG ds, driver
    xor si, si
    xor di, di
    mov cx, xmsd_end
    rep movsb
    pop ds

    mov ax, [ext_kb]
    mov [es:xmsd_ext_kb], ax
    mov byte [es:xmsd_hma], 1
    sub ax, XMS_HMA_KB
    jz .no_emb
    mov di, xmsd_table
    mov byte [es:di + XE_FLAGS], XE_FREE
    mov word [es:di + XE_BASE], XMS_EMB_BASE_KB
    mov [es:di + XE_SIZE], ax
.no_emb:

    push ds
    xor ax, ax
    mov ds, ax
    cli
    mov ax, [0x2F * 4]
    mov [es:xmsd_old2f], ax
    mov ax, [0x2F * 4 + 2]
    mov [es:xmsd_old2f + 2], ax
    mov ax, [0x15 * 4]
    mov [es:xmsd_old15], ax
    mov ax, [0x15 * 4 + 2]
    mov [es:xmsd_old15 + 2], ax
    mov word [0x2F * 4], xmsd_int2f
    mov [0x2F * 4 + 2], es
    mov word [0x15 * 4], xmsd_int15
    mov [0x15 * 4 + 2], es
    sti
    pop ds

    mov [drv_seg], es
    mov [xms_entry + 2], es

    pop es
    pop di
    pop si
    pop dx
    pop cx
    clc
    ret

.no_ext:
    mov ax, msg_no_ext1
    mov bx, msg_no_ext2
    jmp .fail
.no_mem:
    mov ax, msg_no_mem1
    mov bx, msg_no_mem2
.fail:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    stc
    ret

; ========================================================================
; xms_remove -- Unhook the driver and give its memory back
; OUT: CF = 0 on success, [drv_seg] = 0
;      CF = 1, AX/BX = message lines for the user
; ========================================================================
xms_remove:
    push cx
    push dx
    push si
    push es

    mov es, [drv_seg]
    call used_handles
    test ax, ax
    jnz .busy
    cmp byte [es:xmsd_hma], 2
    je .busy

    mov dx, es
    push ds
    xor ax, ax
    mov ds, ax
    cmp word [0x2F * 4], xmsd_int2f
    jne .hooked
    cmp [0x2F * 4 + 2], dx
    jne .hooked
    cmp word [0x15 * 4], xmsd_int15
    jne .hooked
    cmp [0x15 * 4 + 2], dx
    jne .hooked

    cli
    mov bx, dx
    mov ah, 0x05
    int 0x23
    jc .not_top
    mov ax, [es:xmsd_old2f]
    mov [0x2F * 4], ax
    mov ax, [es:xmsd_old2f + 2]
    mov [0x2F * 4 + 2], ax
    mov ax, [es:xmsd_old15]
    mov [0x15 * 4], ax
    mov ax, [es:xmsd_old15 + 2]
    mov [0x15 * 4 + 2], ax
    sti
    pop ds

    mov word [drv_seg], 0
    pop es
    pop si
    pop dx
    pop cx
    clc
    ret

.not_top:
    sti
    pop ds
    mov ax, msg_not_top1
    mov bx, msg_not_top2
    jmp .fail
.hooked:
    pop ds
    mov ax, msg_hooked1
    mov bx, msg_hooked2
    jmp .fail
.busy:
    mov ax, msg_busy1
    mov bx, msg_busy2
.fail:
    pop es
    pop si
    pop dx
    pop cx
    stc
    ret

; ========================================================================
; used_handles -- Count the allocated extended memory blocks
; IN:  ES = driver segment
; OUT: AX = handles in use
; ========================================================================
used_handles:
    push cx
    push si
    xor ax, ax
    mov si, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [es:si + XE_FLAGS], XE_USED
    jne .next
    inc ax
.next:
    add si, XMSD_ENT
    loop .scan
    pop si
    pop cx
    ret

; ========================================================================
; save_cfg -- Write the switch position to CONF.DIR/XMS.CFG on the system drive
; IN:  SI = text to store, CX = its length
; OUT: CF = 1 if the file could not be written
; ========================================================================
save_cfg:
    pusha
    mov [.data], si
    mov [.len], cx

    mov ah, 0x0E
    int 0x22
    mov ah, 0x16
    int 0x22
    mov [sys_drive], al
    mov ah, 0x12
    mov si, sys_drive
    int 0x22
    jc .fail
.up:
    mov ah, 0x0A
    int 0x22
    jnc .up

    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22
    jc .fail

    mov ah, 0x03
    mov si, cfg_file_name
    mov bx, [.data]
    mov cx, [.len]
    int 0x22
    jc .fail

    mov ah, 0x0F
    int 0x22
    popa
    clc
    ret

.fail:
    mov ah, 0x0F
    int 0x22
    popa
    stc
    ret

.data dw 0
.len  dw 0

; ========================================================================
; show_memory -- Print the amount of extended memory the driver manages,
;                the number in cyan
; ========================================================================
show_memory:
    pusha
    push es
    cmp word [drv_seg], 0
    je .bios
    mov es, [drv_seg]
    mov ax, [es:xmsd_ext_kb]
    jmp .print
.bios:
    mov ah, 0x88
    int 0x15
    jnc .capped
    xor ax, ax
.capped:
    cmp ax, XMS_MAX_KB
    jbe .print
    mov ax, XMS_MAX_KB
.print:
    mov di, num_buf + 5
    mov byte [di], 0
    mov bx, 10
.digit:
    xor dx, dx
    div bx
    add dl, '0'
    dec di
    mov [di], dl
    test ax, ax
    jnz .digit
    mov si, msg_memory
    mov ah, 0x01
    int 0x21
    mov si, di
    mov ah, 0x03
    int 0x21
    mov si, msg_kb
    int 0x21
    pop es
    popa
    ret

; ========================================================================
; show_error -- Print up to two message lines in red
; IN:  AX = first line, BX = second line or 0
; ========================================================================
show_error:
    pusha
    mov si, ax
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
    test bx, bx
    jz .done
    mov si, bx
    mov ah, 0x04
    int 0x21
    mov ah, 0x05
    int 0x21
.done:
    popa
    ret

args             dw 0, 0
drv_seg          dw 0
xms_entry        dw 0, 0
ext_kb           dw 0
num_buf          times 6 db 0

word_load        db 'LOAD'
word_on          db 'ON'
word_off         db 'OFF'
sig_text         db 'PRXMS', 0
sig_text_len     equ $ - sig_text
sys_drive        db 'A', 0
conf_dir_name    db 'CONF.DIR', 0
cfg_file_name    db 'XMS.CFG', 0
cfg_on           db 'ON'
cfg_on_len       equ $ - cfg_on
cfg_off          db 'OFF'
cfg_off_len      equ $ - cfg_off

msg_usage        db 'Usage: XMS.PLE ON | OFF', 10, 13, 0
msg_memory       db 'Extended memory: ', 0
msg_kb           db ' KB', 10, 13, 0
msg_enabled      db 'Successfully enabled', 0
msg_disabled     db 'Successfully disabled', 0

msg_no_ext1      db 'No extended memory was found.', 0
msg_no_ext2      db 'INT 0x15/0x88 reports under 64 KB.', 0
msg_no_mem1      db 'The top of memory is taken.', 0
msg_no_mem2      db 'Stop background tasks or another XMS driver and retry.', 0
msg_busy1        db 'Programs still hold XMS memory.', 0
msg_busy2        db 'Reboot to release it.', 0
msg_hooked1      db 'INT 0x2F/0x15 was hooked after', 0
msg_hooked2      db 'the driver. Remove that first.', 0
msg_not_top1     db 'Another module sits below', 0
msg_not_top2     db 'the driver. Remove it first.', 0
msg_cfg_fail     db 'Could not write CONF.DIR/XMS.CFG.', 0

; ==================================================================
; Resident part. Every offset below is relative to the block it is
; copied to, which is also its CS and DS while it runs.
; ==================================================================
PLE_SEGMENT driver

xmsd_entry:
    jmp short xmsd_dispatch
    nop
    nop
    nop
xmsd_sig         db 'PRXMS', 0

xmsd_old2f       dd 0
xmsd_old15       dd 0
xmsd_ext_kb      dw 0
xmsd_hma         db 0
xmsd_a20_global  db 0
xmsd_a20_local   dw 0
xmsd_r_entry     dw 0
xmsd_r_old       dw 0
xmsd_r_slot      dw 0

; ========================================================================
; xmsd_int2f -- XMS installation check and entry point query
; ========================================================================
xmsd_int2f:
    cmp ax, 0x4300
    je .present
    cmp ax, 0x4310
    je .entry
    jmp far [cs:xmsd_old2f]
.present:
    mov al, 0x80
    iret
.entry:
    push cs
    pop es
    mov bx, xmsd_entry
    iret

; ========================================================================
; xmsd_int15 -- Report no raw extended memory, it all belongs to XMS
; ========================================================================
xmsd_int15:
    cmp ah, 0x88
    je .none
    jmp far [cs:xmsd_old15]
.none:
    xor ax, ax
    push bp
    mov bp, sp
    and byte [bp + 6], 0xFE
    pop bp
    iret

; ========================================================================
; xmsd_dispatch -- XMS entry point, reached with a far call
; IN:  AH = XMS function, other registers as the function wants
; OUT: AX = 1 on success, AX = 0 and BL = error code on failure
; ========================================================================
xmsd_dispatch:
    push ds
    push es
    pushad
    mov bp, sp
    push cs
    pop ds
    cld

    cmp ah, 0x12
    jbe .table
    cmp ah, 0x88
    je xmsd_f88
    cmp ah, 0x89
    je xmsd_f89
    cmp ah, 0x8E
    je xmsd_f8e
    cmp ah, 0x8F
    je xmsd_f8f
    mov al, 0x80
    jmp xmsd_fail
.table:
    movzx bx, ah
    shl bx, 1
    jmp [cs:xmsd_funcs + bx]

xmsd_ok:
    mov word [bp + XF_EAX], 1
    jmp xmsd_return

xmsd_fail:
    mov word [bp + XF_EAX], 0
    mov [bp + XF_EBX], al

xmsd_return:
    popad
    pop es
    pop ds
    retf

xmsd_funcs:
    dw xmsd_f00, xmsd_f01, xmsd_f02, xmsd_f03, xmsd_f04, xmsd_f05
    dw xmsd_f06, xmsd_f07, xmsd_f08, xmsd_f09, xmsd_f0a, xmsd_f0b
    dw xmsd_f0c, xmsd_f0d, xmsd_f0e, xmsd_f0f, xmsd_f10, xmsd_f11
    dw xmsd_f12

xmsd_f00:
    mov word [bp + XF_EAX], 0x0300
    mov word [bp + XF_EBX], 0x035F
    xor ax, ax
    cmp byte [xmsd_hma], 0
    je .no_hma
    inc ax
.no_hma:
    mov [bp + XF_EDX], ax
    jmp xmsd_return

xmsd_f01:
    mov al, 0x90
    cmp byte [xmsd_hma], 0
    je xmsd_fail
    mov al, 0x91
    cmp byte [xmsd_hma], 2
    je xmsd_fail
    mov byte [xmsd_hma], 2
    jmp xmsd_ok

xmsd_f02:
    mov al, 0x90
    cmp byte [xmsd_hma], 0
    je xmsd_fail
    mov al, 0x93
    cmp byte [xmsd_hma], 2
    jne xmsd_fail
    mov byte [xmsd_hma], 1
    jmp xmsd_ok

xmsd_f03:
    call xmsd_a20_on
    mov al, 0x82
    jc xmsd_fail
    mov byte [xmsd_a20_global], 1
    jmp xmsd_ok

xmsd_f04:
    mov byte [xmsd_a20_global], 0
    cmp word [xmsd_a20_local], 0
    jne xmsd_ok
    call xmsd_a20_off
    mov al, 0x82
    jc xmsd_fail
    jmp xmsd_ok

xmsd_f05:
    call xmsd_a20_on
    mov al, 0x82
    jc xmsd_fail
    inc word [xmsd_a20_local]
    jmp xmsd_ok

xmsd_f06:
    mov al, 0x82
    cmp word [xmsd_a20_local], 0
    je xmsd_fail
    dec word [xmsd_a20_local]
    jnz xmsd_ok
    cmp byte [xmsd_a20_global], 0
    jne xmsd_ok
    call xmsd_a20_off
    mov al, 0x82
    jc xmsd_fail
    jmp xmsd_ok

xmsd_f07:
    call xmsd_a20_test
    mov [bp + XF_EAX], ax
    mov byte [bp + XF_EBX], 0
    jmp xmsd_return

xmsd_f08:
    call xmsd_free_info
    mov [bp + XF_EAX], ax
    mov [bp + XF_EDX], dx
    mov byte [bp + XF_EBX], 0
    test ax, ax
    jnz xmsd_return
    mov byte [bp + XF_EBX], 0xA0
    jmp xmsd_return

xmsd_f09:
    mov dx, [bp + XF_EDX]
    call xmsd_alloc
    jc xmsd_fail
    mov [bp + XF_EDX], si
    jmp xmsd_ok

xmsd_f0a:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov al, 0xAB
    cmp byte [si + XE_LOCKS], 0
    jne xmsd_fail
    call xmsd_release
    jmp xmsd_ok

xmsd_f0b:
    push ds
    mov ds, [bp + XF_DS]
    mov si, [bp + XF_ESI]
    mov ecx, [si]
    mov dx, [si + 4]
    mov eax, [si + 6]
    mov bx, [si + 0x0A]
    mov edi, [si + 0x0C]
    pop ds
    test cl, 1
    jz .even
    mov al, 0xA7
    jmp xmsd_fail
.even:
    push bx
    mov bl, 0xA3
    call xmsd_linear
    pop bx
    jc xmsd_fail
    mov esi, eax
    mov eax, edi
    mov dx, bx
    mov bl, 0xA5
    call xmsd_linear
    jc xmsd_fail
    mov edi, eax
    call xmsd_copy
    mov al, 0x8E
    jc xmsd_fail
    jmp xmsd_ok

xmsd_f0c:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov al, 0xAC
    cmp byte [si + XE_LOCKS], 0xFF
    je xmsd_fail
    inc byte [si + XE_LOCKS]
    movzx eax, word [si + XE_BASE]
    shl eax, 10
    mov [bp + XF_EBX], ax
    shr eax, 16
    mov [bp + XF_EDX], ax
    jmp xmsd_ok

xmsd_f0d:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov al, 0xAA
    cmp byte [si + XE_LOCKS], 0
    je xmsd_fail
    dec byte [si + XE_LOCKS]
    jmp xmsd_ok

xmsd_f0e:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    call xmsd_count_unused
    mov ah, [si + XE_LOCKS]
    mov [bp + XF_EBX], ax
    mov ax, [si + XE_SIZE]
    mov [bp + XF_EDX], ax
    jmp xmsd_ok

xmsd_f0f:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov bx, [bp + XF_EBX]
    call xmsd_resize
    jc xmsd_fail
    jmp xmsd_ok

xmsd_f10:
    mov word [bp + XF_EDX], 0
    mov al, 0xB1
    jmp xmsd_fail

xmsd_f11:
xmsd_f12:
    mov al, 0xB2
    jmp xmsd_fail

xmsd_f88:
    call xmsd_free_info
    movzx eax, ax
    mov [bp + XF_EAX], eax
    movzx edx, dx
    mov [bp + XF_EDX], edx
    movzx ecx, word [xmsd_ext_kb]
    add ecx, 1024
    shl ecx, 10
    dec ecx
    mov [bp + XF_ECX], ecx
    mov byte [bp + XF_EBX], 0
    test eax, eax
    jnz xmsd_return
    mov byte [bp + XF_EBX], 0xA0
    jmp xmsd_return

xmsd_f89:
    mov edx, [bp + XF_EDX]
    mov al, 0xA0
    cmp edx, 0xFFFF
    ja xmsd_fail
    call xmsd_alloc
    jc xmsd_fail
    movzx esi, si
    mov [bp + XF_EDX], esi
    jmp xmsd_ok

xmsd_f8e:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov al, [si + XE_LOCKS]
    mov [bp + XF_EBX + 1], al
    call xmsd_count_unused
    xor ah, ah
    mov [bp + XF_ECX], ax
    movzx eax, word [si + XE_SIZE]
    mov [bp + XF_EDX], eax
    jmp xmsd_ok

xmsd_f8f:
    mov dx, [bp + XF_EDX]
    call xmsd_handle
    jc xmsd_fail
    mov ebx, [bp + XF_EBX]
    mov al, 0xA0
    cmp ebx, 0xFFFF
    ja xmsd_fail
    call xmsd_resize
    jc xmsd_fail
    jmp xmsd_ok

; ========================================================================
; xmsd_handle -- Validate an EMB handle
; IN:  DX = handle
; OUT: SI = its table entry, CF = 1 and AL = A2h if it is not allocated
; ========================================================================
xmsd_handle:
    mov si, dx
    sub si, xmsd_table
    jb .bad
    cmp si, XMSD_HANDLES * XMSD_ENT
    jae .bad
    test si, XMSD_ENT - 1
    jnz .bad
    mov si, dx
    cmp byte [si + XE_FLAGS], XE_USED
    jne .bad
    clc
    ret
.bad:
    mov al, 0xA2
    stc
    ret

; ========================================================================
; xmsd_unused_slot -- Find a table entry that describes nothing
; OUT: DI = entry, CF = 1 if the table is full
; ========================================================================
xmsd_unused_slot:
    push cx
    mov di, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [di + XE_FLAGS], XE_UNUSED
    je .hit
    add di, XMSD_ENT
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ========================================================================
; xmsd_count_unused -- Count the entries that describe nothing
; OUT: AL = count
; ========================================================================
xmsd_count_unused:
    push cx
    push di
    xor al, al
    mov di, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [di + XE_FLAGS], XE_UNUSED
    jne .next
    inc al
.next:
    add di, XMSD_ENT
    loop .scan
    pop di
    pop cx
    ret

; ========================================================================
; xmsd_first_fit -- Find a free block of at least DX KiB
; OUT: DI = entry, CF = 1 if there is none
; ========================================================================
xmsd_first_fit:
    push cx
    mov di, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [di + XE_FLAGS], XE_FREE
    jne .next
    cmp [di + XE_SIZE], dx
    jae .hit
.next:
    add di, XMSD_ENT
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ========================================================================
; xmsd_free_at -- Find the free block that starts at DX KiB
; OUT: DI = entry, CF = 1 if there is none
; ========================================================================
xmsd_free_at:
    push cx
    mov di, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [di + XE_FLAGS], XE_FREE
    jne .next
    cmp [di + XE_BASE], dx
    je .hit
.next:
    add di, XMSD_ENT
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ========================================================================
; xmsd_free_info -- Sum up the free extended memory
; OUT: AX = largest free block in KiB, DX = total free KiB
; ========================================================================
xmsd_free_info:
    push bx
    push cx
    push si
    xor ax, ax
    xor dx, dx
    mov si, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp byte [si + XE_FLAGS], XE_FREE
    jne .next
    mov bx, [si + XE_SIZE]
    add dx, bx
    cmp bx, ax
    jbe .next
    mov ax, bx
.next:
    add si, XMSD_ENT
    loop .scan
    pop si
    pop cx
    pop bx
    ret

; ========================================================================
; xmsd_alloc -- Allocate an extended memory block
; IN:  DX = size in KiB
; OUT: SI = handle, CF = 1 and AL = error code on failure
; ========================================================================
xmsd_alloc:
    test dx, dx
    jz .zero
    call xmsd_first_fit
    mov al, 0xA0
    jc .fail
    mov si, di
    cmp [si + XE_SIZE], dx
    je .take
    call xmsd_unused_slot
    jc .take
    mov ax, [si + XE_BASE]
    add ax, dx
    mov [di + XE_BASE], ax
    mov ax, [si + XE_SIZE]
    sub ax, dx
    mov [di + XE_SIZE], ax
    mov byte [di + XE_FLAGS], XE_FREE
    mov byte [di + XE_LOCKS], 0
    mov [si + XE_SIZE], dx
.take:
    mov byte [si + XE_FLAGS], XE_USED
    mov byte [si + XE_LOCKS], 0
    clc
    ret
.zero:
    call xmsd_unused_slot
    mov al, 0xA1
    jc .fail
    mov si, di
    mov word [si + XE_BASE], XMS_EMB_BASE_KB
    mov word [si + XE_SIZE], 0
    jmp .take
.fail:
    stc
    ret

; ========================================================================
; xmsd_release -- Turn an allocated block back into free memory
; IN:  SI = table entry
; ========================================================================
xmsd_release:
    mov byte [si + XE_LOCKS], 0
    cmp word [si + XE_SIZE], 0
    jne .free
    mov byte [si + XE_FLAGS], XE_UNUSED
    ret
.free:
    mov byte [si + XE_FLAGS], XE_FREE
    call xmsd_coalesce
    ret

; ========================================================================
; xmsd_coalesce -- Merge a free block with the free blocks around it
; IN:  SI = free table entry
; ========================================================================
xmsd_coalesce:
    push ax
    push bx
    push cx
    push dx
    push di
.again:
    mov ax, [si + XE_BASE]
    mov bx, ax
    add bx, [si + XE_SIZE]
    mov di, xmsd_table
    mov cx, XMSD_HANDLES
.scan:
    cmp di, si
    je .next
    cmp byte [di + XE_FLAGS], XE_FREE
    jne .next
    cmp [di + XE_BASE], bx
    je .right
    mov dx, [di + XE_BASE]
    add dx, [di + XE_SIZE]
    cmp dx, ax
    je .left
.next:
    add di, XMSD_ENT
    loop .scan
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.right:
    mov dx, [di + XE_SIZE]
    add [si + XE_SIZE], dx
    mov byte [di + XE_FLAGS], XE_UNUSED
    jmp .again
.left:
    mov dx, [si + XE_SIZE]
    add [di + XE_SIZE], dx
    mov byte [si + XE_FLAGS], XE_UNUSED
    mov si, di
    jmp .again

; ========================================================================
; xmsd_resize -- Change the size of an allocated block, moving it when
;                it cannot grow in place
; IN:  SI = table entry, BX = new size in KiB
; OUT: CF = 1 and AL = error code on failure
; ========================================================================
xmsd_resize:
    mov al, 0xAB
    cmp byte [si + XE_LOCKS], 0
    jne .fail
    mov ax, [si + XE_SIZE]
    cmp bx, ax
    je .ok
    jb .shrink

    test ax, ax
    jz .move
    mov dx, [si + XE_BASE]
    add dx, ax
    call xmsd_free_at
    jc .move
    mov cx, bx
    sub cx, ax
    cmp [di + XE_SIZE], cx
    jb .move
    add [di + XE_BASE], cx
    sub [di + XE_SIZE], cx
    jnz .grown
    mov byte [di + XE_FLAGS], XE_UNUSED
.grown:
    mov [si + XE_SIZE], bx
.ok:
    clc
    ret

.shrink:
    call xmsd_unused_slot
    jc .ok
    mov dx, [si + XE_BASE]
    add dx, bx
    mov [di + XE_BASE], dx
    mov dx, ax
    sub dx, bx
    mov [di + XE_SIZE], dx
    mov byte [di + XE_FLAGS], XE_FREE
    mov byte [di + XE_LOCKS], 0
    mov [si + XE_SIZE], bx
    push si
    mov si, di
    call xmsd_coalesce
    pop si
    clc
    ret

.move:
    mov [xmsd_r_entry], si
    mov [xmsd_r_old], ax
    mov word [xmsd_r_slot], 0
    test ax, ax
    jz .find
    call xmsd_unused_slot
    mov al, 0xA1
    jc .fail
    mov [xmsd_r_slot], di
.find:
    mov dx, bx
    call xmsd_first_fit
    mov al, 0xA0
    jc .fail

    cmp word [xmsd_r_old], 0
    je .relink
    push bx
    push di
    mov si, [xmsd_r_entry]
    movzx esi, word [si + XE_BASE]
    shl esi, 10
    movzx edi, word [di + XE_BASE]
    shl edi, 10
    movzx ecx, word [xmsd_r_old]
    shl ecx, 10
    call xmsd_copy
    pop di
    pop bx
    mov al, 0x8E
    jc .fail

.relink:
    mov si, [xmsd_r_entry]
    mov ax, [si + XE_BASE]
    mov cx, [xmsd_r_old]
    mov dx, [di + XE_BASE]
    mov [si + XE_BASE], dx
    mov [si + XE_SIZE], bx
    add [di + XE_BASE], bx
    sub [di + XE_SIZE], bx
    jnz .old_space
    mov byte [di + XE_FLAGS], XE_UNUSED
.old_space:
    test cx, cx
    jz .ok
    mov di, [xmsd_r_slot]
    mov [di + XE_BASE], ax
    mov [di + XE_SIZE], cx
    mov byte [di + XE_FLAGS], XE_FREE
    mov byte [di + XE_LOCKS], 0
    push si
    mov si, di
    call xmsd_coalesce
    pop si
    clc
    ret
.fail:
    stc
    ret

; ========================================================================
; xmsd_linear -- Turn a handle and an offset into a linear address
; IN:  DX = handle (0 = EAX holds a real-mode segment:offset)
;      EAX = offset, ECX = length, BL = error code for a bad handle
; OUT: EAX = linear address, CF = 1 and AL = error code on failure
; ========================================================================
xmsd_linear:
    test dx, dx
    jnz .block
    mov edx, eax
    shr edx, 16
    shl edx, 4
    and eax, 0xFFFF
    add eax, edx
    clc
    ret
.block:
    push si
    push edx
    push eax
    call xmsd_handle
    pop eax
    jc .bad_handle
    movzx edx, word [si + XE_SIZE]
    shl edx, 10
    cmp eax, edx
    ja .bad_offset
    sub edx, eax
    cmp ecx, edx
    ja .bad_length
    movzx edx, word [si + XE_BASE]
    shl edx, 10
    add eax, edx
    pop edx
    pop si
    clc
    ret
.bad_handle:
    mov al, bl
    jmp .fail
.bad_offset:
    mov al, bl
    inc al
    jmp .fail
.bad_length:
    mov al, 0xA7
.fail:
    pop edx
    pop si
    stc
    ret

; ========================================================================
; xmsd_copy -- Copy memory below 16 MiB through INT 15h AH=87h
; IN:  ESI = source, EDI = destination, ECX = even byte count
; OUT: CF = 1 if the BIOS refused a chunk
; ========================================================================
xmsd_copy:
.chunk:
    test ecx, ecx
    jz .done
    mov eax, 0x10000
    cmp ecx, eax
    jae .sized
    mov eax, ecx
.sized:
    mov edx, esi
    mov [xmsd_gdt + 0x12], dx
    shr edx, 16
    mov [xmsd_gdt + 0x14], dl
    mov [xmsd_gdt + 0x17], dh
    mov edx, edi
    mov [xmsd_gdt + 0x1A], dx
    shr edx, 16
    mov [xmsd_gdt + 0x1C], dl
    mov [xmsd_gdt + 0x1F], dh

    push esi
    push edi
    push ecx
    push eax
    shr eax, 1
    mov cx, ax
    push cs
    pop es
    mov si, xmsd_gdt
    mov ah, 0x87
    pushf
    call far [xmsd_old15]
    pop eax
    pop ecx
    pop edi
    pop esi
    jc .fail
    add esi, eax
    add edi, eax
    sub ecx, eax
    jmp .chunk
.done:
    clc
    ret
.fail:
    stc
    ret

; ========================================================================
; xmsd_a20_test -- Check whether the A20 line is on
; OUT: AX = 1 if it is on, 0 if addresses wrap at 1 MiB
; ========================================================================
xmsd_a20_test:
    push ds
    push es
    push si
    push di
    pushf
    cli
    xor ax, ax
    mov ds, ax
    not ax
    mov es, ax
    mov si, 0x0500
    mov di, 0x0510
    mov al, [si]
    mov ah, [es:di]
    push ax
    mov byte [si], 0x00
    mov byte [es:di], 0xFF
    cmp byte [si], 0xFF
    pop ax
    mov [es:di], ah
    mov [si], al
    mov ax, 0
    je .off
    inc ax
.off:
    popf
    pop di
    pop si
    pop es
    pop ds
    ret

; ========================================================================
; xmsd_a20_settle -- Wait a little for the A20 line to reach a state
; IN:  DL = wanted state (1 = on, 0 = off)
; OUT: ZF = 1 once it is there
; ========================================================================
xmsd_a20_settle:
    push cx
    mov cx, 0x1000
.poll:
    call xmsd_a20_test
    cmp al, dl
    je .done
    loop .poll
    cmp al, dl
.done:
    pop cx
    ret

; ========================================================================
; xmsd_kbc_wait -- Wait until the keyboard controller takes a byte
; ========================================================================
xmsd_kbc_wait:
    push cx
    xor cx, cx
.poll:
    in al, 0x64
    test al, 0x02
    loopnz .poll
    pop cx
    ret

; ========================================================================
; xmsd_a20_on -- Turn the A20 line on: BIOS, then port 92h, then the KBC
; OUT: CF = 1 if nothing worked
; ========================================================================
xmsd_a20_on:
    push ax
    push dx
    mov dl, 1
    call xmsd_a20_test
    test ax, ax
    jnz .ok

    mov ax, 0x2401
    pushf
    call far [xmsd_old15]
    call xmsd_a20_settle
    je .ok

    in al, 0x92
    or al, 0x02
    and al, 0xFE
    out 0x92, al
    call xmsd_a20_settle
    je .ok

    call xmsd_kbc_wait
    mov al, 0xD1
    out 0x64, al
    call xmsd_kbc_wait
    mov al, 0xDF
    out 0x60, al
    call xmsd_kbc_wait
    call xmsd_a20_settle
    je .ok

    pop dx
    pop ax
    stc
    ret
.ok:
    pop dx
    pop ax
    clc
    ret

; ========================================================================
; xmsd_a20_off -- Turn the A20 line off the same three ways
; OUT: CF = 1 if nothing worked
; ========================================================================
xmsd_a20_off:
    push ax
    push dx
    mov dl, 0
    call xmsd_a20_test
    test ax, ax
    jz .ok

    mov ax, 0x2400
    pushf
    call far [xmsd_old15]
    call xmsd_a20_settle
    je .ok

    in al, 0x92
    and al, 0xFC
    out 0x92, al
    call xmsd_a20_settle
    je .ok

    call xmsd_kbc_wait
    mov al, 0xD1
    out 0x64, al
    call xmsd_kbc_wait
    mov al, 0xDD
    out 0x60, al
    call xmsd_kbc_wait
    call xmsd_a20_settle
    je .ok

    pop dx
    pop ax
    stc
    ret
.ok:
    pop dx
    pop ax
    clc
    ret


xmsd_gdt:
    times 16 db 0
    dw 0xFFFF, 0
    db 0, 0x93, 0, 0
    dw 0xFFFF, 0
    db 0, 0x93, 0, 0
    times 16 db 0

xmsd_table       times XMSD_HANDLES * XMSD_ENT db 0
xmsd_end:

PLE_END
