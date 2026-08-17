; ==================================================================
; x16-PRos - disk I/O for the DOS compatibility layer
; ==================================================================

; NOTE: The kernel filesystem only knows how to load and 
;       store whole files, so an open file is held
;       in a RAM buffer taken from the DOS arena (see dosmem.asm)

DOSF_SLOTS       equ 8
DOSF_FIRST       equ 5
DOSF_MAXPARAS    equ DOSMEM_TOP - DOSMEM_BASE
DOSF_NEWPARAS    equ 0x0400
DOSF_SECTOR      equ disk_buffer + 0x1200
DOSF_SPARE_SEG   equ 0x1800
DOSF_SPARE_PARAS equ 0x0800

DF_NAME          equ 0
DF_SEG           equ 13
DF_PARAS         equ 15
DF_SIZE          equ 17
DF_POS           equ 21
DF_FLAGS         equ 25
DF_FIRST         equ 26
DF_CCLUS         equ 28
DF_CIDX          equ 30
DF_ENT           equ 32

DFF_USED         equ 0x01
DFF_DIRTY        equ 0x02
DFF_BUF          equ 0x04

; ==================================================================
; dosfile_init - drop every opened handle
; ==================================================================
dosfile_init:
    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    mov di, dosfile_table
    mov cx, DOSF_SLOTS * DF_ENT
    xor al, al
    cld
    rep stosb

    mov byte [dosf_spare_taken], 0

    pop es
    pop ds
    popa
    ret

; ==================================================================
; dosfile_slot - map a DOS handle to a table entry.
; IN : BX = handle
;      DS = KERNEL_DATA_SEG
; OUT: SI = slot
;      CF = 1 if the handle is not an open file
; ==================================================================
dosfile_slot:
    push ax
    mov ax, bx
    sub ax, DOSF_FIRST
    jb .bad
    cmp ax, DOSF_SLOTS
    jae .bad

    push dx
    mov si, DF_ENT
    mul si
    pop dx
    mov si, dosfile_table
    add si, ax

    test byte [si + DF_FLAGS], DFF_USED
    jz .bad

    pop ax
    clc
    ret

.bad:
    pop ax
    stc
    ret

; ==================================================================
; dosfile_free_slot - find a closed table entry.
; IN : DS = KERNEL_DATA_SEG
; OUT: SI = slot
;      BX = handle
;      CF = 1 if all handles are in use
; ==================================================================
dosfile_free_slot:
    push cx
    mov si, dosfile_table
    mov bx, DOSF_FIRST
    mov cx, DOSF_SLOTS
.scan:
    test byte [si + DF_FLAGS], DFF_USED
    jz .hit
    add si, DF_ENT
    inc bx
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ==================================================================
; dosfile_store_name - copy com_path_buffer into a slot (13 bytes).
; IN : SI = slot
;      DS = ES = KERNEL_DATA_SEG
; ==================================================================
dosfile_store_name:
    pusha
    mov di, si
    mov si, com_path_buffer
    mov cx, 12
    cld
.copy:
    lodsb
    stosb
    test al, al
    jz .done
    loop .copy
    mov byte [di], 0
.done:
    popa
    ret

dosfile_paras_for:
    push bx
    push cx

    add ax, 15
    adc dx, 0
    cmp dx, 0x0010
    jae .too_big

    mov bx, dx
    mov cl, 4
    shr ax, cl
    mov cl, 12
    shl bx, cl
    or ax, bx

    add ax, 31
    jc .too_big
    and ax, 0xFFE0
    jnz .have
    mov ax, 32
.have:
    cmp ax, DOSF_MAXPARAS
    ja .too_big

    pop cx
    pop bx
    clc
    ret

.too_big:
    pop cx
    pop bx
    stc
    ret

dosfile_far:
    push bx
    push cx

    mov bx, ax
    and bx, 0x000F

    mov cl, 4
    shr ax, cl
    push bx
    mov bx, dx
    mov cl, 12
    shl bx, cl
    or ax, bx
    pop bx

    add ax, [si + DF_SEG]
    mov dx, ax
    mov ax, bx

    pop cx
    pop bx
    ret

dosfile_fill_gap:
    pusha
    push es

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    sub ax, [si + DF_SIZE]
    sbb dx, [si + DF_SIZE + 2]
    jb .done
    mov [cs:.left_lo], ax
    mov [cs:.left_hi], dx
    or ax, dx
    jz .done

    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    call dosfile_far
    mov es, dx
    mov di, ax
    xor al, al
    cld

.pass:
    mov cx, 0x8000
    cmp word [cs:.left_hi], 0
    jne .clip
    cmp [cs:.left_lo], cx
    jae .clip
    mov cx, [cs:.left_lo]
.clip:
    mov bx, di
    neg bx
    jz .fill
    cmp cx, bx
    jbe .fill
    mov cx, bx
.fill:
    sub [cs:.left_lo], cx
    sbb word [cs:.left_hi], 0
    rep stosb

    test di, di
    jnz .next
    mov bx, es
    add bx, 0x1000
    mov es, bx
.next:
    mov ax, [cs:.left_lo]
    or ax, [cs:.left_hi]
    jnz .pass

.done:
    pop es
    popa
    ret

.left_lo    dw 0
.left_hi    dw 0

; ==================================================================
; dosfile_grow - make sure a slot's buffer can hold DX:AX bytes.
; IN : SI = slot
;      DX:AX = capacity needed in bytes
;      DS = KERNEL_DATA_SEG
; OUT: CF = 1 if the buffer could not be made large enough
; ==================================================================
dosfile_grow:
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    call dosfile_paras_for
    jc .fail
    mov [cs:.need], ax

    cmp ax, [si + DF_PARAS]
    jbe .ok

    mov ax, [si + DF_PARAS]
    shl ax, 1
    jnc .no_overflow
    mov ax, DOSF_MAXPARAS
.no_overflow:
    cmp ax, [cs:.need]
    jae .want_ready
    mov ax, [cs:.need]
.want_ready:
    cmp ax, DOSF_MAXPARAS
    jbe .want_capped
    mov ax, DOSF_MAXPARAS
.want_capped:
    mov [cs:.want], ax

.attempt:
    mov ax, [si + DF_SEG]
    mov bx, [cs:.want]
    call dosmem_resize
    jnc .in_place

    mov bx, [cs:.want]
    call dosmem_alloc
    jnc .moved

    mov ax, [cs:.want]
    cmp ax, [cs:.need]
    je .fail
    mov ax, [cs:.need]
    mov [cs:.want], ax
    jmp .attempt

.moved:
    mov [cs:.newseg], ax
    mov [cs:.dstseg], ax
    mov ax, [si + DF_SEG]
    mov [cs:.oldseg], ax
    mov [cs:.srcseg], ax

    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    mov [cs:.left_lo], ax
    mov [cs:.left_hi], dx

    push ds
    push si
    push di
.copy_pass:
    mov ax, [cs:.left_lo]
    or ax, [cs:.left_hi]
    jz .copy_done

    mov cx, 0x8000
    cmp word [cs:.left_hi], 0
    jne .copy_chunk
    cmp [cs:.left_lo], cx
    jae .copy_chunk
    mov cx, [cs:.left_lo]
.copy_chunk:
    sub [cs:.left_lo], cx
    sbb word [cs:.left_hi], 0

    mov ds, [cs:.srcseg]
    mov es, [cs:.dstseg]
    xor si, si
    xor di, di
    cld
    rep movsb

    add word [cs:.srcseg], 0x0800
    add word [cs:.dstseg], 0x0800
    jmp .copy_pass
.copy_done:
    pop di
    pop si
    pop ds

    mov ax, [cs:.oldseg]
    call dosmem_free
    mov ax, [cs:.newseg]
    mov [si + DF_SEG], ax

.in_place:
    mov ax, [cs:.want]
    mov [si + DF_PARAS], ax

.ok:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

.fail:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

.need       dw 0
.want       dw 0
.oldseg     dw 0
.newseg     dw 0
.srcseg     dw 0
.dstseg     dw 0
.left_lo    dw 0
.left_hi    dw 0

; ==================================================================
; dosfile_sector_of - which sector of a file a byte offset falls in.
; IN : DX:AX = byte offset
; OUT: AX = sector index
; ==================================================================
dosfile_sector_of:
    push bx
    push cx
    mov bx, dx
    mov cl, 9
    shr ax, cl
    mov cl, 7
    shl bx, cl
    or ax, bx
    pop cx
    pop bx
    ret

dosfile_cluster_at:
    push bx
    push cx

    mov cx, ax
    mov ax, [si + DF_CCLUS]
    mov bx, [si + DF_CIDX]
    test ax, ax
    jz .from_start
    cmp cx, bx
    jae .walk
.from_start:
    mov ax, [si + DF_FIRST]
    xor bx, bx

.walk:
    test ax, ax
    jz .bad
    cmp bx, cx
    je .found
    call fs_fat_next_cluster
    jc .bad
    inc bx
    jmp .walk

.found:
    mov [si + DF_CCLUS], ax
    mov [si + DF_CIDX], bx
    pop cx
    pop bx
    clc
    ret

.bad:
    pop cx
    pop bx
    stc
    ret

; ==================================================================
; dosfile_read_stream - read from a file that is not held in RAM.
;
; IN : SI = slot, CX = bytes wanted, ES:DI = destination,
;      DS = KERNEL_DATA_SEG
; OUT: AX = bytes actually read, ES:DI left past the last byte
; ==================================================================
dosfile_read_stream:
    mov [cs:.want], cx
    mov word [cs:.done], 0

    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    sub ax, [si + DF_POS]
    sbb dx, [si + DF_POS + 2]
    jb .finish
    test dx, dx
    jnz .clamped
    cmp ax, cx
    jae .clamped
    mov [cs:.want], ax
.clamped:
    cmp word [cs:.want], 0
    je .finish

    cmp word [si + DF_CCLUS], 0
    je .need_fat
    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    call dosfile_sector_of
    xor dx, dx
    div word [fs_spc]
    cmp ax, [si + DF_CIDX]
    jne .need_fat
    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    add ax, [cs:.want]
    adc dx, 0
    sub ax, 1
    sbb dx, 0
    call dosfile_sector_of
    xor dx, dx
    div word [fs_spc]
    cmp ax, [si + DF_CIDX]
    je .next

.need_fat:
    push es
    call fs_read_fat
    pop es
    jc .finish

.next:
    mov cx, [cs:.want]
    sub cx, [cs:.done]
    jz .finish

    mov ax, [si + DF_POS]
    mov dx, [si + DF_POS + 2]
    mov bx, ax
    and bx, 0x01FF
    mov [cs:.secoff], bx
    call dosfile_sector_of
    xor dx, dx
    div word [fs_spc]
    mov [cs:.secinclus], dx

    call dosfile_cluster_at
    jc .finish

    push cx
    call fs_cluster_lba
    add ax, [cs:.secinclus]
    call fs_convert_l2hts
    push es
    push ds
    pop es
    mov bx, DOSF_SECTOR
    mov byte [cs:.retries], 5
    pusha

.attempt:
    popa
    pusha
    mov ah, 0x02
    mov al, 0x01
    stc
    int 0x13
    jnc .sector_ok
    dec byte [cs:.retries]
    jz .sector_fail
    call fs_reset_floppy
    jmp .attempt

.sector_fail:
    popa
    pop es
    pop cx
    jmp .finish

.sector_ok:
    popa
    pop es
    pop cx

    mov ax, 512
    sub ax, [cs:.secoff]
    cmp ax, cx
    jbe .have_chunk
    mov ax, cx
.have_chunk:
    mov [cs:.chunk], ax

    mov ax, di
    mov cl, 4
    shr ax, cl
    and di, 0x000F
    mov bx, es
    add bx, ax
    mov es, bx

    push si
    mov cx, [cs:.chunk]
    mov si, DOSF_SECTOR
    add si, [cs:.secoff]
    cld
    rep movsb
    pop si

    mov cx, [cs:.chunk]
    add [si + DF_POS], cx
    adc word [si + DF_POS + 2], 0
    add [cs:.done], cx
    jmp .next

.finish:
    mov ax, [cs:.done]
    ret

.want       dw 0
.done       dw 0
.chunk      dw 0
.secoff     dw 0
.secinclus  dw 0
.retries    db 0

; ==================================================================
; dosfile_materialise - move a streamed file into a RAM buffer.
;
; IN : SI = slot
;      DS = KERNEL_DATA_SEG
; OUT: CF = 1 if there is no room for the buffer
; ==================================================================
dosfile_materialise:
    test byte [si + DF_FLAGS], DFF_BUF
    jnz .already

    pusha
    push es

    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    call dosfile_paras_for
    jc .fail
    mov bx, ax
    cmp bx, DOSF_NEWPARAS
    jae .alloc
    mov bx, DOSF_NEWPARAS
.alloc:
    call dosmem_alloc
    jnc .got

    mov ax, [si + DF_SIZE]
    mov dx, [si + DF_SIZE + 2]
    call dosfile_paras_for
    jc .fail
    mov bx, ax
    call dosmem_alloc
    jnc .got

    cmp byte [dosf_spare_taken], 0
    jne .fail
    cmp word [si + DF_SIZE + 2], 0
    jne .fail
    cmp word [si + DF_SIZE], DOSF_SPARE_PARAS * 16
    ja .fail
    mov byte [dosf_spare_taken], 1
    mov ax, DOSF_SPARE_SEG
    mov bx, DOSF_SPARE_PARAS

.got:
    mov [si + DF_SEG], ax
    mov [si + DF_PARAS], bx

    mov ax, [si + DF_SIZE]
    or ax, [si + DF_SIZE + 2]
    jz .filled

    push si
    push es
    push ds
    pop es
    mov di, com_path_buffer
    mov cx, 13
    cld
    rep movsb
    pop es
    pop si

    mov ax, com_path_buffer
    xor cx, cx
    mov dx, [si + DF_SEG]
    call fs_load_huge_file

.filled:
    or byte [si + DF_FLAGS], DFF_BUF

    pop es
    popa
    clc
    ret

.fail:
    pop es
    popa
    stc
    ret

.already:
    clc
    ret


; ==================================================================
; dosfile_open - shared body of AH=3Dh and AH=3Ch.
; IN : caller DS:DX = ASCIIZ path
;      AL = 0 to open, 1 to create
; OUT: CF = 0, AX = handle
;      CF = 1, AX = DOS error code
; ==================================================================
dosfile_open:
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov [cs:.creating], al

    call com_copy_path_from_caller

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    call dosfile_free_slot
    jc .too_many
    mov [.slot], si
    mov [.handle], bx

    cmp byte [cs:.creating], 0
    jne .make_new

    mov ax, com_path_buffer
    call fs_get_file_size
    jc .not_found

    mov [.size_lo], bx
    mov [.size_hi], dx
    mov [.first], cx

    xor ax, ax
    mov [.buf_seg], ax
    mov [.buf_paras], ax
    mov byte [.newflags], DFF_USED
    jmp .finish

.make_new:
    xor ax, ax
    mov [.buf_seg], ax
    mov [.buf_paras], ax
    mov [.size_lo], ax
    mov [.size_hi], ax
    mov [.first], ax
    mov byte [.newflags], DFF_USED | DFF_DIRTY

.finish:
    mov si, [.slot]
    call dosfile_store_name

    mov ax, [.buf_seg]
    mov [si + DF_SEG], ax
    mov ax, [.buf_paras]
    mov [si + DF_PARAS], ax
    mov ax, [.size_lo]
    mov [si + DF_SIZE], ax
    mov ax, [.size_hi]
    mov [si + DF_SIZE + 2], ax
    mov word [si + DF_POS], 0
    mov word [si + DF_POS + 2], 0
    mov ax, [.first]
    mov [si + DF_FIRST], ax
    mov word [si + DF_CCLUS], 0
    mov word [si + DF_CIDX], 0

    mov al, [.newflags]
    mov [si + DF_FLAGS], al

    call dosfile_materialise

    mov ax, [.handle]
    jmp .ok

.too_many:
    mov ax, 0x0004                  ; too many open files
    jmp .err
.not_found:
    mov ax, 0x0002                  ; file not found
    jmp .err
.no_memory:
    mov ax, 0x0008                  ; insufficient memory

.err:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    stc
    ret

.ok:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret

.creating   db 0
.newflags   db 0
.slot       dw 0
.handle     dw 0
.size_lo    dw 0
.size_hi    dw 0
.first      dw 0
.buf_seg    dw 0
.buf_paras  dw 0

; ==================================================================
; dosfile_close_slot - flush a dirty buffer back to disk and release it.
; IN : SI = slot
;      DS = KERNEL_DATA_SEG
; OUT: CF = 1 if the file could not be written back
; ==================================================================
dosfile_close_slot:
    mov byte [cs:dosf_flush_failed], 0
    pusha
    push es

    mov ax, KERNEL_DATA_SEG
    mov es, ax

    test byte [si + DF_FLAGS], DFF_DIRTY
    jz .no_flush

    push si
    mov di, com_path_buffer
    mov cx, 13
    cld
    rep movsb
    pop si

    mov ax, com_path_buffer
    xor cx, cx
    mov dx, [si + DF_SEG]
    mov di, [si + DF_SIZE + 2]
    mov bx, [si + DF_SIZE]
    call fs_write_huge_file
    jnc .no_flush
    mov byte [cs:dosf_flush_failed], 1

.no_flush:
    mov ax, [si + DF_SEG]
    test ax, ax
    jz .no_buffer
    cmp ax, DOSF_SPARE_SEG
    jne .arena_block
    mov byte [dosf_spare_taken], 0
    jmp .no_buffer
.arena_block:
    call dosmem_free

.no_buffer:
    mov byte [si + DF_FLAGS], 0
    mov word [si + DF_SEG], 0
    mov word [si + DF_PARAS], 0

    pop es
    popa

    cmp byte [cs:dosf_flush_failed], 0
    jne .write_error
    clc
    ret

.write_error:
    stc
    ret

; ==================================================================
; dosfile_close_all - flush and release every handle a program left open.
; ==================================================================
dosfile_close_all:
    pusha
    push ds

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    mov si, dosfile_table
    mov cx, DOSF_SLOTS
.scan:
    test byte [si + DF_FLAGS], DFF_USED
    jz .next
    call dosfile_close_slot
.next:
    add si, DF_ENT
    loop .scan

    pop ds
    popa
    ret

; ==================================================================
; dosfile_capacity - buffer size in bytes for a slot.
; IN : SI = slot
;      DS = KERNEL_DATA_SEG
; OUT: DX:AX = capacity
; ==================================================================
dosfile_capacity:
    push cx
    mov ax, [si + DF_PARAS]
    mov dx, ax
    mov cl, 12
    shr dx, cl
    mov cl, 4
    shl ax, cl
    pop cx
    ret

section .data

dosfile_table   times DOSF_SLOTS * DF_ENT db 0
dosf_caller_ds  dw 0
dosf_caller_dx  dw 0
dosf_count      dw 0
dosf_seek_origin db 0
dosf_seek_lo    dw 0
dosf_seek_hi    dw 0
dosf_flush_failed db 0
dosf_access     db 0
dosf_spare_taken db 0

section .text
