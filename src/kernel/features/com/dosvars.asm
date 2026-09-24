; ==================================================================
; x16-PRos - the page of DOS internals programs read for themselves
; ==================================================================

DOSVARS_DRIVES   equ 5

DOSVARS_SYSVARS  equ 0x0022
DOSVARS_NUL      equ DOSVARS_SYSVARS + 0x22
DOSVARS_CON      equ 0x0060
DOSVARS_CLOCK    equ 0x0074
DOSVARS_DPB      equ 0x0090
DOSVARS_CDS      equ 0x0280
DOSVARS_SFT      equ 0x0420

DEVHDR_LEN       equ 18

DPB_LEN          equ 0x20
DPB_DRIVE        equ 0x00
DPB_UNIT         equ 0x01
DPB_BPS          equ 0x02
DPB_SPC1         equ 0x04
DPB_SHIFT        equ 0x05
DPB_RESSEC       equ 0x06
DPB_FATS         equ 0x08
DPB_ROOTENT      equ 0x09
DPB_DATASEC      equ 0x0B
DPB_MAXCLUS      equ 0x0D
DPB_SPF          equ 0x0F
DPB_DIRSEC       equ 0x10
DPB_DRIVER       equ 0x12
DPB_MEDIA        equ 0x16
DPB_ACCESS       equ 0x17
DPB_NEXT         equ 0x18
DPB_LASTCLUS     equ 0x1C
DPB_FREECLUS     equ 0x1E

CDS_LEN          equ 0x51
CDS_PATH         equ 0x00
CDS_FLAGS        equ 0x43
CDS_DPB          equ 0x45
CDS_CLUSTER      equ 0x49
CDS_ROOTOFF      equ 0x4F
CDS_F_PHYSICAL   equ 0x4000

SFT_ENTRY        equ 0x35
SFT_DEVS         equ 5
SFT_COUNT        equ SFT_DEVS + DOSF_SLOTS
SFT_FIRST        equ DOSVARS_SFT + 6
DOSVARS_MCB      equ 0x0860

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

    mov ax, es
    mov word [es:DOSVARS_SYSVARS + 0x00], DOSVARS_DPB
    mov [es:DOSVARS_SYSVARS + 0x02], ax
    mov word [es:DOSVARS_SYSVARS + 0x04], DOSVARS_SFT
    mov [es:DOSVARS_SYSVARS + 0x06], ax
    mov word [es:DOSVARS_SYSVARS + 0x08], DOSVARS_CLOCK
    mov [es:DOSVARS_SYSVARS + 0x0A], ax
    mov word [es:DOSVARS_SYSVARS + 0x0C], DOSVARS_CON
    mov [es:DOSVARS_SYSVARS + 0x0E], ax
    mov word [es:DOSVARS_SYSVARS + 0x10], 512
    mov word [es:DOSVARS_SYSVARS + 0x16], DOSVARS_CDS
    mov [es:DOSVARS_SYSVARS + 0x18], ax
    mov byte [es:DOSVARS_SYSVARS + 0x20], DOSVARS_DRIVES
    mov byte [es:DOSVARS_SYSVARS + 0x21], DOSVARS_DRIVES

    mov di, DOSVARS_NUL
    mov si, .hdr_nul
    mov bx, DOSVARS_CON
    call dosvars_devhdr
    mov di, DOSVARS_CON
    mov si, .hdr_con
    mov bx, DOSVARS_CLOCK
    call dosvars_devhdr
    mov di, DOSVARS_CLOCK
    mov si, .hdr_clock
    mov bx, 0xFFFF
    call dosvars_devhdr

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

    call dosvars_sync_drives

    pop ds
    pop es
    popa
    ret

.name_con db 'CON', 0
.name_aux db 'AUX', 0
.name_prn db 'PRN', 0

.hdr_nul   dw 0x8004
           db 'NUL     '
.hdr_con   dw 0x8013
           db 'CON     '
.hdr_clock dw 0x8008
           db 'CLOCK$  '

; ==================================================================
; DOSVARS_DEVHDR - lay down one device driver header
; IN : ES:DI = where it goes
;      DS:SI = attribute word + 8-char name
;      BX = offset of the next header in the chain, 0xFFFF to end it
; OUT : nothing (all registers preserved)
; ==================================================================
dosvars_devhdr:
    pusha
    mov ax, bx
    mov [es:di + 0x00], ax
    cmp bx, 0xFFFF
    je .last
    mov ax, es
    jmp .seg
.last:
    mov ax, 0xFFFF
.seg:
    mov [es:di + 0x02], ax
    lodsw
    mov [es:di + 0x04], ax
    mov word [es:di + 0x06], 0
    mov word [es:di + 0x08], 0
    add di, 0x0A
    mov cx, 8
    cld
    rep movsb
    popa
    ret

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
; DOSVARS_SYNC_DRIVES - refresh the DPB chain and the CDS array
; IN : DS = KERNEL_DATA_SEG
; OUT : nothing (all registers preserved)
; ==================================================================
dosvars_sync_drives:
    pusha
    push ds
    push es
    call dosvars_seg
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    xor bx, bx
.drive:
    cmp bx, DOSVARS_DRIVES
    jae .done

    ; ---------------- DPB ----------------
    mov ax, bx
    mov cx, DPB_LEN
    mul cx
    mov di, DOSVARS_DPB
    add di, ax

    mov [es:di + DPB_DRIVE], bl
    mov [es:di + DPB_UNIT], bl
    mov word [es:di + DPB_BPS], 512

    mov ax, [fs_spc]
    dec ax
    mov [es:di + DPB_SPC1], al
    inc ax
    call dosvars_log2
    mov [es:di + DPB_SHIFT], al

    mov ax, [fs_fat_lba]
    mov [es:di + DPB_RESSEC], ax
    mov byte [es:di + DPB_FATS], 2
    mov ax, [fs_root_ents]
    mov [es:di + DPB_ROOTENT], ax
    mov ax, [fs_clus_base]
    mov [es:di + DPB_DATASEC], ax
    mov ax, [fs_total_clus]
    inc ax
    mov [es:di + DPB_MAXCLUS], ax
    mov ax, [fs_fat_secs]
    mov [es:di + DPB_SPF], al
    mov ax, [fs_root_lba]
    mov [es:di + DPB_DIRSEC], ax

    mov word [es:di + DPB_DRIVER], DOSVARS_NUL
    mov ax, es
    mov [es:di + DPB_DRIVER + 2], ax
    mov byte [es:di + DPB_MEDIA], 0xF0
    mov byte [es:di + DPB_ACCESS], 0
    mov word [es:di + DPB_LASTCLUS], 2
    mov word [es:di + DPB_FREECLUS], 0xFFFF

    mov ax, bx
    inc ax
    cmp ax, DOSVARS_DRIVES
    jae .dpb_last
    mov cx, DPB_LEN
    mul cx
    add ax, DOSVARS_DPB
    mov [es:di + DPB_NEXT], ax
    mov ax, es
    mov [es:di + DPB_NEXT + 2], ax
    jmp .cds
.dpb_last:
    mov word [es:di + DPB_NEXT], 0xFFFF
    mov word [es:di + DPB_NEXT + 2], 0xFFFF

    ; ---------------- CDS ----------------
.cds:
    mov ax, bx
    mov cx, CDS_LEN
    mul cx
    mov di, DOSVARS_CDS
    add di, ax
    push di

    push di
    mov cx, CDS_LEN
    xor al, al
    cld
    rep stosb
    pop di

    mov al, bl
    add al, 'A'
    mov [es:di + CDS_PATH], al
    mov byte [es:di + CDS_PATH + 1], ':'
    mov byte [es:di + CDS_PATH + 2], '\'
    mov byte [es:di + CDS_PATH + 3], 0
    mov word [es:di + CDS_ROOTOFF], 2

    mov ax, bx
    mov cx, DPB_LEN
    mul cx
    add ax, DOSVARS_DPB
    mov [es:di + CDS_DPB], ax
    mov ax, es
    mov [es:di + CDS_DPB + 2], ax

    mov al, [current_drive_char]
    sub al, 'A'
    xor ah, ah
    cmp ax, bx
    jne .cds_done

    mov word [es:di + CDS_FLAGS], CDS_F_PHYSICAL
    mov ax, [current_dir_cluster]
    mov [es:di + CDS_CLUSTER], ax
    call dosvars_cds_path

.cds_done:
    pop di
    inc bx
    jmp .drive
.done:
    pop es
    pop ds
    popa
    ret

dosvars_cds_path:
    pusha
    mov si, current_directory
    cmp byte [si], 0
    je .done
    add di, CDS_PATH + 3
    mov cx, 63
.copy:
    lodsb
    test al, al
    jz .done
    cmp al, '/'
    jne .store
    mov al, '\'
.store:
    stosb
    loop .copy
.done:
    mov byte [es:di], 0
    popa
    ret

dosvars_log2:
    push cx
    xor cl, cl
.shift:
    cmp ax, 1
    jbe .done
    shr ax, 1
    inc cl
    jmp .shift
.done:
    mov al, cl
    pop cx
    ret

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
