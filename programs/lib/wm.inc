; ========================================================================
; wm.inc - rendezvous block shared by the window manager and its clients
; Copyright (C) 2026 PRoX2011
; ========================================================================

%ifndef WM_INC
%define WM_INC

WM_VEC          equ 0x60
WM_MAGIC        equ 0x4D57
WM_VERSION      equ 1

WM_OFF_MAGIC    equ 0x00
WM_OFF_VERSION  equ 0x02
WM_OFF_OWNER    equ 0x03
WM_OFF_SLOTS    equ 0x04
WM_OFF_OWNSEG   equ 0x06
WM_OFF_ENTRIES  equ 0x08

WM_OWNER_NONE   equ 0xFF
WM_ENTRY_SHIFT  equ 6
WM_ENTRY_SIZE   equ (1 << WM_ENTRY_SHIFT)
WM_E_FLAGS      equ 0x00
WM_E_CLIPN      equ 0x01
WM_E_X          equ 0x02
WM_E_Y          equ 0x04
WM_E_W          equ 0x06
WM_E_H          equ 0x08
WM_E_CLIP       equ 0x0A

WM_CLIP_MAX     equ 6
WM_TASK_MAX     equ 8
WM_BLOCK_SIZE   equ (WM_OFF_ENTRIES + WM_TASK_MAX * WM_ENTRY_SIZE)

WM_F_WINDOWED   equ 0x01
WM_F_CLOSE      equ 0x02
WM_F_DIRTY      equ 0x04

; ========================================================================
; wm_entry - offset of a task's entry inside the block
; IN:  BL = task id
; OUT: AX = offset of the entry
; ========================================================================
wm_entry:
    xor ah, ah
    mov al, bl
    shl ax, WM_ENTRY_SHIFT
    add ax, WM_OFF_ENTRIES
    ret

; ========================================================================
; wm_probe - find the block whoever it belongs to
; IN:  nothing
; OUT: ES = block segment
;      CF = 1 when there is no readable block
; ========================================================================
wm_probe:
    push ax
    xor ax, ax
    mov es, ax
    mov ax, [es:WM_VEC * 4 + 2]
    test ax, ax
    jz .none
    mov es, ax
    cmp word [es:WM_OFF_MAGIC], WM_MAGIC
    jne .none
    cmp byte [es:WM_OFF_VERSION], WM_VERSION
    jne .none
    pop ax
    clc
    ret
.none:
    xor ax, ax
    mov es, ax
    pop ax
    stc
    ret

; ========================================================================
; wm_locate - find the block of a manager that is actually running
; IN:  nothing
; OUT: ES = block segment
;      CF = 1 when no manager is live
; ========================================================================
wm_locate:
    push ax
    push bx
    push cx
    push dx
    call wm_probe
    jc .none
    mov bl, [es:WM_OFF_OWNER]
    cmp bl, WM_OWNER_NONE
    je .none
    push es
    mov ah, 0x17
    int 0x23
    pop es
    jc .none
    test al, al
    jz .none
    cmp cx, [es:WM_OFF_OWNSEG]
    jne .none
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.none:
    xor ax, ax
    mov es, ax
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

%endif
