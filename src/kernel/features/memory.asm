; ==================================================================
; x16-PRos - Kernel memory allocator
; Copyright (C) 2026 PRoX2011
; ==================================================================

HEAP_BASE_SEG        equ 0x3000
HEAP_END_SEG         equ 0xA000
HEAP_TOTAL_PARAS     equ HEAP_END_SEG - HEAP_BASE_SEG

MEM_SLOT_COUNT       equ 32
MEM_SLOT_SIZE        equ 5

MEM_OFF_START        equ 0
MEM_OFF_PARAS        equ 2
MEM_OFF_USED         equ 4

; ==================================================================
; mem_init - reset the descriptor table to one free arena block.
; ==================================================================
mem_init:
    pusha
    push es

    push cs
    pop es
    mov di, mem_table
    mov cx, MEM_SLOT_COUNT * MEM_SLOT_SIZE
    xor al, al
    cld
    rep stosb

    mov word [mem_table + MEM_OFF_START], HEAP_BASE_SEG
    mov word [mem_table + MEM_OFF_PARAS], HEAP_TOTAL_PARAS
    mov byte [mem_table + MEM_OFF_USED],  0

    pop es
    popa
    ret

; ==================================================================
; mem_alloc - first-fit allocation.
; IN : BX = paragraphs (16-byte units)
; OUT: AX = segment
;      AX = 0
;      CF = 0 on success
;      CF = 1 on failure
; ==================================================================
mem_alloc:
    push bx
    push cx
    push si
    push di
    push bp

    test bx, bx
    jz  .fail

    mov si, mem_table
    mov bp, MEM_SLOT_COUNT
.scan:
    mov al, [si + MEM_OFF_USED]
    test al, al
    jnz .next
    mov ax, [si + MEM_OFF_PARAS]
    test ax, ax
    jz .next
    cmp ax, bx
    jae .found
.next:
    add si, MEM_SLOT_SIZE
    dec bp
    jnz .scan
    jmp .fail

.found:
    cmp ax, bx
    je .take_whole

    mov di, mem_table
    mov cx, MEM_SLOT_COUNT
.find_empty:
    mov dx, [di + MEM_OFF_PARAS]
    test dx, dx
    jz .empty_ok
    add di, MEM_SLOT_SIZE
    loop .find_empty
    jmp .take_whole

.empty_ok:
    sub ax, bx
    mov [di + MEM_OFF_PARAS], ax
    mov ax, [si + MEM_OFF_START]
    add ax, bx
    mov [di + MEM_OFF_START], ax
    mov byte [di + MEM_OFF_USED], 0
    mov [si + MEM_OFF_PARAS], bx

.take_whole:
    mov byte [si + MEM_OFF_USED], 1
    mov ax, [si + MEM_OFF_START]
    pop bp
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

.fail:
    xor ax, ax
    pop bp
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

; ==================================================================
; mem_free - mark a block free and coalesce with neighbours.
; IN : AX = segment returned by mem_alloc
; OUT: CF = 0 on success, CF = 1 if segment unknown
; ==================================================================
mem_free:
    push bx
    push cx
    push si

    mov si, mem_table
    mov cx, MEM_SLOT_COUNT
.find:
    cmp [si + MEM_OFF_START], ax
    jne .next
    cmp byte [si + MEM_OFF_USED], 0
    je .next
    cmp word [si + MEM_OFF_PARAS], 0
    je .next

    mov byte [si + MEM_OFF_USED], 0
    call mem_coalesce_at_si

    pop si
    pop cx
    pop bx
    clc
    ret
.next:
    add si, MEM_SLOT_SIZE
    loop .find

    pop si
    pop cx
    pop bx
    stc
    ret

; ==================================================================
; mem_coalesce_at_si - merge SI's free block with adjacent free blocks.
; Restarts after each merge so the result is a single coalesced block.
; ==================================================================
mem_coalesce_at_si:
    pusha
.restart:
    mov ax, [si + MEM_OFF_START]
    mov bx, [si + MEM_OFF_PARAS]
    add bx, ax

    mov di, mem_table
    mov cx, MEM_SLOT_COUNT
.scan:
    cmp di, si
    je .scan_next
    mov dl, [di + MEM_OFF_USED]
    test dl, dl
    jnz .scan_next
    mov dx, [di + MEM_OFF_PARAS]
    test dx, dx
    jz .scan_next

    cmp [di + MEM_OFF_START], bx
    je .merge_right

    push ax
    mov bp, [di + MEM_OFF_START]
    add bp, dx
    cmp bp, ax
    pop ax
    je .merge_left

.scan_next:
    add di, MEM_SLOT_SIZE
    loop .scan
    jmp .done

.merge_right:
    add [si + MEM_OFF_PARAS], dx
    mov word [di + MEM_OFF_PARAS], 0
    mov word [di + MEM_OFF_START], 0
    jmp .restart

.merge_left:
    mov dx, [si + MEM_OFF_PARAS]
    add [di + MEM_OFF_PARAS], dx
    mov word [si + MEM_OFF_PARAS], 0
    mov word [si + MEM_OFF_START], 0
    mov si, di
    jmp .restart

.done:
    popa
    ret

; ==================================================================
; mem_get_free - sum of free bytes across all blocks.
; OUT: DX:AX = total free bytes
; ==================================================================
mem_get_free:
    push bx
    push cx
    push si
    push di
    push bp

    xor ax, ax
    xor dx, dx
    mov si, mem_table
    mov cx, MEM_SLOT_COUNT
.scan:
    mov bl, [si + MEM_OFF_USED]
    test bl, bl
    jnz .next
    mov bx, [si + MEM_OFF_PARAS]
    test bx, bx
    jz .next

    mov di, bx
    mov bp, bx
    shr di, 12
    shl bp, 4
    add ax, bp
    adc dx, di
.next:
    add si, MEM_SLOT_SIZE
    loop .scan

    pop bp
    pop di
    pop si
    pop cx
    pop bx
    ret


section .data

mem_table times MEM_SLOT_COUNT * MEM_SLOT_SIZE db 0