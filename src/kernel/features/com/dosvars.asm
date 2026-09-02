; ==================================================================
; x16-PRos - the page of DOS internals programs read for themselves
; ==================================================================

DOSVARS_SYSVARS  equ 0x0022
DOSVARS_SFT      equ 0x0400

SFT_ENTRY        equ 0x35
SFT_DEVS         equ 5
SFT_COUNT        equ SFT_DEVS + DOSF_SLOTS
SFT_FIRST        equ DOSVARS_SFT + 6
DOSVARS_MCB      equ 0x0600

SFTE_REFS        equ 0x00
SFTE_MODE        equ 0x02
SFTE_ATTR        equ 0x04
SFTE_INFO        equ 0x05
SFTE_DPB         equ 0x07
SFTE_CLUS        equ 0x0B
SFTE_TIME        equ 0x0D
SFTE_DATE        equ 0x0F
SFTE_SIZE        equ 0x11
SFTE_POS         equ 0x15
SFTE_REL         equ 0x19
SFTE_DIRSEC      equ 0x1B
SFTE_DIRENT      equ 0x1F
SFTE_NAME        equ 0x20
SFTE_OWNER       equ 0x31
DOSVARS_INDOS    equ 0x019B
DOSVARS_PSPCHK   equ 0x0014
DOSVARS_CURDRV   equ 0x01BC
DOSVARS_SDA      equ 0x0200
DOSVARS_SDA_IND  equ DOSVARS_SDA + 0x00
DOSVARS_SDA_CHK  equ DOSVARS_SDA + 0x10
DOSVARS_SDA_DRV  equ DOSVARS_SDA + 0x16

; ==================================================================
; DOSVARS_INIT - lay the page out once at boot
; ==================================================================
dosvars_init:
    pusha
    push es
    push ds

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    call dosvars_seg

    xor di, di
    mov cx, 2048
    xor ax, ax
    cld
    rep stosw

    mov word [es:DOSVARS_SYSVARS + 4], DOSVARS_SFT
    mov ax, es
    mov [es:DOSVARS_SYSVARS + 6], ax

    mov di, DOSVARS_MCB
    mov byte [es:di], 'Z'
    mov word [es:di + 1], 0x0008
    mov word [es:di + 3], 0x0001
    mov ax, es
    add ax, DOSVARS_MCB >> 4
    mov [es:DOSVARS_SYSVARS - 2], ax

    mov word [es:DOSVARS_SFT], 0xFFFF
    mov word [es:DOSVARS_SFT + 2], 0xFFFF
    mov word [es:DOSVARS_SFT + 4], SFT_COUNT

    mov di, SFT_FIRST
    mov cx, 3
.con_entry:
    push cx
    mov word [es:di + SFTE_REFS], 1
    mov word [es:di + SFTE_MODE], 2
    mov word [es:di + SFTE_INFO], 0x80D3
    mov si, .name_con
    call sft_fcb_name
    add di, SFT_ENTRY
    pop cx
    loop .con_entry

    mov word [es:di + SFTE_REFS], 1
    mov word [es:di + SFTE_MODE], 2
    mov word [es:di + SFTE_INFO], 0x80C0
    mov si, .name_aux
    call sft_fcb_name
    add di, SFT_ENTRY

    mov word [es:di + SFTE_REFS], 1
    mov word [es:di + SFTE_MODE], 2
    mov word [es:di + SFTE_INFO], 0xA0C0
    mov si, .name_prn
    call sft_fcb_name

    mov byte [es:DOSVARS_INDOS], 0

    pop ds
    pop es
    popa
    ret

.name_con db 'CON', 0
.name_aux db 'AUX', 0
.name_prn db 'PRN', 0

dosvars_seg:
    push ax
    push cx
    mov ax, dosvars_block
    mov cl, 4
    shr ax, cl
    mov cx, cs
    add ax, cx
    mov es, ax
    pop cx
    pop ax
    ret

align 16
dosvars_block times 4096 db 0

; ==================================================================
; DOSVARS_STAMP_PSP - publish which process owns the DOS state
; ==================================================================
dosvars_stamp_psp:
    push ax
    push es
    call dosvars_seg
    mov ax, [cs:dos_current_psp]
    mov [es:DOSVARS_PSPCHK], ax
    mov [es:DOSVARS_SDA_CHK], ax
    pop es
    pop ax
    ret

sft_fcb_name:
    pusha
    add di, SFTE_NAME
    push di
    mov cx, 11
    mov al, ' '
    cld
    rep stosb
    pop di
    push di

    mov cx, 8
.base:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    je .have_dot
    stosb
    loop .base

.skip:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    jne .skip

.have_dot:
    pop di
    push di
    add di, 8
    mov cx, 3
.ext:
    lodsb
    test al, al
    jz .done
    stosb
    loop .ext

.done:
    pop di
    popa
    ret

; ==================================================================
; DOSVARS_SYNC_SFT - mirror the open-file table into the SFT.
; ==================================================================
dosvars_sync_sft:
    pusha
    push ds
    push es

    call dosvars_seg
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    mov si, dosfile_table
    mov di, SFT_FIRST + SFT_DEVS * SFT_ENTRY
    mov cx, DOSF_SLOTS

.slot:
    push cx
    push si
    push di

    push di
    mov cx, SFT_ENTRY
    xor al, al
    cld
    rep stosb
    pop di

    test byte [si + DF_FLAGS], DFF_USED
    jz .next

    mov word [es:di + SFTE_REFS], 1
    mov word [es:di + SFTE_MODE], 2
    mov byte [es:di + SFTE_ATTR], 0x20
    mov al, [current_drive_char]
    sub al, 'A'
    xor ah, ah
    mov [es:di + SFTE_INFO], ax
    mov ax, [si + DF_FIRST]
    mov [es:di + SFTE_CLUS], ax
    mov ax, [si + DF_TIME]
    mov [es:di + SFTE_TIME], ax
    mov ax, [si + DF_DATE]
    mov [es:di + SFTE_DATE], ax
    mov ax, [si + DF_SIZE]
    mov [es:di + SFTE_SIZE], ax
    mov ax, [si + DF_SIZE + 2]
    mov [es:di + SFTE_SIZE + 2], ax
    mov ax, [si + DF_POS]
    mov [es:di + SFTE_POS], ax
    mov ax, [si + DF_POS + 2]
    mov [es:di + SFTE_POS + 2], ax
    mov ax, [cs:dos_current_psp]
    mov [es:di + SFTE_OWNER], ax

    push si
    add si, DF_NAME
    call sft_fcb_name
    pop si

.next:
    pop di
    pop si
    pop cx
    add si, DF_ENT
    add di, SFT_ENTRY
    loop .slot

    pop es
    pop ds
    popa
    ret

dos_current_psp dw EXE_PSP_SEG
