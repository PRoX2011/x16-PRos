; This file is a part of FatBoot project (https://github.com/invin1x/FatBoot)
; Copyright (c) 2025 Alexander Zubov
; Licensed under the MIT License

; Define these macros before assembly:
;   Macros        Description                                   Example
;   ---------------------------------------------------------------------------
;   FILENAME      The name of the file to load (8.3 format).    "KERNEL  BIN"
;   LOAD_SEGMENT  The segment where the file will be loaded.    0x0100
;   LOAD_OFFSET   The offset at which the file will be loaded.  0x0000
;   JMP_SEGMENT   The segment to jump to after loading.         0x0100
;   JMP_OFFSET    The offset to jump to after loading.          0x0100

; Note: 0xB4B is THE LOWEST physical address at whitch the file can be loaded.
; If CHS addressing is used while reading a disk, 0x90000-0x9FFFF
; will be used as a temporary buffer due to ISA DMA limitations.

; -----------------------------------------------------------------------------

; IVT (1024 bytes) + BDA (256 bytes) + stack (64 bytes) = 0x500 + 64
RELOC_ADDR EQU 0x500 + 64

; CHS reading buffer is right before the upper memory area
CHS_BUFFER_SEGMENT EQU 0x9000
CHS_BUFFER_OFFSET  EQU 0x0000

; Bios Parameter Block
BPB_OEM_id              EQU RELOC_ADDR + 0x03  ; 8 BYTES
BPB_bytes_per_sector    EQU RELOC_ADDR + 0x0B  ; WORD
BPB_sectors_per_cluster EQU RELOC_ADDR + 0x0D  ; BYTE
BPB_reserved_sectors    EQU RELOC_ADDR + 0x0E  ; WORD
BPB_num_fats            EQU RELOC_ADDR + 0x10  ; BYTE
BPB_root_entries        EQU RELOC_ADDR + 0x11  ; WORD
BPB_total_sectors_16    EQU RELOC_ADDR + 0x13  ; WORD
BPB_media               EQU RELOC_ADDR + 0x15  ; BYTE
BPB_sectors_per_FAT     EQU RELOC_ADDR + 0x16  ; WORD
BPB_sectors_per_track   EQU RELOC_ADDR + 0x18  ; WORD
BPB_heads               EQU RELOC_ADDR + 0x1A  ; WORD
BPB_partition_LBA       EQU RELOC_ADDR + 0x1C  ; DWORD
BPB_total_sectors_32    EQU RELOC_ADDR + 0x20  ; DWORD

; Where to store temp data
FAT_LBA      EQU RELOC_ADDR + 512       ; DWORD
DATA_LBA     EQU RELOC_ADDR + 512 + 4   ; DWORD
DISK         EQU RELOC_ADDR + 512 + 8   ; BYTE
READ_SECTORS EQU RELOC_ADDR + 512 + 9   ; WORD
FAT_BUFFER   EQU RELOC_ADDR + 512 + 11  ; 2 sectors (usually 1024 bytes)

; Physical address at which file will be loaded
LOAD_PHYS EQU ((LOAD_SEGMENT << 4) + LOAD_OFFSET)

BITS 16
CPU 8086
ORG RELOC_ADDR + 62  ; Right after BPB in relocated boot sector

; Initialization
xor ax, ax                  ; AX = 0
mov ds, ax                  ; Data segment = 0
mov es, ax                  ; Extra segment = 0
mov ss, ax                  ; Stack segment = 0
mov sp, RELOC_ADDR          ; Stack is under relocated boot sector

; Copy boot sector
mov si, 0x7C00              ; Source
mov di, RELOC_ADDR          ; Destination
mov cx, 512                 ; Bytes to copy
rep movsb                   ; Copy

; Far jump to relocated code
jmp 0x0000:($+5)

; Save boot disk number
mov [DISK], dl

; Calculate FAT LBA = reserved sectors + partition LBA
xor bx, bx                          ; BX:CX = reserved sectors
mov cx, [BPB_reserved_sectors]
add cx, [BPB_partition_LBA]         ; BX:CX += partition LBA
adc bx, [BPB_partition_LBA + 2]
mov [FAT_LBA], cx                   ; Save BX:CX (FAT LBA)
mov [FAT_LBA + 2], bx

; Calculate root LBA = FATs * sectors per FAT + FAT LBA
mov al, [BPB_num_fats]              ; AX = FATs (AH == 0)
mul word [BPB_sectors_per_FAT]      ; DX:AX = AX * sectors per FAT
add cx, ax                          ; BX:CX = FAT LBA + DX:AX = root LBA
adc bx, dx
push bx                             ; Save root LBA to stack
push cx

; Calculate data area LBA = root entries * 32 / bytes per sector + root LBA
mov ax, 32                          ; AX = 32
mul word [BPB_root_entries]         ; DX:AX = 32 * root entries
div word [BPB_bytes_per_sector]     ; DX:AX /= bytes per sector = root sectors
push ax                             ; Save root sectors to stack
add cx, ax                          ; BX:CX = data area LBA
adc bx, 0
mov [DATA_LBA], cx                  ; Save data area LBA
mov [DATA_LBA + 2], bx

; Read root directory
pop cx                              ; Restore root sectors from stack in CX
pop ax                              ; Restore root LBA from stack in DX:AX
pop dx
mov bx, 0x1000                      ; Buffer address
push bx                             ; Save it to stack
call read_disk                      ; Read

; Find file entry in root directory
mov cx, [BPB_root_entries]          ; CX = root directory entries
pop si                              ; Current entry = buffer address from stack
.find:
    mov di, filename                ; DI = pointer to filename
    push cx                         ; Save CX to stack
    mov cx, 11                      ; CX = 11 (filename length)
    repe cmpsb                      ; Compare filenames
    je .found                       ; Jump if match
    add si, cx                      ; Point SI to next entry
    add si, 32 - 11
    pop cx                          ; Restore CX from stack
    loop .find                      ; Check next entry
    jmp error                       ; Error if checked all entries
.found:
    pop cx                          ; Free stack

; Check flags
and byte [si], 11011000b            ; Check if flags are correct
jnz error                           ; Error if flags are not correct

; Read file
mov ax, [si - 11 + 26]              ; AX = current cluster number
mov word [READ_SECTORS], 0          ; Current read sectors number = 0
.read:
    push ax                         ; Save current cluster number to stack
    TIMES 2 dec ax                  ; AX -= 2 = cluster index
    cmp ax, 0xFEF - 2               ; Check if cluster index is valid
    ja error                        ; Error if not valid
    xor ch, ch                      ; CX = cluster size (sectors to read)
    mov cl, [BPB_sectors_per_cluster]
    push cx                         ; Save cluster size to stack
    mul cx                          ; DX:AX = AX * CX = sector in data area
    add ax, [DATA_LBA]              ; DX:AX += data area LBA = cluster LBA
    adc dx, [DATA_LBA + 2]
    push dx                         ; Save cluster LBA to stack
    push ax
    mov ax, [READ_SECTORS]          ; AX = read sectors
    mul word [BPB_bytes_per_sector] ; DX:AX = read bytes
    add ax, LOAD_PHYS & 0xFFFF      ; DX:AX += load address = buffer address
    adc dx, LOAD_PHYS >> 16
    mov bx, ax                      ; BX = buffer offset
    and bx, 0xF
    mov cl, 12                      ; DX = buffer segment
    shl dx, cl
    mov cl, 4
    shr ax, cl
    or dx, ax
    mov es, dx                      ; ES = DX = segment
    pop ax                          ; Restore cluster LBA from stack in DX:AX
    pop dx
    pop cx                          ; Restore cluster size from stack in CX
    call read_disk                  ; Read cluster
    pop ax                          ; Restore current cluster number from stack
    mov bx, 3                       ; BX = 3
    mul bx                          ; DX:AX = AX * 3
    dec bx                          ; BX = 2
    div bx                          ; AX = FAT value address rel to FAT LBA
    push dx                         ; Save remainder to stack
    xor dx, dx                      ; DX = 0
    div word [BPB_bytes_per_sector] ; AX:DX = FAT value seg:off rel to FAT LBA
    push dx                         ; Save FAT value offset to stack
    xor dx, dx                      ; DX = 0
    add ax, [FAT_LBA]               ; DX:AX += FAT LBA = FAT value sector LBA
    adc dx, [FAT_LBA + 2]
    mov cx, 2                       ; sectors to read = 2
    xor bx, bx                      ; BX = 0 (temp)
    mov es, bx                      ; Buffer segment = BX = 0
    mov bx, FAT_BUFFER              ; Buffer offset
    call read_disk                  ; Read disk
    pop bx                          ; Restore FAT value offset from stack in BX
    mov ax, [FAT_BUFFER + bx]       ; AX = word with next cluster number
    pop cx                          ; Restore remainder from stack in CX
    jcxz .even                      ; AX = next cluster number
    mov cl, 4
    shr ax, cl
    jmp .done
    .even:
    and ax, 0x0FFF
    .done:
    cmp ax, 0xFF7                   ; Check if EOF
    ja .loaded                      ; Jump if EOF
    xor bh, bh                      ; BX = sectors per cluster
    mov bl, [BPB_sectors_per_cluster]
    add [READ_SECTORS], bx          ; Read sectors += sectors per cluster
    jmp .read                       ; Read next cluster
.loaded:
    jmp JMP_SEGMENT:JMP_OFFSET      ; Far jump to loaded file



; Inputs: DX:AX = LBA, CX = sectors to read,
;         ES:BX = buffer address, [DISK] = disk number.
; AX, CX, BX, DX, SI, DI are not saved, and DS is set to 0
read_disk:
    ; Fill out DAP structure in stack to save memory
    xor si, si
    push si                         ; LBA
    push si
    push dx
    push ax
    push es                         ; Buffer segment
    push bx                         ; Buffer offset
    push cx                         ; Number of sectors to read
    mov si, 0x0010                  ; Structure size + reserved
    push si
    ; Read disk
    mov si, sp                      ; DAP structure address = stack pointer
    push dx                         ; Save LBA to stack
    push ax
    mov ah, 0x42                    ; Extended read function
    mov dl, [DISK]                  ; Disk number
    int 0x13                        ; BIOS disk interrupt
    pop ax                          ; Restore LBA from stack to DX:AX
    pop dx
    jnc .done                       ; Jump if no errors
    ; Error, try CHS
    push bx                         ; Save buffer offset to stack
    push cx                         ; Save sectors to read to stack
    div word [BPB_sectors_per_track]; AX = LBA / sectors per track
    inc dx                          ; DX = LBA % sectors per track + 1 = sector
    push dx                         ; Save sector to stack
    xor dx, dx                      ; DX = 0
    div word [BPB_heads]            ; AX = DX:AX / heads = cylinder
                                    ; DX = DX:AX % heads = head
    cmp ax, 0000001111111111b       ; Error if cylinder > 1023 (CHS limit)
    ja error
    pop bx                          ; Restore sector from stack in BX
    mov dh, dl                      ; DH = head
    mov ch, al                      ; CH = cylinder (low 8 bits)
    mov cl, 6                       ; CL = 6 (temp)
    shl ah, cl                      ; AH << 6
    or ah, bl                       ; AH = 2 high cylinder bits + sector
    mov cl, ah                      ; CL = AH = 2 high cylinder bits + sector
    pop ax                          ; Restore sectors to read from stack in AX
    push es                         ; Save buffer segment to stack
    push ax                         ; Save sectors to read to stack again
    mov bx, CHS_BUFFER_SEGMENT      ; ES:BX = buffer
    mov es, bx
    mov bx, CHS_BUFFER_OFFSET
    mov ah, 0x02                    ; BIOS read sectors function
    mov dl, [DISK]                  ; Disk number
    int 0x13                        ; BIOS disk interrupt
    jc error                        ; If still error, jump to error code
    pop ax                          ; Restore read sectors from stack in AX
    mul word [BPB_bytes_per_sector] ; AX = read bytes (DX = 0)
    mov cx, ax                      ; CX = AX = read bytes
    pop es                          ; Restore final address from stack in ES:DI
    pop di
    mov si, CHS_BUFFER_SEGMENT      ; DS:SI = temp buffer
    mov ds, si
    mov si, CHS_BUFFER_OFFSET
    rep movsb                       ; Copy CX bytes from DS:SI to ES:DI
    mov ds, dx                      ; DS = 0 (DX == 0)
.done:
    add sp, 16                      ; Release stack
    ret                             ; Return

error:
    mov si, msg_error           ; Point SI to error message
    .print:
        lodsb                   ; AL = next character from SI
        cmp al, 0               ; Check for null terminator
        je .done                ; Exit if null terminator
        mov ah, 0x0E            ; Teletype output function
        mov bh, 0x00            ; Page number
        mov bl, 0x07            ; Text attribute (0x07 = light gray on black)
        int 0x10                ; BIOS video interrupt
        jmp .print              ; Continue to next character
    .done:
        xor ah, ah              ; Wait for keypress function
        int 0x16                ; BIOS keyboard interrupt
        int 0x19                ; Continue booting

; Filename
filename: DB FILENAME

; Error message
msg_error: DB "Boot error!", 0x0D, 0x0A, 0
