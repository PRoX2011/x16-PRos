; ==================================================================
; x16-PRos -- FDISK. Floppy disk format utility for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Usage: fdisk <drive_letter>
;
; Options:
;   1 - Zero disk and create FAT12 filesystem
;   2 - Zero disk only
;   ESC - Cancel
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

TOTAL_SECTORS   equ 2880
SECS_PER_TRACK  equ 18
NUM_HEADS       equ 2

jmp start

%include "programs/lib/string.inc"


start:
    mov [param_list], si

    mov ah, 0x05
    int 0x21

    or si, si
    jz show_usage
    cmp byte [si], 0
    je show_usage

    mov si, [param_list]
    call string_string_parse
    cmp ax, 0
    je show_usage

    mov si, ax
    mov al, [si]
    
    cmp byte [si+1], 0
    je .got_letter
    cmp byte [si+1], ':'
    jne bad_drive
    cmp byte [si+2], 0
    jne bad_drive

.got_letter:
    cmp al, 'a'
    jb .check_drive
    cmp al, 'z'
    ja .check_drive
    sub al, 32

.check_drive:
    cmp al, 'A'
    je .drive_a
    cmp al, 'B'
    je .drive_b
    jmp bad_drive

.drive_a:
    mov byte [drive_letter], 'A'
    mov byte [drive_num], 0x00
    jmp show_warning

.drive_b:
    mov byte [drive_letter], 'B'
    mov byte [drive_num], 0x01
    jmp show_warning


show_usage:
    mov ah, 0x04
    mov si, msg_usage
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


bad_drive:
    mov ah, 0x04
    mov si, msg_bad_drive
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


show_warning:
    mov ah, 0x04
    mov si, msg_warning_pre
    int 0x21

    mov ah, 0x0E
    mov al, [drive_letter]
    mov bl, 0x0C
    int 0x10

    mov ah, 0x04
    mov si, msg_warning_post
    int 0x21
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, msg_option1
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, msg_option2
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, msg_option_esc
    int 0x21
    mov ah, 0x05
    int 0x21

wait_choice:
    mov ah, 0x00
    int 0x16

    cmp al, '1'
    je .opt_fat12
    cmp al, '2'
    je .opt_zero
    cmp al, 27
    je cancel
    jmp wait_choice

.opt_fat12:
    mov byte [format_mode], 1
    jmp confirm

.opt_zero:
    mov byte [format_mode], 2
    jmp confirm


confirm:
    mov ah, 0x05
    int 0x21
    mov ah, 0x04
    mov si, msg_confirm
    int 0x21

    mov ah, 0x00
    int 0x16

    cmp al, 'Y'
    je do_format
    cmp al, 'y'
    je do_format

cancel:
    mov ah, 0x05
    int 0x21
    mov ah, 0x01
    mov si, msg_cancelled
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


do_format:
    mov ah, 0x05
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x00
    mov dl, [drive_num]
    int 0x13
    jc disk_error

    mov ah, 0x03
    mov si, msg_formatting_pre
    int 0x21

    mov ah, 0x0E
    mov al, [drive_letter]
    mov bl, 0x0B
    int 0x10

    mov ah, 0x03
    mov si, msg_formatting_post
    int 0x21
    mov ah, 0x05
    int 0x21

    mov word [current_sector], 0

.zero_loop:
    cmp word [current_sector], TOTAL_SECTORS
    jge .zero_done

    mov ax, [current_sector]
    mov bx, zero_sector
    call write_sector
    jc disk_error

    mov ax, [current_sector]
    xor dx, dx
    mov bx, SECS_PER_TRACK
    div bx
    cmp dx, 0
    jne .skip_progress

    call show_progress

.skip_progress:
    inc word [current_sector]
    jmp .zero_loop

.zero_done:
    mov word [current_sector], TOTAL_SECTORS
    call show_progress

    mov ah, 0x05
    int 0x21

    cmp byte [format_mode], 1
    jne .format_complete

    call create_fat12
    jc disk_error

.format_complete:
    mov ah, 0x05
    int 0x21
    mov ah, 0x02
    mov si, msg_complete
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


disk_error:
    mov ah, 0x05
    int 0x21
    mov ah, 0x04
    mov si, msg_disk_error
    int 0x21
    mov ah, 0x05
    int 0x21
    ret


; ========================================================================
; LBA_TO_CHS - Convert LBA sector number to CHS for 1.44MB floppy
; IN:  AX = LBA sector number
; OUT: CH = cylinder, CL = sector, DH = head
; ========================================================================
lba_to_chs:
    push bx

    xor dx, dx
    mov bx, SECS_PER_TRACK
    div bx
    mov cl, dl
    inc cl

    xor dx, dx
    mov bx, NUM_HEADS
    div bx
    mov ch, al
    mov dh, dl

    pop bx
    ret


; ========================================================================
; WRITE_SECTOR - Write one sector to disk with retry
; IN:  AX = LBA sector number, BX = buffer address
; OUT: CF = set on error
; ========================================================================
write_sector:
    pusha

    mov [.lba], ax
    mov [.buf], bx
    mov byte [.retries], 3

.retry:
    mov ax, [.lba]
    call lba_to_chs

    mov bx, [.buf]
    mov dl, [drive_num]
    mov ah, 0x03
    mov al, 1
    stc
    int 0x13
    jnc .ok

    dec byte [.retries]
    jz .fail

    mov ah, 0x00
    mov dl, [drive_num]
    int 0x13
    jmp .retry

.ok:
    popa
    clc
    ret

.fail:
    popa
    stc
    ret

.lba     dw 0
.buf     dw 0
.retries db 0


; ========================================================================
; SHOW_PROGRESS - Display formatting progress on current line
; ========================================================================
show_progress:
    pusha

    mov ah, 0x0E
    mov al, 0x0D
    int 0x10

    mov ah, 0x03
    mov si, msg_progress
    int 0x21

    mov ax, [current_sector]
    mov cx, 100
    mul cx
    mov cx, TOTAL_SECTORS
    div cx

    call string_int_to_string
    mov si, ax
    mov ah, 0x03
    int 0x21

    mov ah, 0x03
    mov si, msg_percent
    int 0x21

    popa
    ret


; ========================================================================
; CREATE_FAT12 - Write FAT12 filesystem structures to formatted disk
; ========================================================================
create_fat12:
    pusha

    mov ah, 0x03
    mov si, msg_creating_fs
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ax, 0
    mov bx, fat12_boot_sector
    call write_sector
    jc .error

    mov ax, 1
    mov bx, fat_init_sector
    call write_sector
    jc .error

    mov ax, 10
    mov bx, fat_init_sector
    call write_sector
    jc .error

    popa
    clc
    ret

.error:
    popa
    stc
    ret


section .data

param_list      dw 0
drive_letter    db 0
drive_num       db 0
format_mode     db 0
current_sector  dw 0

msg_usage       db 'Usage: fdisk <drive_letter>', 10, 13
                db '  Formats a floppy disk (A: or B:)', 0

msg_bad_drive   db 'Only floppy drives (A:, B:) are supported', 0

msg_warning_pre  db 'WARNING: All data on drive ', 0
msg_warning_post db ': will be permanently destroyed!', 0

msg_option1     db '  1 - Zero disk and create FAT12 filesystem', 0
msg_option2     db '  2 - Zero disk only', 0
msg_option_esc  db '  ESC - Cancel', 0

msg_confirm     db 'Are you sure? (Y/N) ', 0
msg_cancelled   db 'Operation cancelled.', 0

msg_formatting_pre  db 'Formatting drive ', 0
msg_formatting_post db ': ...', 0

msg_progress    db '  Progress: ', 0
msg_percent     db '%   ', 0

msg_creating_fs db 'Creating FAT12 filesystem...', 0
msg_complete    db 'Format complete!', 0
msg_disk_error  db 'Disk error! Format aborted.', 0

; FAT12 boot sector template (512 bytes)
fat12_boot_sector:
    db 0xEB, 0x3C, 0x90        ; JMP SHORT 0x3E + NOP
    db 'x16-PROS'              ; OEM name (8 bytes)
    dw 512                     ; Bytes per sector
    db 1                       ; Sectors per cluster
    dw 1                       ; Reserved sectors
    db 2                       ; Number of FATs
    dw 224                     ; Root directory entries
    dw 2880                    ; Total sectors (1.44MB)
    db 0xF0                    ; Media descriptor (1.44MB floppy)
    dw 9                       ; Sectors per FAT
    dw 18                      ; Sectors per track
    dw 2                       ; Number of heads
    dd 0                       ; Hidden sectors
    dd 0                       ; Total sectors (32-bit, unused)
    db 0x00                    ; BIOS drive number
    db 0                       ; Reserved
    db 0x29                    ; Extended boot signature
    dd 0x50524F53              ; Volume serial number ('PROS')
    db "x16-PROS   "           ; Volume label (11 bytes)
    db 'FAT12   '              ; Filesystem type (8 bytes)
    times 448 db 0             ; Boot code area (empty)
    dw 0xAA55

; FAT initial sector - media descriptor + end-of-chain markers
fat_init_sector:
    db 0xF0, 0xFF, 0xFF
    times 509 db 0

; Zero-filled sector buffer for wiping
zero_sector:
    times 512 db 0