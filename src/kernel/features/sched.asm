; ==================================================================
; x16-PRos - Cooperative task scheduler
; Copyright (C) 2026 PRoX2011
; ==================================================================

TASK_SLOT_COUNT      equ 8
TASK_SLOT_SIZE       equ 16
TASK_NAME_LEN        equ 16

TASK_STATE           equ 0       ; byte
TASK_FLAGS           equ 1       ; byte
TASK_BASE_SEG        equ 2       ; word (0xFFFF for kernel slot)
TASK_PARAS           equ 4       ; word (paragraphs allocated)
TASK_SS              equ 6       ; word (saved stack segment)
TASK_SP              equ 8       ; word (saved stack pointer)
TASK_WAKE_LO         equ 10      ; word (BIOS tick low)
TASK_WAKE_HI         equ 12      ; word (BIOS tick high)
TASK_PARENT          equ 14      ; byte (slot id blocked on this task, or 0xFF)

TASK_S_FREE          equ 0
TASK_S_READY         equ 1
TASK_S_RUNNING       equ 2
TASK_S_SLEEPING      equ 3
TASK_S_WAITING       equ 4       ; blocked until a foreground child exits

TASK_F_BACKGROUND    equ 0x01
TASK_F_KERNEL        equ 0x80

; ==================================================================
; sched_init - reset task table, mark slot 0 (kernel) as running.
; ==================================================================
sched_init:
    pusha
    push es

    push cs
    pop es
    mov di, sched_tasks
    mov cx, TASK_SLOT_COUNT * TASK_SLOT_SIZE
    xor al, al
    cld
    rep stosb

    mov byte [sched_tasks + TASK_STATE], TASK_S_RUNNING
    mov byte [sched_tasks + TASK_FLAGS], TASK_F_KERNEL
    mov ax, cs
    mov [sched_tasks + TASK_BASE_SEG], ax
    mov byte [sched_tasks + TASK_PARENT], 0xFF
    mov byte [sched_cur_task], 0

    mov di, sched_task_names
    mov cx, TASK_SLOT_COUNT * TASK_NAME_LEN
    xor al, al
    rep stosb

    ; slot 0 = "KERNEL"
    mov word [sched_task_names + 0], 'KE'
    mov word [sched_task_names + 2], 'RN'
    mov word [sched_task_names + 4], 'EL'
    mov byte [sched_task_names + 6], 0

    pop es
    popa
    ret

; ==================================================================
; sched_task_create_from_ple - allocate a task slot
; IN : AL = task flags (TASK_F_BACKGROUND or 0)
; OUT: AL = task id
;      CF = 0 on success
;      CF = 1 if no slot is available
; ==================================================================
sched_task_create_from_ple:
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov [.flags_tmp], al

    ; ----- find a free slot -----
    mov bx, sched_tasks + TASK_SLOT_SIZE
    mov cx, TASK_SLOT_COUNT - 1
.scan:
    cmp byte [bx + TASK_STATE], TASK_S_FREE
    je  .found
    add bx, TASK_SLOT_SIZE
    loop .scan
    jmp .no_slot

.found:
    ; ----- compute task id -----
    mov ax, bx
    sub ax, sched_tasks
    mov cl, 4
    shr ax, cl
    mov [.id_tmp], al

    ; ----- fill slot metadata -----
    mov al, [.flags_tmp]
    mov [bx + TASK_FLAGS], al
    mov ax, [ple_base_seg]
    mov [bx + TASK_BASE_SEG], ax
    mov word [bx + TASK_PARAS], PLE_MAX_PARAS
    mov byte [bx + TASK_PARENT], 0xFF             ; no parent by default

    push bx
    xor bh, bh
    mov bl, [.id_tmp]
    mov byte [task_win_flags + bx], 0
    pop bx

    ; ----- build initial stack frame in task's stack segment -----
    ; Layout (from epilogue's perspective, low -> high addresses):
    ;   SP+0   ES     (popped first)
    ;   SP+2   DS
    ;   SP+4   DI     (popa: DI first)
    ;   SP+6   SI
    ;   SP+8   BP
    ;   SP+10  SP-phantom
    ;   SP+12  BX
    ;   SP+14  DX
    ;   SP+16  CX
    ;   SP+18  AX
    ;   SP+20  IP     (iret pops IP first)
    ;   SP+22  CS
    ;   SP+24  FLAGS
    ;   SP+26  retf IP (= ple_task_done)
    ;   SP+28  retf CS (= kernel CS)
    ;
    ; Frame is 30 bytes. After iret to (CS:IP, FLAGS), SP points to the
    ; far pointer so a 'retf' from the PLE program lands on ple_task_done.

    push bx
    mov ax, [ple_stack_ss]
    mov es, ax
    mov di, [ple_stack_sp]
    sub di, 30                            ; new SP for the saved frame

    mov ax, [ple_entry_cs]                ; DS/ES initial value for the task
    mov [es:di + 0],  ax                  ; ES
    mov [es:di + 2],  ax                  ; DS
    xor ax, ax
    mov [es:di + 4],  ax                  ; DI
    mov [es:di + 6],  ax                  ; SI
    mov [es:di + 8],  ax                  ; BP
    mov [es:di + 10], ax                  ; phantom SP
    mov [es:di + 12], ax                  ; BX
    mov [es:di + 14], ax                  ; DX
    mov [es:di + 16], ax                  ; CX
    mov [es:di + 18], ax                  ; AX
    mov ax, [ple_entry_ip]
    mov [es:di + 20], ax                  ; IP
    mov ax, [ple_entry_cs]
    mov [es:di + 22], ax                  ; CS
    mov word [es:di + 24], 0x0202         ; FLAGS (IF=1)
    mov word [es:di + 26], ple_task_done
    mov [es:di + 28], cs                  ; kernel CS for retf landing
    pop bx

    mov ax, [ple_stack_ss]
    mov [bx + TASK_SS], ax
    mov [bx + TASK_SP], di
    mov byte [bx + TASK_STATE], TASK_S_READY

    mov al, [.id_tmp]
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret

.no_slot:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    xor al, al
    stc
    ret

.flags_tmp db 0
.id_tmp    db 0

; ==================================================================
; sched_dispatch - foreground exec. Parks the current task in the
; waiting state and switches to the freshly created child task.
; ==================================================================
sched_dispatch:
    cli
    pushf
    push cs
    push word .resume_point
    pusha
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    xor bh, bh
    mov bl, [sched_cur_task]
    shl bx, 4
    mov [sched_tasks + bx + TASK_SS], ss
    mov [sched_tasks + bx + TASK_SP], sp
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_WAITING

    xor bh, bh
    mov bl, [sched_disp_child]
    mov [sched_cur_task], bl
    shl bx, 4
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_RUNNING
    mov ss, [sched_tasks + bx + TASK_SS]
    mov sp, [sched_tasks + bx + TASK_SP]

    pop es
    pop ds
    popa
    iret

.resume_point:
    ret

; ==================================================================
; sched_yield - save current SS:SP, pick next task, switch
; ==================================================================
sched_yield:
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    xor bh, bh
    mov bl, [sched_cur_task]
    shl bx, 4
    mov [sched_tasks + bx + TASK_SS], ss
    mov [sched_tasks + bx + TASK_SP], sp
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_READY

    call sched_pick_next
    mov [sched_cur_task], al
    xor bh, bh
    mov bl, al
    shl bx, 4
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_RUNNING

    cli
    mov ss, [sched_tasks + bx + TASK_SS]
    mov sp, [sched_tasks + bx + TASK_SP]
    sti

    pop es
    pop ds
    popa
    iret


sched_sleep:
    mov ax, KERNEL_DATA_SEG
    mov ds, ax

    mov bp, sp
    mov cx, [bp + 16]

    push es
    mov ax, 0x0040
    mov es, ax
    mov ax, [es:0x006C]
    mov dx, [es:0x006E]
    pop es

    add ax, cx
    adc dx, 0

    xor bh, bh
    mov bl, [sched_cur_task]
    shl bx, 4

    cmp bl, 0
    je .as_yield

    mov [sched_tasks + bx + TASK_WAKE_LO], ax
    mov [sched_tasks + bx + TASK_WAKE_HI], dx
    mov [sched_tasks + bx + TASK_SS], ss
    mov [sched_tasks + bx + TASK_SP], sp
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_SLEEPING
    jmp .switch

.as_yield:
    mov [sched_tasks + bx + TASK_SS], ss
    mov [sched_tasks + bx + TASK_SP], sp
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_READY

.switch:
    call sched_pick_next
    mov [sched_cur_task], al
    xor bh, bh
    mov bl, al
    shl bx, 4
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_RUNNING

    cli
    mov ss, [sched_tasks + bx + TASK_SS]
    mov sp, [sched_tasks + bx + TASK_SP]
    sti

    pop es
    pop ds
    popa
    iret

; ==================================================================
; sched_exit - frees current task's memory, marks slot
; free, switches to next task (or kernel when fallback).
; ENTRY ASSUMPTIONS:
;   DS = KERNEL_DATA_SEG (caller must set this before jmp).
;   The current SS:SP belongs to the task being torn down; it is
;   abandoned and the memory will be freed.
; ==================================================================
sched_exit:
    xor bh, bh
    mov bl, [sched_cur_task]
    shl bx, 4

    mov al, [sched_tasks + bx + TASK_PARENT]
    mov [.parent_tmp], al

    cmp bl, 0
    je .no_free  ; never free kernel slot

    mov ax, [sched_tasks + bx + TASK_BASE_SEG]
    push bx
    call mem_free
    pop bx

.no_free:
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_FREE
    mov word [sched_tasks + bx + TASK_BASE_SEG], 0
    mov byte [sched_tasks + bx + TASK_FLAGS], 0
    mov byte [sched_tasks + bx + TASK_PARENT], 0xFF
    mov al, [sched_cur_task]
    call sched_task_clear_name

    mov al, [.parent_tmp]
    cmp al, 0xFF
    je .no_parent
    xor bh, bh
    mov bl, al
    shl bx, 4
    cmp byte [sched_tasks + bx + TASK_STATE], TASK_S_WAITING
    jne .no_parent
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_READY
.no_parent:

    call sched_pick_next
    mov [sched_cur_task], al
    xor bh, bh
    mov bl, al
    shl bx, 4
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_RUNNING

    cli
    mov ss, [sched_tasks + bx + TASK_SS]
    mov sp, [sched_tasks + bx + TASK_SP]
    sti

    pop es
    pop ds
    popa
    iret

.parent_tmp db 0

; ==================================================================
; sched_pick_next - wake any due sleepers, then round-robin scan
; starting after sched_cur_task. Falls back to slot 0 (kernel).
; OUT: AL = chosen task id (0..TASK_SLOT_COUNT-1)
; ==================================================================
sched_pick_next:
    push bx
    push cx
    push dx
    push si

    call sched_wake_sleepers

    mov al, [sched_cur_task]
    mov cx, TASK_SLOT_COUNT
.scan:
    inc al
    cmp al, TASK_SLOT_COUNT
    jb .check
    xor al, al
.check:
    mov si, ax
    and si, 0x00FF
    mov bx, si
    shl bx, 4
    cmp byte [sched_tasks + bx + TASK_STATE], TASK_S_READY
    jne .skip
    ; Sanity check: slot must have a valid base segment. A stray READY
    ; state with TASK_BASE_SEG = 0 means the slot was clobbered or never
    ; properly initialised - skipping it avoids iret-to-garbage.
    cmp word [sched_tasks + bx + TASK_BASE_SEG], 0
    jne .found
.skip:
    loop .scan

    xor al, al
.found:
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ==================================================================
; sched_wake_sleepers - scan all slots; for any TASK_S_SLEEPING task
; whose wake tick is reached, change state to TASK_S_READY.
; Clobbers AX, BX, CX, DX, ES.
; ==================================================================
sched_wake_sleepers:
    push es
    push ax
    push bx
    push cx
    push dx
    push si

    mov ax, 0x0040
    mov es, ax
    mov ax, [es:0x006C]           ; current tick low
    mov dx, [es:0x006E]           ; current tick high

    mov bx, sched_tasks
    mov cx, TASK_SLOT_COUNT
.scan_sleep:
    cmp byte [bx + TASK_STATE], TASK_S_SLEEPING
    jne .next

    ; now_hi:now_lo >= wake_hi:wake_lo
    mov si, [bx + TASK_WAKE_HI]
    cmp dx, si
    ja .wake
    jb .next
    mov si, [bx + TASK_WAKE_LO]
    cmp ax, si
    jb .next
.wake:
    mov byte [bx + TASK_STATE], TASK_S_READY
.next:
    add bx, TASK_SLOT_SIZE
    loop .scan_sleep

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret

; ==================================================================
; sched_get_cur_id - returns AL = current task id.
; ==================================================================
sched_get_cur_id:
    mov al, [sched_cur_task]
    ret

; ==================================================================
; sched_task_set_name - copy NUL-terminated filename into a task's
; name slot. Truncates at TASK_NAME_LEN-1 chars.
; IN : AL = task id
;      SI = filename pointer (DS:SI)
; ==================================================================
sched_task_set_name:
    push ax
    push cx
    push si
    push di
    push es

    push cs
    pop es
    xor ah, ah
    mov cl, 4
    shl ax, cl
    mov di, sched_task_names
    add di, ax
    mov cx, TASK_NAME_LEN - 1
    cld
.tsn_copy:
    lodsb
    test al, al
    jz  .tsn_done
    stosb
    loop .tsn_copy
.tsn_done:
    xor al, al
    stosb

    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; ==================================================================
; sched_task_clear_name - blank a task's name slot.
; IN : AL = task id
; ==================================================================
sched_task_clear_name:
    push ax
    push cx
    push di
    push es

    push cs
    pop es
    xor ah, ah
    mov cl, 4
    shl ax, cl
    mov di, sched_task_names
    add di, ax
    mov cx, TASK_NAME_LEN
    xor al, al
    cld
    rep stosb

    pop es
    pop di
    pop cx
    pop ax
    ret

; ==================================================================
; sched_task_query - read one task slot.
; IN : BL = task id (0..TASK_SLOT_COUNT-1)
; OUT: AL = state
;      AH = flags
;      CX = base_seg (0xFFFF for kernel)
;      CF = 1 if id is out of range
; ==================================================================
sched_task_query:
    cmp bl, TASK_SLOT_COUNT
    jae .bad
    push bx
    xor bh, bh
    shl bx, 4
    mov al, [sched_tasks + bx + TASK_STATE]
    mov ah, [sched_tasks + bx + TASK_FLAGS]
    mov cx, [sched_tasks + bx + TASK_BASE_SEG]
    pop bx
    clc
    ret
.bad:
    stc
    ret

; ==================================================================
; sched_task_kill - terminate a task by id. Frees the task's arena
; and marks the slot free. Cannot kill the kernel slot (0), the
; calling task, or a slot that is already free.
; IN : BL = task id
; OUT: CF = 0 on success, CF = 1 on failure
; ==================================================================
sched_task_kill:
    cmp bl, TASK_SLOT_COUNT
    jae .kbad
    cmp bl, 0
    je .kbad
    cmp bl, [sched_cur_task]
    je .kbad
    push bx
    xor bh, bh
    shl bx, 4
    cmp byte [sched_tasks + bx + TASK_STATE], TASK_S_FREE
    je .kbad_pop
    mov ax, [sched_tasks + bx + TASK_BASE_SEG]
    cmp ax, 0xFFFF
    je .kbad_pop
    push bx
    call mem_free
    pop bx
    mov byte [sched_tasks + bx + TASK_STATE], TASK_S_FREE
    mov word [sched_tasks + bx + TASK_BASE_SEG], 0
    mov byte [sched_tasks + bx + TASK_FLAGS], 0
    mov ax, bx
    mov cl, 4
    shr ax, cl
    call sched_task_clear_name
    pop bx
    clc
    ret
.kbad_pop:
    pop bx
.kbad:
    stc
    ret

sched_yield_call:
    pushf
    push cs
    push word .resume
    pusha
    push ds
    push es
    jmp sched_yield
.resume:
    ret

section .data

sched_tasks       times TASK_SLOT_COUNT * TASK_SLOT_SIZE db 0
sched_task_names  times TASK_SLOT_COUNT * TASK_NAME_LEN  db 0
sched_cur_task                                           db 0
sched_disp_child                                         db 0