; ==================================================================
; x16-PRos -- The x16-PRos bootloader
; Copyright (C) 2025 PRoX2011
;
; Loads the kernel (KERNEL.BIN) for execution.
; Uses FAT12 file system.
; ==================================================================

[BITS 16]
[ORG 0x0000]

start: jmp main

; ========================= DISK PARAMETERS ========================

; bpbOEM               - 8-byte OEM identifier
; bpbBytesPerSector    - Bytes per sector (512)
; bpbSectorsPerCluster - Sectors per allocation unit (1)
; bpbReservedSectors   - Reserved sectors including boot sector (1)
; bpbNumberOfFATs      - Number of FAT copies (2)
; bpbRootEntries       - Max root directory entries (224)
; bpbTotalSectors      - Total sectors on disk (2880)
; bpbMedia             - Media descriptor (0xF0 = removable)
; bpbSectorsPerFAT     - Sectors per FAT table (9)
; bpbSectorsPerTrack   - Sectors per track (18)
; bpbHeadsPerCylinder  - Number of heads (2)
; bpbHiddenSectors     - Hidden sectors (0)
; bpbTotalSectorsBig   - Large sector count (0)
; bsDriveNumber        - Drive number (0 = auto)
; bsUnused             - Reserved (0)
; bsExtBootSignature   - Extended boot sig (0x29)
; bsSerialNumber       - Volume serial number
; bsVolumeLabel        - 11-byte volume label
; bsFileSystem         - 8-byte filesystem type

bpbOEM               DB "x16-PROS"
bpbBytesPerSector    DW 512
bpbSectorsPerCluster DB 1
bpbReservedSectors   DW 1
bpbNumberOfFATs      DB 2
bpbRootEntries       DW 224
bpbTotalSectors      DW 2880
bpbMedia             DB 0xf0
bpbSectorsPerFAT     DW 9
bpbSectorsPerTrack   DW 18
bpbHeadsPerCylinder  DW 2
bpbHiddenSectors     DD 0
bpbTotalSectorsBig   DD 0
bsDriveNumber        DB 0
bsUnused             DB 0
bsExtBootSignature   DB 0x29
bsSerialNumber       DD 0x00000000
bsVolumeLabel        DB "x16-PROS   "
bsFileSystem         DB "FAT12   "

; ===================================================================


Print:
    lodsb
    or al, al
    jz PrintDone
    mov ah, 0eh
    int 10h
    jmp Print
PrintDone:
    ret

absoluteSector db 0x00
absoluteHead db 0x00
absoluteTrack db 0x00

ClusterLBA:
    sub ax, 0x0002
    xor cx, cx
    mov cl, BYTE [bpbSectorsPerCluster]
    mul cx
    add ax, WORD [datasector]
    ret

LBACHS:
    xor dx, dx
    div WORD [bpbSectorsPerTrack]
    inc dl
    mov BYTE [absoluteSector], dl
    xor dx, dx
    div WORD [bpbHeadsPerCylinder]
    mov BYTE [absoluteHead], dl
    mov BYTE [absoluteTrack], al
    ret

ReadSectors:
    .MAIN
    mov di, 0x0005
.SECTORLOOP
    push ax
    push bx
    push cx
    call LBACHS
    mov ah, 0x02
    mov al, 0x01
    mov ch, BYTE [absoluteTrack]
    mov cl, BYTE [absoluteSector]
    mov dh, BYTE [absoluteHead]
    mov dl, BYTE [bsDriveNumber]
    int 0x13
    jnc .SUCCESS
    xor ax, ax
    int 0x13
    dec di
    pop cx
    pop bx
    pop ax
    jnz .SECTORLOOP
    int 0x18
.SUCCESS
    mov si, msgProgress
    call Print
    pop cx
    pop bx
    pop ax
    add bx, WORD [bpbBytesPerSector]
    inc ax
    loop .MAIN
    ret

main:
    cli
    mov ax, 0x07C0
    mov ds, ax
    mov es, ax
    ;mov fs, ax
    ;mov gs, ax
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0xFFFF
    sti
    mov si, msgLoading
    call Print

LOAD_ROOT:
    xor cx, cx
    xor dx, dx
    mov ax, 0x0020
    mul WORD [bpbRootEntries]
    div WORD [bpbBytesPerSector]
    xchg ax, cx
    mov al, BYTE [bpbNumberOfFATs]
    mul WORD [bpbSectorsPerFAT]
    add ax, WORD [bpbReservedSectors]
    mov WORD [datasector], ax
    add WORD [datasector], cx
    mov bx, 0x0200
    call ReadSectors

    mov cx, WORD [bpbRootEntries]
    mov di, 0x0200
.LOOP:
    push cx
    mov cx, 0x000B
    mov si, ImageName
    push di
    rep cmpsb
    pop di
    je LOAD_FAT
    pop cx
    add di, 0x0020
    loop .LOOP
    jmp FAILURE

LOAD_FAT:
    mov dx, WORD [di + 0x001A]
    mov WORD [cluster], dx
    xor ax, ax
    mov al, BYTE [bpbNumberOfFATs]
    mul WORD [bpbSectorsPerFAT]
    mov cx, ax
    mov ax, WORD [bpbReservedSectors]
    mov bx, 0x0200
    call ReadSectors
    mov ax, 0x2000
    mov es, ax
    mov bx, 0x0000
    push bx

LOAD_IMAGE:
    mov ax, WORD [cluster]
    pop bx
    call ClusterLBA
    xor cx, cx
    mov cl, BYTE [bpbSectorsPerCluster]
    call ReadSectors
    push bx
    mov ax, WORD [cluster]
    mov cx, ax
    mov dx, ax
    shr dx, 0x0001
    add cx, dx
    mov bx, 0x0200
    add bx, cx
    mov dx, WORD [bx]
    test ax, 0x0001
    jnz .ODD_CLUSTER

.EVEN_CLUSTER:
    and dx, 0000111111111111b
    jmp .DONE

.ODD_CLUSTER:
    shr dx, 0x0004

.DONE:
    mov WORD [cluster], dx
    cmp dx, 0x0FF0
    jb LOAD_IMAGE

DONE:
    mov si, msgCRLF
    call Print
    push WORD 0x2000
    push WORD 0x0000
    retf

FAILURE:
    mov si, msgFailure
    call Print
    mov ah, 0x00
    int 0x16
    int 0x19

datasector dw 0x0000
cluster dw 0x0000
ImageName db "KERNEL  BIN"
msgLoading db 0x0D, 0x0A, "Loading Boot Image ", 0x00
msgCRLF db 0x0D, 0x0A, 0x00
msgProgress db ".", 0x00
msgFailure db 0x0D, 0x0A, "KERNEL.BIN not found. Press Any Key to Reboot", 0x0D, 0x0A, 0x00

TIMES 510-($-$$) DB 0
DW 0xAA55