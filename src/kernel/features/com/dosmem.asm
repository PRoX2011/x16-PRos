; ==================================================================
; x16-PRos - DOS memory arena for the compatibility layer
; ==================================================================

DOSMEM_BASE      equ 0x3000
DOSMEM_TOP       equ 0xA000
DOSMEM_ENV_SEG   equ DOSMEM_BASE
DOSMEM_ENV_PARAS equ 0x0040

DOSMEM_SLOTS     equ 24
DOSMEM_ENT       equ 7
DM_START         equ 0
DM_PARAS         equ 2
DM_USED          equ 4
DM_OWNER         equ 5

dosmem_probe_top:
    push ax
    push cx

    mov word [dosmem_top_seg], DOSMEM_TOP

    int 0x12
    test ax, ax
    jz .done

    mov cl, 6
    shl ax, cl
    jc .done

    cmp ax, DOSMEM_TOP
    ja .done
    cmp ax, EXE_PSP_SEG
    jbe .done

    mov [dosmem_top_seg], ax

.done:
    pop cx
    pop ax
    ret

dosmem_init:
    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    mov di, dosmem_table
    mov cx, DOSMEM_SLOTS * DOSMEM_ENT
    xor al, al
    cld
    rep stosb

    ; --- slot 0: the environment block ---
    mov ax, [dosmem_env_seg]
    mov [dosmem_table + DM_START], ax
    mov word [dosmem_table + DM_PARAS], DOSMEM_ENV_PARAS
    mov byte [dosmem_table + DM_USED], 1
    add ax, DOSMEM_ENV_PARAS
    mov dx, ax

    ; --- slot 1: the program's own block ---
    mov ax, [dosmem_prog_base]
    mov [dosmem_table + DOSMEM_ENT + DM_START], ax
    mov bx, [dosmem_top_seg]
    sub bx, ax
    mov cx, [dosmem_prog_paras]
    test cx, cx
    jz .prog_all
    cmp cx, bx
    jae .prog_all
    mov bx, cx
.prog_all:
    mov [dosmem_table + DOSMEM_ENT + DM_PARAS], bx
    mov byte [dosmem_table + DOSMEM_ENT + DM_USED], 1
    add ax, bx

    ; --- slot 2: whatever is left is free ---
    cmp ax, dx
    jae .free_start
    mov ax, dx
.free_start:
    mov bx, [dosmem_top_seg]
    cmp ax, bx
    jae .slots_ready
    sub bx, ax
    mov [dosmem_table + 2 * DOSMEM_ENT + DM_START], ax
    mov [dosmem_table + 2 * DOSMEM_ENT + DM_PARAS], bx
    mov byte [dosmem_table + 2 * DOSMEM_ENT + DM_USED], 0

.slots_ready:
    mov word [dosmem_prog_paras], 0
    mov word [dosmem_prog_base], EXE_PSP_SEG
    mov word [dosmem_env_seg], DOSMEM_ENV_SEG

    pop es
    pop ds
    popa
    ret

; ==================================================================
; dosmem_find - locate the used block starting at AX.
; IN : AX = segment
;      DS = KERNEL_DATA_SEG
; OUT: SI = slot
;      CF = 1 if not found
; ==================================================================
dosmem_find:
    push cx
    mov si, dosmem_table
    mov cx, DOSMEM_SLOTS
.scan:
    cmp byte [si + DM_USED], 0
    je .next
    cmp [si + DM_START], ax
    je .hit
.next:
    add si, DOSMEM_ENT
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ==================================================================
; dosmem_empty_slot - find an unused, zero-sized table entry.
; IN : DS = KERNEL_DATA_SEG
; OUT: DI = slot
;      CF = 1 if the table is full
; ==================================================================
dosmem_empty_slot:
    push cx
    mov di, dosmem_table
    mov cx, DOSMEM_SLOTS
.scan:
    cmp word [di + DM_PARAS], 0
    je .hit
    add di, DOSMEM_ENT
    loop .scan
    pop cx
    stc
    ret
.hit:
    pop cx
    clc
    ret

; ==================================================================
; dosmem_coalesce - merge every pair of adjacent free blocks.
; IN : DS = KERNEL_DATA_SEG
; ==================================================================
dosmem_coalesce:
    pusha
.restart:
    mov si, dosmem_table
    mov cx, DOSMEM_SLOTS
.outer:
    cmp byte [si + DM_USED], 0
    jne .outer_next
    mov bx, [si + DM_PARAS]
    test bx, bx
    jz .outer_next

    add bx, [si + DM_START]

    mov di, dosmem_table
    mov dx, DOSMEM_SLOTS
.inner:
    cmp di, si
    je .inner_next
    cmp byte [di + DM_USED], 0
    jne .inner_next
    cmp word [di + DM_PARAS], 0
    je .inner_next
    cmp [di + DM_START], bx
    je .merge
.inner_next:
    add di, DOSMEM_ENT
    dec dx
    jnz .inner

.outer_next:
    add si, DOSMEM_ENT
    loop .outer
    popa
    ret

.merge:
    mov ax, [di + DM_PARAS]
    add [si + DM_PARAS], ax
    mov word [di + DM_PARAS], 0
    mov word [di + DM_START], 0
    jmp .restart

; ==================================================================
; dosmem_alloc - first-fit allocation out of the DOS arena.
; IN : BX = paragraphs wanted
; OUT: CF = 0, AX = segment
;      CF = 1, BX = largest free block available
; ==================================================================
dosmem_alloc:
    push cx
    push dx
    push si
    push di
    push ds

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    test bx, bx
    jz .zero_req

    xor dx, dx
    mov si, dosmem_table
    mov cx, DOSMEM_SLOTS
.scan:
    cmp byte [si + DM_USED], 0
    jne .next
    mov ax, [si + DM_PARAS]
    test ax, ax
    jz .next
    cmp ax, dx
    jbe .no_bigger
    mov dx, ax
.no_bigger:
    cmp ax, bx
    jae .found
.next:
    add si, DOSMEM_ENT
    loop .scan

    mov bx, dx
    jmp .fail

.found:
    cmp ax, bx
    je .take_whole

    call dosmem_empty_slot
    jc .take_whole

    sub ax, bx
    mov [di + DM_PARAS], ax
    mov ax, [si + DM_START]
    add ax, bx
    mov [di + DM_START], ax
    mov byte [di + DM_USED], 0
    mov [si + DM_PARAS], bx

.take_whole:
    mov byte [si + DM_USED], 1
    push ax
    mov ax, [cs:dos_current_psp]
    mov [si + DM_OWNER], ax
    pop ax
    mov ax, [si + DM_START]
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    clc
    ret

.zero_req:
    xor bx, bx
.fail:
    xor ax, ax
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    stc
    ret

; ==================================================================
; dosmem_free - release a block allocated by dosmem_alloc.
; IN : AX = segment
; OUT: CF = 1 if the segment is not an allocated block
; ==================================================================
dosmem_free:
    push si
    push ds

    push ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    pop ax

    call dosmem_find
    jc .bad

    mov byte [si + DM_USED], 0
    call dosmem_coalesce

    pop ds
    pop si
    clc
    ret

.bad:
    pop ds
    pop si
    stc
    ret

; ==================================================================
; dosmem_resize - grow or shrink an allocated block in place.
; IN : AX = segment, BX = new size in paragraphs
; OUT: CF = 0 on success
;      CF = 1, BX = largest size this block can reach
; ==================================================================
dosmem_resize:
    push cx
    push dx
    push si
    push di
    push ds

    push ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    pop ax

    call dosmem_find
    jc .bad_block

    mov dx, [si + DM_PARAS]
    cmp bx, dx
    je .ok
    ja .grow

    call dosmem_empty_slot
    jc .ok

    mov ax, dx
    sub ax, bx
    mov [di + DM_PARAS], ax
    mov ax, [si + DM_START]
    add ax, bx
    mov [di + DM_START], ax
    mov byte [di + DM_USED], 0
    mov [si + DM_PARAS], bx
    call dosmem_coalesce
    jmp .ok

.grow:
    mov cx, [si + DM_START]
    add cx, dx

    push si
    mov si, dosmem_table
    mov ax, DOSMEM_SLOTS
.gscan:
    cmp byte [si + DM_USED], 0
    jne .gnext
    cmp word [si + DM_PARAS], 0
    je .gnext
    cmp [si + DM_START], cx
    je .gfound
.gnext:
    add si, DOSMEM_ENT
    dec ax
    jnz .gscan
    pop si
    mov bx, dx
    jmp .too_big

.gfound:
    mov ax, [si + DM_PARAS]
    add ax, dx
    cmp bx, ax
    ja .gtoo_big

    push ax
    mov ax, bx
    sub ax, dx
    add [si + DM_START], ax
    sub [si + DM_PARAS], ax
    pop ax
    pop si
    mov [si + DM_PARAS], bx
    jmp .ok

.gtoo_big:
    pop si
    mov bx, ax
    jmp .too_big

.ok:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    clc
    ret

.bad_block:
    xor bx, bx
.too_big:
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    stc
    ret

; ==================================================================
; DOSMEM_FREE_OWNER - release every block a process still holds
;
; IN : AX = the PSP whose memory should go
; ==================================================================
dosmem_free_owner:
    pusha
    push ds

    mov bx, ax
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    mov si, dosmem_table
    mov cx, DOSMEM_SLOTS
.scan:
    cmp byte [si + DM_USED], 0
    je .next
    cmp [si + DM_OWNER], bx
    jne .next
    mov byte [si + DM_USED], 0
    mov word [si + DM_OWNER], 0
.next:
    add si, DOSMEM_ENT
    loop .scan

    call dosmem_coalesce

    pop ds
    popa
    ret


section .data

dosmem_table times DOSMEM_SLOTS * DOSMEM_ENT db 0
dosmem_top_seg dw DOSMEM_TOP
dosmem_prog_paras dw 0
dosmem_prog_base dw EXE_PSP_SEG
dosmem_env_seg   dw DOSMEM_ENV_SEG