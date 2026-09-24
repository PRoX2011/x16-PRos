; ==================================================================
; x16-PRos - INT 33h mouse ABI for MS-DOS programs
; Copyright (C) 2026 PRoX2011
; ==================================================================

[BITS 16]

M33_SCR_MAXX  equ 639
M33_SCR_MAXY  equ 479

int33_init:
    push ax
    push es
    xor ax, ax
    mov es, ax
    cli
    mov word [es:0x33*4],     int33_handler
    mov word [es:0x33*4 + 2], cs
    sti
    call m33_reset_state
    pop es
    pop ax
    ret

m33_reset_state:
    push ax
    push cx
    push di
    push es

    push cs
    pop es

    mov word [m33_minx], 0
    mov word [m33_maxx], M33_SCR_MAXX
    mov word [m33_miny], 0
    mov word [m33_maxy], M33_SCR_MAXY
    mov word [m33_mickx], 0
    mov word [m33_micky], 0
    mov word [m33_dx], 0
    mov word [m33_dy], 0
    mov word [m33_hide], 1
    mov word [m33_hnd_mask], 0
    mov word [m33_hnd_ptr], 0
    mov word [m33_hnd_ptr + 2], 0
    mov byte [m33_busy], 0
    mov word [m33_events], 0

    mov di, m33_pcnt
    mov cx, 18
    xor ax, ax
    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    ret

int33_handler:
    cld
    push ds
    push si
    push di
    push bp
    push cs
    pop ds


    cmp ax, 0x0000
    je .reset
    cmp ax, 0x0001
    je .show
    cmp ax, 0x0002
    je .hide
    cmp ax, 0x0003
    je .getpos
    cmp ax, 0x0004
    je .setpos
    cmp ax, 0x0005
    je .press
    cmp ax, 0x0006
    je .release
    cmp ax, 0x0007
    je .xrange
    cmp ax, 0x0008
    je .yrange
    cmp ax, 0x000B
    je .motion
    cmp ax, 0x000C
    je .sethnd
    cmp ax, 0x0014
    je .swaphnd
    jmp .done

.reset:
    call m33_reset_state
    call m33_rearm_force
    mov ax, 0xFFFF
    mov bx, 2
    jmp .done

.show:
    cmp word [m33_hide], 0
    je .done
    dec word [m33_hide]
    jmp .done

.hide:
    inc word [m33_hide]
    jmp .done

.getpos:
    call m33_clamp_pos
    xor bx, bx
    mov bl, [ButtonStatus]
    mov cx, [MouseX]
    mov dx, [MouseY]
    jmp .done

.setpos:
    mov [MouseX], cx
    mov [MouseY], dx
    call m33_clamp_pos
    call m33_sync_cell
    jmp .done

.press:
    mov si, m33_pcnt
    jmp short .counters

.release:
    mov si, m33_rcnt

.counters:
    cmp bx, 3
    jae .bad_button
    shl bx, 1
    mov ax, [si + bx]
    mov word [si + bx], 0
    mov cx, [si + bx + 6]
    mov dx, [si + bx + 12]
    mov bx, ax
    xor ax, ax
    mov al, [ButtonStatus]
    jmp .done
.bad_button:
    xor ax, ax
    mov al, [ButtonStatus]
    xor bx, bx
    mov cx, [MouseX]
    mov dx, [MouseY]
    jmp .done

.xrange:
    cmp cx, dx
    jbe .x_ok
    xchg cx, dx
.x_ok:
    mov [m33_minx], cx
    mov [m33_maxx], dx
    call m33_clamp_pos
    jmp .done

.yrange:
    cmp cx, dx
    jbe .y_ok
    xchg cx, dx
.y_ok:
    mov [m33_miny], cx
    mov [m33_maxy], dx
    call m33_clamp_pos
    jmp .done

.motion:
    mov cx, [m33_mickx]
    mov dx, [m33_micky]
    mov word [m33_mickx], 0
    mov word [m33_micky], 0
    jmp .done

.sethnd:
    mov [m33_hnd_mask], cx
    mov [m33_hnd_ptr], dx
    mov [m33_hnd_ptr + 2], es
    call m33_rearm
    jmp .done

.swaphnd:
    mov ax, [m33_hnd_mask]
    mov si, [m33_hnd_ptr]
    mov di, [m33_hnd_ptr + 2]
    mov [m33_hnd_mask], cx
    mov [m33_hnd_ptr], dx
    mov [m33_hnd_ptr + 2], es
    call m33_rearm

    mov cx, ax
    mov dx, si
    mov es, di
    jmp .done

.done:
    pop bp
    pop di
    pop si
    pop ds
    iret

m33_rearm_force:
    pusha
    push es
    push cs
    pop es
    call EnableMouse
    pop es
    popa
    ret

m33_rearm:
    cmp word [m33_hnd_mask], 0
    je .leave_alone
    pusha
    push es
    push cs
    pop es
    call EnableMouse
    pop es
    popa
.leave_alone:
    ret

m33_clamp_pos:
    push ax
    mov ax, [MouseX]
    cmp ax, [m33_minx]
    jae .x_min_ok
    mov ax, [m33_minx]
.x_min_ok:
    cmp ax, [m33_maxx]
    jbe .x_max_ok
    mov ax, [m33_maxx]
.x_max_ok:
    mov [MouseX], ax

    mov ax, [MouseY]
    cmp ax, [m33_miny]
    jae .y_min_ok
    mov ax, [m33_miny]
.y_min_ok:
    cmp ax, [m33_maxy]
    jbe .y_max_ok
    mov ax, [m33_maxy]
.y_max_ok:
    mov [MouseY], ax
    pop ax
    ret

m33_sync_cell:
    push ax
    push bx
    push dx
    mov ax, [MouseX]
    shr ax, 3
    mov [MouseCol], ax
    mov ax, [MouseY]
    xor dx, dx
    mov bx, 16
    div bx
    mov [MouseRow], ax
    pop dx
    pop bx
    pop ax
    ret

m33_edges:
    pusha

    mov word [m33_events], 0

    mov ax, [m33_dx]
    or ax, [m33_dy]
    jz .no_move
    or word [m33_events], 0x0001
.no_move:

    mov dl, bl
    mov dh, bl
    xor dh, bh
    xor si, si
    mov cx, 3
    mov bp, 0x0002

.btn_loop:
    test dh, 1
    jz .btn_next

    test dl, 1
    jz .btn_release

    mov ax, [MouseX]
    mov [m33_pcnt + si + 6], ax
    mov ax, [MouseY]
    mov [m33_pcnt + si + 12], ax
    inc word [m33_pcnt + si]
    or [m33_events], bp
    jmp short .btn_next

.btn_release:
    mov ax, [MouseX]
    mov [m33_rcnt + si + 6], ax
    mov ax, [MouseY]
    mov [m33_rcnt + si + 12], ax
    inc word [m33_rcnt + si]
    mov ax, bp
    shl ax, 1
    or [m33_events], ax

.btn_next:
    shr dl, 1
    shr dh, 1
    add si, 2
    shl bp, 1
    shl bp, 1
    loop .btn_loop

    mov ax, [m33_events]
    and ax, [m33_hnd_mask]
    jz .done
    cmp word [m33_hnd_ptr + 2], 0
    je .done
    cmp byte [m33_busy], 0
    jne .done

    mov byte [m33_busy], 1

    xor bx, bx
    mov bl, [ButtonStatus]
    mov cx, [MouseX]
    mov dx, [MouseY]
    mov si, [m33_dx]
    mov di, [m33_dy]
    call far [m33_hnd_ptr]
    push cs
    pop ds
    mov byte [m33_busy], 0

.done:
    popa
    ret

m33_minx     dw 0
m33_maxx     dw M33_SCR_MAXX
m33_miny     dw 0
m33_maxy     dw M33_SCR_MAXY
m33_mickx    dw 0
m33_micky    dw 0
m33_dx       dw 0
m33_dy       dw 0
m33_hide     dw 1
m33_events   dw 0
m33_hnd_mask dw 0
m33_hnd_ptr  dw 0, 0
m33_busy     db 0
m33_pcnt     times 3 dw 0
m33_ppx      times 3 dw 0
m33_ppy      times 3 dw 0
m33_rcnt     times 3 dw 0
m33_rrx      times 3 dw 0
m33_rry      times 3 dw 0
