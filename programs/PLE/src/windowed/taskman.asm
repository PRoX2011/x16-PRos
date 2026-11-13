; ==================================================================
; x16-PRos -- TASKMAN. Process manager.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Process manager", "PRoX-dev"
PLE_LOGO          "logo/taskman.raw"

MAX_TASKS       equ 8
MAX_ROWS        equ MAX_TASKS - 1
TASK_S_PAUSED   equ 5
PLE_LOGO_OFF    equ 0x40

HEADER_H        equ 20
ROW_H           equ 36
ICON_SIZE       equ 32
ICON_X          equ 4
NAME_X          equ 42
ID_GAP          equ 26
BUTTON_GAP      equ 6
SIDE_MARGIN     equ 6
KILL_W          equ 38
PAUSE_W         equ 38
BUTTON_H        equ 20
WINDOW_W        equ 280
WINDOW_H        equ 260
REFRESH_TICKS   equ 18

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    mov cx, WINDOW_W
    mov dx, WINDOW_H
    call surf_request_size
    mov byte [surf_keys], 1
    call surf_sync
    cmp byte [surf_windowed], 1
    je .ready
    mov ah, 0x06
    int 0x21
.ready:
    mov ah, 0x15
    int 0x23
    mov [self_id], al
    xor ah, ah
    int 0x1A
    mov [last_tick], dx
    call compute_layout
    call refresh_tasks
    call draw_all

.loop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .exit
    call compute_layout
    call surf_input

    cmp byte [surf_dirty], 0
    jne .redraw
    mov ax, [surf_w]
    cmp ax, [last_w]
    jne .redraw
    mov ax, [surf_h]
    cmp ax, [last_h]
    jne .redraw
    mov ax, [surf_key]
    cmp al, 27
    jne .mouse
    cmp byte [surf_windowed], 0
    je .exit
.mouse:
    cmp byte [surf_mpress], 0
    je .timer
    call handle_press
.timer:
    xor ah, ah
    int 0x1A
    mov ax, dx
    sub ax, [last_tick]
    cmp ax, REFRESH_TICKS
    jb .pace
.refresh:
    xor ah, ah
    int 0x1A
    mov [last_tick], dx
    call refresh_tasks
    cmp byte [tasks_dirty], 0
    jne .redraw
    jmp .pace
.redraw:
    call draw_all
.pace:
    call surf_idle
    jmp .loop

.exit:
    cmp byte [surf_windowed], 1
    je .window_exit
    mov ah, 0x0C
    int 0x21
    retf
.window_exit:
    mov ah, 0x12
    int 0x23
    jmp .window_exit

compute_layout:
    pusha
    mov ax, [surf_w]
    sub ax, PAUSE_W + SIDE_MARGIN
    jnc .pause_ready
    xor ax, ax
.pause_ready:
    mov [pause_x], ax
    sub ax, KILL_W + BUTTON_GAP
    jnc .kill_ready
    xor ax, ax
.kill_ready:
    mov [kill_x], ax
    sub ax, ID_GAP
    jnc .id_ready
    xor ax, ax
.id_ready:
    mov [id_x], ax

    mov ax, [surf_h]
    sub ax, HEADER_H
    jbe .no_rows
    xor dx, dx
    mov bx, ROW_H
    div bx
    cmp ax, MAX_ROWS
    jbe .store_rows
    mov ax, MAX_ROWS
.store_rows:
    mov [max_rows], al
    popa
    ret
.no_rows:
    mov byte [max_rows], 0
    popa
    ret

; ========================================================================
; refresh_tasks - snapshot every controllable task and its PLE arena
; ========================================================================
refresh_tasks:
    pusha
    mov byte [tasks_dirty], 0
    mov byte [row_count], 0
    mov byte [scan_id], 1
.scan:
    mov bl, [scan_id]
    cmp bl, MAX_TASKS
    jae .done
    mov ah, 0x17
    int 0x23
    jc .next
    test al, al
    jz .next
    mov [scan_state], al
    mov al, [max_rows]
    cmp [row_count], al
    jae .done

    mov [scan_base], cx
    mov byte [scan_icon_dirty], 0
    xor bh, bh
    mov bl, [scan_id]
    mov si, bx
    shl bx, 1
    mov ax, [scan_base]
    cmp ax, [task_base + bx]
    je .base_ready
    mov [task_base + bx], ax
    mov byte [tasks_dirty], 1
    mov byte [scan_icon_dirty], 1
.base_ready:
    mov al, [scan_state]
    cmp [task_states + si], al
    je .state_ready
    mov [task_states + si], al
    mov byte [tasks_dirty], 1
.state_ready:
    mov di, scan_name
    mov bl, [scan_id]
    mov ah, 0x19
    int 0x23
    xor bh, bh
    mov bl, [scan_id]
    shl bx, 4
    mov di, task_names
    add di, bx
    mov si, scan_name
    mov cx, 16
.name:
    lodsb
    cmp al, [di]
    je .name_same
    mov [di], al
    mov byte [tasks_dirty], 1
    mov byte [scan_icon_dirty], 1
.name_same:
    inc di
    loop .name
    cmp byte [scan_icon_dirty], 0
    je .icon_ready
    mov al, [scan_id]
    call cache_task_icon
.icon_ready:
    xor bh, bh
    mov bl, [row_count]
    mov al, [scan_id]
    cmp [row_ids + bx], al
    je .row_ready
    mov [row_ids + bx], al
    mov byte [tasks_dirty], 1
.row_ready:
    inc byte [row_count]
.next:
    inc byte [scan_id]
    jmp .scan
.done:
    mov al, [row_count]
    cmp al, [drawn_count]
    je .ret
    mov byte [tasks_dirty], 1
.ret:
    popa
    ret

; ========================================================================
; draw_all - repaint the process list and its controls
; ========================================================================
draw_all:
    pusha
    call surf_begin_paint
    mov al, 7
    call surf_clear

    xor cx, cx
    xor dx, dx
    mov si, [surf_w]
    mov di, HEADER_H
    mov al, 15
    call surf_fill_rect
    mov cx, NAME_X
    mov dx, 1
    mov si, str_process
    xor al, al
    call surf_print
    mov cx, [id_x]
    mov si, str_id
    call surf_print
    mov cx, [kill_x]
    mov si, str_end
    call surf_print
    mov cx, [pause_x]
    mov si, str_pr
    call surf_print

    mov byte [draw_row], 0
.row:
    mov al, [draw_row]
    cmp al, [max_rows]
    jae .empty_check
    cmp al, [row_count]
    jae .empty_check
    xor ah, ah
    mov bx, ax
    mov al, [row_ids + bx]
    mov [draw_id], al
    mov ax, bx
    mov cx, ROW_H
    mul cx
    add ax, HEADER_H
    mov [row_y], ax

    mov al, 15
    test byte [draw_row], 1
    jz .row_color
    mov al, 7
.row_color:
    xor bh, bh
    mov bl, [draw_id]
    cmp byte [task_states + bx], TASK_S_PAUSED
    jne .fill_row
    mov al, 14
.fill_row:
    xor cx, cx
    mov dx, [row_y]
    mov si, [surf_w]
    mov di, ROW_H
    call surf_fill_rect

    mov al, [draw_id]
    mov cx, ICON_X
    mov dx, [row_y]
    add dx, 2
    call draw_task_icon

    xor bh, bh
    mov bl, [draw_id]
    shl bx, 4
    mov si, task_names
    add si, bx
    mov cx, NAME_X
    mov dx, [row_y]
    add dx, 10
    xor al, al
    call surf_print

    mov al, [draw_id]
    add al, '0'
    mov [id_buf], al
    mov cx, [id_x]
    mov si, id_buf
    mov al, 0x00
    call surf_print

    mov al, [draw_id]
    cmp al, [self_id]
    je .next_row
    mov cx, [kill_x]
    mov dx, [row_y]
    add dx, 8
    mov si, KILL_W
    mov di, BUTTON_H
    mov bx, str_kill
    xor al, al
    call surf_button

    mov bx, str_pause
    xor ah, ah
    mov al, [draw_id]
    mov si, ax
    cmp byte [task_states + si], TASK_S_PAUSED
    jne .pause_caption
    mov bx, str_resume
.pause_caption:
    mov cx, [pause_x]
    mov dx, [row_y]
    add dx, 8
    mov si, PAUSE_W
    mov di, BUTTON_H
    xor al, al
    call surf_button

.next_row:
    inc byte [draw_row]
    jmp .row
.empty_check:
    cmp byte [row_count], 0
    jne .done
    mov cx, NAME_X
    mov dx, HEADER_H + 1
    mov si, str_empty
    xor al, al
    call surf_print
.done:
    call surf_end_paint
    mov byte [tasks_dirty], 0
    mov al, [row_count]
    mov [drawn_count], al
    mov ax, [surf_w]
    mov [last_w], ax
    mov ax, [surf_h]
    mov [last_h], ax
    popa
    ret

; ========================================================================
; task_is_gui - check whether a task is the window manager
; IN:  AL = task id
; OUT: CF = 1 for GUI.PLE
; ========================================================================
task_is_gui:
    push bx
    push cx
    push si
    push di
    xor bh, bh
    mov bl, al
    shl bx, 4
    mov si, task_names
    add si, bx
    mov di, gui_task_name
    mov cx, 8
    repe cmpsb
    je .yes
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret
.yes:
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

; ========================================================================
; cache_task_icon - cache a 32x32 sample of a PLE logo
; IN:  AL = task id
; ========================================================================
cache_task_icon:
    pusha
    push es
    xor ah, ah
    mov bx, ax
    shl bx, 10
    mov di, task_icons
    add di, bx
    shr bx, 9
    mov ax, [task_base + bx]
    test ax, ax
    jz .generic
    mov es, ax
    cmp byte [es:0], 'P'
    jne .generic
    cmp byte [es:1], 'L'
    jne .generic
    cmp byte [es:2], 'E'
    jne .generic

    mov word [.row_pos], 0
.row:
    cmp word [.row_pos], ICON_SIZE
    jae .done
    mov ax, [.row_pos]
    shl ax, 7
    add ax, PLE_LOGO_OFF
    mov [.src], ax
    mov word [.col_pos], 0
.col:
    cmp word [.col_pos], ICON_SIZE
    jae .next_row
    mov bx, [.src]
    mov al, [es:bx]
    and al, 0x0F
    mov [di], al
    inc di
    add word [.src], 2
    inc word [.col_pos]
    jmp .col
.next_row:
    inc word [.row_pos]
    jmp .row
.generic:
    mov cx, ICON_SIZE * ICON_SIZE
    mov al, 15
.fill:
    mov [di], al
    inc di
    loop .fill
    sub di, ICON_SIZE * ICON_SIZE
    xor bx, bx
    mov cx, ICON_SIZE
.top_bottom:
    mov byte [di + bx], 0
    mov byte [di + bx + ICON_SIZE * (ICON_SIZE - 1)], 0
    inc bx
    loop .top_bottom
    xor bx, bx
    mov cx, ICON_SIZE
.sides:
    mov byte [di + bx], 0
    mov byte [di + bx + ICON_SIZE - 1], 0
    add bx, ICON_SIZE
    loop .sides
.done:
    pop es
    popa
    ret
.src     dw 0
.row_pos dw 0
.col_pos dw 0

; ========================================================================
; draw_task_icon - draw a cached logo
; IN:  AL = task id, CX = x, DX = y
; ========================================================================
draw_task_icon:
    pusha
    mov [.x], cx
    mov [.y], dx
    xor ah, ah
    mov bx, ax
    shl bx, 10
    add bx, task_icons
    mov [.pixels], bx
    mov word [.row_pos], 0
.row:
    cmp word [.row_pos], ICON_SIZE
    jae .done
    mov bx, [.pixels]
    mov word [.col_pos], 0
.col:
    cmp word [.col_pos], ICON_SIZE
    jae .next_row
    mov ax, [.col_pos]
    mov [.run_start], ax
    mov al, [bx]
    mov [.color], al
.scan:
    inc word [.col_pos]
    inc bx
    cmp word [.col_pos], ICON_SIZE
    jae .emit
    cmp al, [bx]
    je .scan
.emit:
    mov cx, [.x]
    add cx, [.run_start]
    mov dx, [.y]
    add dx, [.row_pos]
    push bx
    mov bx, [.x]
    add bx, [.col_pos]
    dec bx
    mov al, [.color]
    call surf_hline
    pop bx
    jmp .col
.next_row:
    mov [.pixels], bx
    inc word [.row_pos]
    jmp .row
.done:
    popa
    ret
.x         dw 0
.y         dw 0
.pixels    dw 0
.row_pos   dw 0
.col_pos   dw 0
.run_start dw 0
.color     db 0

; ========================================================================
; kill_gui_session - close windowed clients, kill the WM and return to shell
; IN:  AL = GUI task id
; OUT: does not return
; ========================================================================
kill_gui_session:
    mov [.owner], al
    call wm_probe
    jc .finish
    mov bl, [.owner]
    cmp [es:WM_OFF_OWNER], bl
    jne .finish
    mov byte [es:WM_OFF_OWNER], WM_OWNER_NONE
    mov byte [.client], 1
.clients:
    cmp byte [.client], MAX_TASKS
    jae .finish
    mov bl, [.client]
    cmp bl, [self_id]
    je .next
    call wm_entry
    mov si, ax
    test byte [es:si + WM_E_FLAGS], WM_F_WINDOWED
    jz .next
    mov ah, 0x18
    int 0x23
.next:
    inc byte [.client]
    jmp .clients
.finish:
    mov bl, [.owner]
    mov ah, 0x18
    int 0x23
    mov ah, 0x26
    xor al, al
    int 0x23
    mov ah, 0x25
    mov al, 1
    int 0x23
    mov ah, 0x0C
    int 0x21
    mov ah, 0x12
    int 0x23
.wait:
    jmp .wait
.owner  db 0
.client db 0

; ========================================================================
; handle_press - activate the kill or pause/resume button under the cursor
; ========================================================================
handle_press:
    pusha
    mov byte [.row], 0
.scan:
    mov al, [.row]
    cmp al, [row_count]
    jae .done
    xor ah, ah
    mov bx, ax
    mov al, [row_ids + bx]
    mov [.id], al
    cmp al, [self_id]
    je .next_row
    mov ax, bx
    mov cx, ROW_H
    mul cx
    add ax, HEADER_H + 8
    mov [.y], ax

    mov cx, [kill_x]
    mov dx, [.y]
    mov si, KILL_W
    mov di, BUTTON_H
    call surf_in_rect
    jc .kill
    mov cx, [pause_x]
    mov dx, [.y]
    mov si, PAUSE_W
    mov di, BUTTON_H
    call surf_in_rect
    jc .pause
.next_row:
    inc byte [.row]
    jmp .scan
.kill:
    mov al, [.id]
    call task_is_gui
    jnc .kill_task
    call kill_gui_session
    jmp .done
.kill_task:
    mov bl, [.id]
    mov ah, 0x18
    int 0x23
    jmp .changed
.pause:
    xor bh, bh
    mov bl, [.id]
    mov si, bx
    mov ax, 0x1A01
    cmp byte [task_states + si], TASK_S_PAUSED
    jne .set_paused
    mov ax, 0x1A00
.set_paused:
    int 0x23
.changed:
    call refresh_tasks
    call draw_all
    xor ah, ah
    int 0x1A
    mov [last_tick], dx
.done:
    popa
    ret
.row db 0
.id  db 0
.y   dw 0

str_process db 'PROCESS', 0
str_id      db 'ID', 0
str_end     db 'END', 0
str_pr      db 'P/R', 0
str_kill    db 'X', 0
str_pause   db 'II', 0
str_resume  db '>', 0
str_empty   db 'No processes', 0
gui_task_name db 'GUI.PLE', 0
id_buf      db 0, 0

self_id     db 0
scan_id     db 0
scan_state  db 0
scan_icon_dirty db 0
scan_base   dw 0
scan_name   times 16 db 0
row_count   db 0
drawn_count db 0
tasks_dirty db 0
row_ids     times MAX_ROWS db 0
task_states times MAX_TASKS db 0
task_base   times MAX_TASKS dw 0
task_names  times MAX_TASKS * 16 db 0
task_icons  times MAX_TASKS * ICON_SIZE * ICON_SIZE db 0
draw_row    db 0
draw_id     db 0
row_y       dw 0
max_rows    db 0
id_x        dw 0
kill_x      dw 0
pause_x     dw 0
last_w      dw 0xFFFF
last_h      dw 0xFFFF
last_tick   dw 0

%include "grafx.inc"
%include "surf.inc"

PLE_END
