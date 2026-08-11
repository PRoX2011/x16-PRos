; ==================================================================
; x16-PRos - Kernel System API (Interrupt-Driven)
; Copyright (C) 2026 PRoX2011
;
; Provides memory, PLE launch, and mouse syscalls via INT 0x23.
; Function codes in AH:
;   0x00: Get version (returns AX = 0x0001)
;   0x01: Allocate memory (BX = bytes; returns AX = segment, CF on fail)
;   0x02: Free memory (AX = segment; CF on unknown segment)
;   0x03: Get free bytes (returns DX:AX = free bytes)
;   0x10: Execute PLE program foreground (SI = filename, CF on load failure)
;   0x11: Execute PLE program background (SI = filename; returns AX = task id, CF on load / no-slot failure)
;   0x12: Terminate current task (does not return)
;   0x13: Cooperative yield to next ready task
;   0x14: Sleep current task for CX BIOS ticks (~55 ms each)
;   0x15: Get current task id (returns AL = id)
;   0x16: Blocking key read with cooperative yield while idle
;         (returns AX = INT 16h/AH=0 result)
;   0x17: Query task slot (BL = id; OUT AL = state, AH = flags, CX = base_seg
;         (kernel's CS for slot 0); CF on bad id)
;         States: 0=free, 1=ready, 2=running, 3=sleeping
;         Flags : bit0=background, bit7=kernel
;   0x18: Kill task by id (BL = id; CF on failure -
;         cannot kill kernel slot, self, free slot, or bad id)
;   0x19: Copy task name into caller's buffer (BL = id, DI = dest offset
;         in caller's DS; buffer must be >= 16 bytes; result is
;         NUL-terminated; CF on bad id)
;   0x20: Mouse get state (returns AX=X, BX=Y, CL=buttons, CH=visible)
;   0x21: Mouse get text cell (returns AX=col, BX=row)
;   0x22: Mouse hide cursor
;   0x23: Mouse show cursor
;   0x24: Mouse enable (AL = 1 enable, 0 disable)
;   0x25: Mouse drag-select (AL = 1 enable, 0 disable)
;   0x26: Set cursor shape (AL = 0 arrow, 1 resize)
; ==================================================================

[BITS 16]

api_sys_init:
    pusha
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x23*4],     int23_handler
    mov word [es:0x23*4 + 2], cs
    sti
    pop es
    popa
    ret

int23_handler:
    pusha
    push ds
    push es

    mov [cs:caller_ds_save_23], ds

    mov bp, cs
    mov ds, bp
    mov es, bp
    cld

    cmp ah, 0x10
    je .exec_ple
    cmp ah, 0x11
    je .exec_ple_bg
    cmp ah, 0x12
    je .task_exit
    cmp ah, 0x13
    je .task_yield
    cmp ah, 0x14
    je .task_sleep
    cmp ah, 0x15
    je .task_get_id
    cmp ah, 0x16
    je .read_key_y
    cmp ah, 0x17
    je .task_query
    cmp ah, 0x18
    je .task_kill
    cmp ah, 0x19
    je .task_get_name

    cmp ah, 0x00
    je .get_version
    cmp ah, 0x01
    je .mem_alloc_sys
    cmp ah, 0x02
    je .mem_free_sys
    cmp ah, 0x03
    je .mem_get_free_sys
    cmp ah, 0x20
    je .mouse_get_state
    cmp ah, 0x21
    je .mouse_get_text
    cmp ah, 0x22
    je .mouse_hide
    cmp ah, 0x23
    je .mouse_show
    cmp ah, 0x24
    je .mouse_enable
    cmp ah, 0x25
    je .mouse_drag_select
    cmp ah, 0x26
    je .mouse_set_cursor
    cmp ah, 0x30
    je .win_set
    cmp ah, 0x31
    je .win_get
    cmp ah, 0x32
    je .win_close
    stc
    jmp .done

.get_version:
    mov bp, sp
    mov word [bp+18], 0x0001
    clc
    jmp .done

.mem_alloc_sys:
    test bx, bx
    jz  .mem_alloc_fail
    cmp bx, 0xFFF1
    jae .mem_alloc_fail
    add bx, 15
    mov cl, 4
    shr bx, cl
    test bx, bx
    jz .mem_alloc_fail
    call mem_alloc
    mov bp, sp
    mov [bp+18], ax
    jmp .done
.mem_alloc_fail:
    mov bp, sp
    mov word [bp+18], 0
    stc
    jmp .done

.mem_free_sys:
    call mem_free
    jmp .done

.mem_get_free_sys:
    call mem_get_free
    mov bp, sp
    mov [bp+18], ax
    mov [bp+14], dx
    clc
    jmp .done

.exec_ple:
    call copy_caller_string_si_23
    mov ax, si
    mov bl, 0x01
    call ple_execute
    jmp .done

.exec_ple_bg:
    call copy_caller_string_si_23
    mov ax, si
    call ple_execute_bg
    jc .exec_ple_bg_fail
    mov bp, sp
    xor ah, ah
    mov [bp+18], ax
    clc
    jmp .done
.exec_ple_bg_fail:
    mov bp, sp
    mov word [bp+18], 0
    stc
    jmp .done

.task_exit:
    jmp sched_exit

.task_yield:
    jmp sched_yield

.task_sleep:
    jmp sched_sleep

.task_get_id:
    call sched_get_cur_id
    xor ah, ah
    mov bp, sp
    mov [bp+18], ax
    clc
    jmp .done

.read_key_y:
.read_key_y_poll:
    mov ah, 0x01
    int 0x16
    jnz .read_key_y_got
    call sched_yield_call
    jmp .read_key_y_poll
.read_key_y_got:
    xor ah, ah
    int 0x16
    mov bp, sp
    mov [bp+18], ax
    clc
    jmp .done

.task_query:
    call sched_task_query
    jc .task_query_bad
    mov bp, sp
    mov [bp+18], ax
    mov [bp+16], cx
    clc
    jmp .done
.task_query_bad:
    mov bp, sp
    mov word [bp+18], 0
    mov word [bp+16], 0
    stc
    jmp .done

.task_kill:
    call sched_task_kill
    jmp .done

.task_get_name:
    cmp bl, TASK_SLOT_COUNT
    jae .task_get_name_bad

    mov bp, sp
    mov di, [bp + 4]
    mov ax, [caller_ds_save_23]
    mov es, ax

    xor bh, bh
    shl bx, 4
    mov si, sched_task_names
    add si, bx
    shr bx, 4

    mov cx, TASK_NAME_LEN - 1
    cld
.tgn_copy:
    lodsb
    test al, al
    jz .tgn_done
    stosb
    loop .tgn_copy
.tgn_done:
    xor al, al
    stosb
    clc
    jmp .done
.task_get_name_bad:
    stc
    jmp .done

.mouse_get_state:
    mov ax, [MouseX]
    mov bx, [MouseY]
    mov cl, [ButtonStatus]
    mov ch, [CursorVisible]
    mov bp, sp
    mov [bp+18], ax
    mov [bp+12], bx
    mov [bp+16], cx
    clc
    jmp .done

.mouse_get_text:
    mov ax, [MouseCol]
    mov bx, [MouseRow]
    mov bp, sp
    mov [bp+18], ax
    mov [bp+12], bx
    clc
    jmp .done

.mouse_hide:
    cmp byte [CursorVisible], 0
    je  .mouse_hide_ok
    call HideCursor
    mov byte [CursorVisible], 0
.mouse_hide_ok:
    clc
    jmp .done

.mouse_show:
    cmp byte [CursorVisible], 1
    je .mouse_show_ok
    mov byte [CursorVisible], 1
    call ShowCursor
.mouse_show_ok:
    clc
    jmp .done

.mouse_enable:
    test al, al
    jz .mouse_enable_off
    call EnableMouse
    jmp .mouse_enable_ok
.mouse_enable_off:
    call DisableMouse
.mouse_enable_ok:
    clc
    jmp .done

.mouse_drag_select:
    test al, al
    jz .mouse_drag_off
    mov byte [SelEnabled], 1
    jmp .mouse_drag_ok
.mouse_drag_off:
    mov byte [SelEnabled], 0
.mouse_drag_ok:
    clc
    jmp .done

.mouse_set_cursor:
    test al, al
    jz .cursor_arrow
    mov word [CursorPtr], resizebmp
    jmp .cursor_apply
.cursor_arrow:
    mov word [CursorPtr], mousebmp
.cursor_apply:
    cmp byte [CursorVisible], 0
    je .cursor_done
    call HideCursor
    call ShowCursor
.cursor_done:
    clc
    jmp .done

.win_set:
    cmp bl, TASK_SLOT_COUNT
    jae .win_bad
    xor bh, bh
    mov byte [task_win_flags + bx], 0x05
    shl bx, 1
    mov [task_win_x + bx], cx
    mov [task_win_y + bx], dx
    mov [task_win_w + bx], si
    mov [task_win_h + bx], di
    clc
    jmp .done
.win_bad:
    stc
    jmp .done

.win_close:
    cmp bl, TASK_SLOT_COUNT
    jae .win_bad
    xor bh, bh
    or byte [task_win_flags + bx], 0x02
    clc
    jmp .done

.win_get:
    xor bh, bh
    mov bl, [sched_cur_task]
    mov al, [task_win_flags + bx]
    and byte [task_win_flags + bx], 0xFB
    mov bp, sp
    xor ah, ah
    mov [bp+18], ax
    shl bx, 1
    mov ax, [task_win_x + bx]
    mov [bp+16], ax
    mov ax, [task_win_y + bx]
    mov [bp+14], ax
    mov ax, [task_win_w + bx]
    mov [bp+6], ax
    mov ax, [task_win_h + bx]
    mov [bp+4], ax
    clc
    jmp .done

.done:
    jc .set_cf
    push bp
    mov bp, sp
    and word [bp+26], 0xFFFE
    pop bp
    jmp .do_iret
.set_cf:
    push bp
    mov bp, sp
    or  word [bp+26], 0x0001
    pop bp
.do_iret:
    pop es
    pop ds
    popa
    iret

; ==================================================================
; copy_caller_string_si_23 -- copy NUL-terminated string from
;     [caller_ds_save_23:SI] into kernel scratch and update SI.
; OUT: SI = offset of scratch (in kernel DS).
; ==================================================================
copy_caller_string_si_23:
    push ax
    push cx
    push di
    push es
    push ds

    push cs
    pop es
    mov di, .scratch
    mov cx, 63
    mov ax, [cs:caller_ds_save_23]
    mov ds, ax
.cl:
    lodsb
    stosb
    test al, al
    jz .done
    loop .cl
    mov byte [es:di], 0
.done:
    pop ds
    pop es
    pop di
    pop cx
    pop ax
    mov si, .scratch
    ret

.scratch times 64 db 0

caller_ds_save_23 dw 0

task_win_flags  times TASK_SLOT_COUNT db 0
task_win_x      times TASK_SLOT_COUNT dw 0
task_win_y      times TASK_SLOT_COUNT dw 0
task_win_w      times TASK_SLOT_COUNT dw 0
task_win_h      times TASK_SLOT_COUNT dw 0