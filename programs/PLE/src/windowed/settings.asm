; ==================================================================
; x16-PRos -- SETTINGS. GUI appearance settings.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "GUI Settings", "PRoX-dev"
PLE_LOGO          "logo/settings.raw"

MARGIN     equ 8
ROW_H      equ 44
SLIDER_H   equ 14
SLIDER_W   equ 160
BTN_H      equ 18
HINT_H     equ 18

BOT_M      equ 4
BOT_GAP    equ 4

NAV_H      equ 24
NAV_GAP    equ 8

TILE_N     equ 8
CELL_MIN   equ 4
CELL_MAX   equ 12
PREV_W     equ 32
PREV_H     equ 32
PREV_GAP   equ 10

SCREEN_MENU equ 0
SCREEN_MAIN equ 1
SCREEN_WALL equ 2

DRAG_NONE  equ 0xFF
DRAG_ROUND equ 0
DRAG_GAP   equ 1
DRAG_TILE  equ 2

MAX_TASKS  equ 8

ROUND_MIN  equ 0
ROUND_MAX  equ 8
GAP_MIN    equ 0
GAP_MAX    equ 8

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    call surf_sync
    cmp byte [surf_windowed], 1
    je .ready
    mov ah, 0x06
    int 0x21
    mov ah, 0x24
    mov al, 1
    int 0x23
    mov ah, 0x23
    int 0x23
.ready:
    mov byte [drag_row], DRAG_NONE
    mov byte [saved], 0
    mov byte [screen], SCREEN_MENU
    mov word [last_ox], 0xFFFF
    mov word [last_w], 0xFFFF
    mov word [last_h], 0xFFFF

    call load_round_cfg
    call load_gap_cfg
    call load_wall_cfg

.loop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .exit
    call compute_layout
    call surf_input

    cmp byte [surf_dirty], 0
    jne .full
    mov ax, [surf_ox]
    cmp ax, [last_ox]
    jne .full
    mov ax, [surf_w]
    cmp ax, [last_w]
    jne .full
    mov ax, [surf_h]
    cmp ax, [last_h]
    jne .full
    jmp .input
.full:
    mov byte [surf_dirty], 0
    mov ax, [surf_ox]
    mov [last_ox], ax
    mov ax, [surf_w]
    mov [last_w], ax
    mov ax, [surf_h]
    mov [last_h], ax
    call draw_all

.input:
    cmp byte [drag_row], DRAG_NONE
    jne .in_drag

    cmp byte [surf_mpress], 0
    je .pace

    mov cx, [save_x]
    mov dx, [btn_y]
    mov si, [save_w]
    mov di, BTN_H
    call surf_in_rect
    jc .do_save

    mov cx, [rst_x]
    mov dx, [btn_y]
    mov si, [rst_w]
    mov di, BTN_H
    call surf_in_rect
    jc .do_restart

    cmp byte [screen], SCREEN_MENU
    je .press_menu

    mov cx, [back_x]
    mov dx, [btn_y]
    mov si, [back_w]
    mov di, BTN_H
    call surf_in_rect
    jc .do_back

    cmp byte [screen], SCREEN_MAIN
    je .press_main
    jmp .press_wall

.press_menu:
    mov cx, [nav_x]
    mov dx, [nav1_y]
    mov si, [nav_w]
    mov di, NAV_H
    call surf_in_rect
    jc .open_main
    mov cx, [nav_x]
    mov dx, [nav2_y]
    mov si, [nav_w]
    mov di, NAV_H
    call surf_in_rect
    jc .open_wall
    jmp .pace

.press_main:
    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    call surf_in_rect
    jc .grab_round

    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    call surf_in_rect
    jc .grab_gap
    jmp .pace

.press_wall:
    call tile_hit
    jnc .pace
    call tile_toggle
    mov byte [drag_row], DRAG_TILE
    mov byte [saved], 0
    call draw_all
    jmp .pace

.open_main:
    mov al, SCREEN_MAIN
    call switch_screen
    jmp .pace
.open_wall:
    mov al, SCREEN_WALL
    call switch_screen
    jmp .pace
.do_back:
    mov al, SCREEN_MENU
    call switch_screen
    jmp .pace

.grab_round:
    mov byte [drag_row], DRAG_ROUND
    call track_drag
    jmp .pace
.grab_gap:
    mov byte [drag_row], DRAG_GAP
    call track_drag
    jmp .pace
.do_save:
    call save_round_cfg
    call save_gap_cfg
    call save_wall_cfg
    mov byte [saved], 1
    call draw_all
    jmp .pace
.do_restart:
    call restart_gui
    jmp .pace

.in_drag:
    cmp byte [surf_mb], 0
    je .release
    call track_drag
    jmp .pace
.release:
    mov byte [drag_row], DRAG_NONE
    jmp .pace

.pace:
    cmp byte [surf_windowed], 1
    je .wpace
    mov ah, 0x01
    int 0x16
    jz .sdelay
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .exit
.sdelay:
    mov ah, 0x86
    mov cx, 0
    mov dx, 20000
    int 0x15
    jmp .loop
.wpace:
    mov ah, 0x14
    mov cx, 1
    int 0x23
    jmp .loop

.exit:
    cmp byte [surf_windowed], 1
    je .wexit
    mov ah, 0x0C
    int 0x21
    retf
.wexit:
    mov ah, 0x12
    int 0x23
    jmp .wexit

; ========================================================================
; switch_screen - show another screen
; IN:  AL = SCREEN_MENU, SCREEN_MAIN or SCREEN_WALL
; OUT: nothing
; ========================================================================
switch_screen:
    pusha
    mov [screen], al
    mov byte [drag_row], DRAG_NONE
    call compute_layout
    call draw_all
    popa
    ret

compute_layout:
    pusha
    mov ax, [surf_h]
    sub ax, MARGIN + BTN_H
    mov [btn_y], ax
    sub ax, HINT_H
    mov [hint_y], ax
    mov [top_h], ax

    mov ax, [surf_w]
    sub ax, BOT_M * 2
    mov bx, ax
    sub ax, BOT_GAP * 2
    shr ax, 2
    mov [back_w], ax
    mov [save_w], ax
    add ax, ax
    add ax, BOT_GAP * 2
    sub bx, ax
    mov [rst_w], bx

    mov word [back_x], BOT_M
    mov ax, BOT_M + BOT_GAP
    add ax, [back_w]
    mov [save_x], ax
    add ax, [save_w]
    add ax, BOT_GAP
    mov [rst_x], ax

    cmp byte [screen], SCREEN_MAIN
    je .main
    cmp byte [screen], SCREEN_WALL
    je .wall

    mov ax, [surf_w]
    sub ax, MARGIN * 2
    mov [nav_w], ax
    mov word [nav_x], MARGIN
    mov ax, [top_h]
    sub ax, NAV_H * 2 + NAV_GAP
    jns .nav_mid
    xor ax, ax
.nav_mid:
    shr ax, 1
    mov [nav1_y], ax
    add ax, NAV_H + NAV_GAP
    mov [nav2_y], ax
    jmp .done

.main:
    mov word [round_x], MARGIN
    mov word [round_y], MARGIN + 18
    mov word [gap_x], MARGIN
    mov word [gap_y], MARGIN + 18 + ROW_H
    jmp .done

.wall:
    mov word [grid_x], MARGIN
    mov word [grid_y], MARGIN + 18

    mov ax, [top_h]
    sub ax, MARGIN + 18
    jns .cell_h
    xor ax, ax
.cell_h:
    xor dx, dx
    mov bx, TILE_N
    div bx
    mov [grid_cell], ax

    mov ax, [surf_w]
    sub ax, MARGIN * 2 + PREV_W + PREV_GAP
    jns .cell_w
    xor ax, ax
.cell_w:
    xor dx, dx
    mov bx, TILE_N
    div bx
    cmp ax, [grid_cell]
    jae .cell_clamp
    mov [grid_cell], ax
.cell_clamp:
    cmp word [grid_cell], CELL_MAX
    jbe .cell_min
    mov word [grid_cell], CELL_MAX
.cell_min:
    cmp word [grid_cell], CELL_MIN
    jae .cell_done
    mov word [grid_cell], CELL_MIN
.cell_done:
    mov ax, [grid_cell]
    mov bx, TILE_N
    mul bx
    mov [grid_w], ax
    add ax, MARGIN + PREV_GAP
    mov [prev_x], ax
    mov ax, [grid_y]
    mov [prev_y], ax
.done:
    popa
    ret

; ========================================================================
; track_drag - follow the cursor for whatever is being dragged
; IN:  [drag_row] = DRAG_ROUND, DRAG_GAP or DRAG_TILE
; OUT: the matching value updated and the surface redrawn on a change
; ========================================================================
track_drag:
    pusha
    cmp byte [drag_row], DRAG_ROUND
    je .round
    cmp byte [drag_row], DRAG_GAP
    je .gap
    cmp byte [drag_row], DRAG_TILE
    je .tile
    jmp .done

.round:
    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov bx, ROUND_MIN
    mov bp, ROUND_MAX
    call surf_slider_val
    jnc .done
    cmp ax, [cfg_round]
    je .done
    mov [cfg_round], ax
    jmp .changed

.gap:
    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov bx, GAP_MIN
    mov bp, GAP_MAX
    call surf_slider_val
    jnc .done
    cmp ax, [cfg_gap]
    je .done
    mov [cfg_gap], ax
    jmp .changed

.tile:
    call tile_hit
    jnc .done
    call tile_paint
    jnc .done

.changed:
    mov byte [saved], 0
    call draw_all
.done:
    popa
    ret

; ========================================================================
; tile_hit - which pattern cell is under the cursor
; IN:  nothing
; OUT: CF = 1 and [hit_row] / [hit_col] set to 0..7
; ========================================================================
tile_hit:
    push ax
    push bx
    push dx
    mov ax, [surf_mx]
    sub ax, [grid_x]
    js .out
    xor dx, dx
    div word [grid_cell]
    cmp ax, TILE_N
    jae .out
    mov [hit_col], ax

    mov ax, [surf_my]
    sub ax, [grid_y]
    js .out
    xor dx, dx
    div word [grid_cell]
    cmp ax, TILE_N
    jae .out
    mov [hit_row], ax

    pop dx
    pop bx
    pop ax
    stc
    ret
.out:
    pop dx
    pop bx
    pop ax
    clc
    ret

; ========================================================================
; tile_toggle - flip the cell named by tile_hit and remember the new value
; IN:  [hit_row], [hit_col]
; OUT: the pattern bit flipped, [paint_set] holds what a drag should write
; ========================================================================
tile_toggle:
    pusha
    call tile_mask
    mov bx, [hit_row]
    mov al, [cfg_wall + bx]
    test al, [tile_bit]
    jz .set
    mov byte [paint_set], 0
    jmp .apply
.set:
    mov byte [paint_set], 1
.apply:
    popa
    call tile_paint
    ret

; ========================================================================
; tile_paint - write [paint_set] into the cell named by tile_hit
; IN:  [hit_row], [hit_col], [paint_set]
; OUT: CF = 1 when the bit actually changed
; ========================================================================
tile_paint:
    push ax
    push bx
    call tile_mask
    mov bx, [hit_row]
    mov al, [cfg_wall + bx]
    cmp byte [paint_set], 0
    je .clear
    test al, [tile_bit]
    jnz .same
    or al, [tile_bit]
    jmp .store
.clear:
    test al, [tile_bit]
    jz .same
    mov ah, [tile_bit]
    not ah
    and al, ah
.store:
    mov [cfg_wall + bx], al
    pop bx
    pop ax
    stc
    ret
.same:
    pop bx
    pop ax
    clc
    ret

tile_mask:
    push ax
    push cx
    mov cx, [hit_col]
    mov al, 0x80
    shr al, cl
    mov [tile_bit], al
    pop cx
    pop ax
    ret

; ========================================================================
; draw_all - repaint the whole surface
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_all:
    pusha
    call surf_begin_paint

    mov al, 7
    call surf_clear

    cmp byte [screen], SCREEN_MAIN
    je .main
    cmp byte [screen], SCREEN_WALL
    je .wall
    call draw_screen_menu
    jmp .bottom
.main:
    call draw_screen_main
    jmp .bottom
.wall:
    call draw_screen_wall

.bottom:
    cmp byte [saved], 0
    je .hint_done
    mov si, str_done
    mov cx, MARGIN
    mov dx, [hint_y]
    mov al, 0x02
    call surf_print
.hint_done:

    cmp byte [screen], SCREEN_MENU
    je .no_back
    mov cx, [back_x]
    mov dx, [btn_y]
    mov si, [back_w]
    mov di, BTN_H
    mov bx, str_back
    xor al, al
    call surf_button
.no_back:

    mov cx, [save_x]
    mov dx, [btn_y]
    mov si, [save_w]
    mov di, BTN_H
    mov bx, str_save
    xor al, al
    call surf_button

    mov bx, str_restart
    mov si, bx
    call surf_text_w
    cmp ax, [rst_w]
    jbe .rst_caption
    mov bx, str_restart_short
.rst_caption:
    mov cx, [rst_x]
    mov dx, [btn_y]
    mov si, [rst_w]
    mov di, BTN_H
    xor al, al
    call surf_button

    call surf_end_paint
    popa
    ret

; ========================================================================
; draw_screen_menu - the screen selector
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_screen_menu:
    pusha
    mov cx, [nav_x]
    mov dx, [nav1_y]
    mov si, [nav_w]
    mov di, NAV_H
    mov bx, str_nav_main
    xor al, al
    call surf_button

    mov cx, [nav_x]
    mov dx, [nav2_y]
    mov si, [nav_w]
    mov di, NAV_H
    mov bx, str_nav_wall
    xor al, al
    call surf_button
    popa
    ret

; ========================================================================
; draw_screen_main - the two appearance sliders
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_screen_main:
    pusha
    mov si, str_round
    mov cx, MARGIN
    mov dx, MARGIN
    xor al, al
    call surf_print

    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov ax, [cfg_round]
    mov bx, ROUND_MIN
    mov bp, ROUND_MAX
    call surf_slider

    mov ax, [cfg_round]
    call num_to_str
    mov si, num_buf
    mov cx, [round_x]
    add cx, SLIDER_W + 8
    mov dx, [round_y]
    xor al, al
    call surf_print

    mov si, str_gap
    mov cx, MARGIN
    mov dx, MARGIN + ROW_H
    xor al, al
    call surf_print

    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov ax, [cfg_gap]
    mov bx, GAP_MIN
    mov bp, GAP_MAX
    call surf_slider

    mov ax, [cfg_gap]
    call num_to_str
    mov si, num_buf
    mov cx, [gap_x]
    add cx, SLIDER_W + 8
    mov dx, [gap_y]
    xor al, al
    call surf_print
    popa
    ret

; ========================================================================
; draw_screen_wall - the pattern editor and its preview
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_screen_wall:
    pusha
    mov si, str_pattern
    mov cx, MARGIN
    mov dx, MARGIN
    xor al, al
    call surf_print

    mov si, str_preview
    mov cx, [prev_x]
    mov dx, MARGIN
    xor al, al
    call surf_print

    call draw_tile_grid

    mov cx, [prev_x]
    mov dx, [prev_y]
    mov si, PREV_W
    mov di, PREV_H
    xor al, al
    call surf_fill_rect

    mov cx, [prev_x]
    mov dx, [prev_y]
    mov si, PREV_W
    mov di, PREV_H
    call draw_tiled_pattern

    mov cx, [prev_x]
    dec cx
    mov dx, [prev_y]
    dec dx
    mov si, PREV_W + 2
    mov di, PREV_H + 2
    xor al, al
    call surf_rect
    popa
    ret

; ========================================================================
; draw_tile_grid - the 8x8 editor cells
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_tile_grid:
    pusha
    mov word [.row], 0
.next_row:
    cmp word [.row], TILE_N
    jae .frame
    mov bx, [.row]
    mov al, [cfg_wall + bx]
    mov [.bits], al
    mov word [.col], 0
.next_col:
    cmp word [.col], TILE_N
    jae .row_done

    mov cx, [.col]
    mov al, 0x80
    shr al, cl
    mov ah, al
    mov al, 0
    test [.bits], ah
    jz .have_col
    mov al, 15
.have_col:
    mov [.cell_col], al

    mov ax, [.col]
    mul word [grid_cell]
    add ax, [grid_x]
    mov cx, ax
    mov ax, [.row]
    mul word [grid_cell]
    add ax, [grid_y]
    mov dx, ax
    mov si, [grid_cell]
    dec si
    mov di, si
    mov al, [.cell_col]
    call surf_fill_rect

    inc word [.col]
    jmp .next_col
.row_done:
    inc word [.row]
    jmp .next_row
.frame:
    mov cx, [grid_x]
    dec cx
    mov dx, [grid_y]
    dec dx
    mov si, [grid_w]
    add si, 2
    mov di, si
    xor al, al
    call surf_rect
    popa
    ret
.row      dw 0
.col      dw 0
.bits     db 0
.cell_col db 0

draw_tiled_pattern:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], si
    mov [.h], di
    mov word [.r], 0
.row:
    mov ax, [.r]
    cmp ax, [.h]
    jae .done
    and ax, 7
    mov bx, ax
    mov al, [cfg_wall + bx]
    mov [.bits], al
    mov word [.c], 0
    mov word [.run], 0xFFFF
.col:
    mov ax, [.c]
    cmp ax, [.w]
    jae .row_flush
    and ax, 7
    mov cl, al
    mov ah, 0x80
    shr ah, cl
    test [.bits], ah
    jz .gap
    cmp word [.run], 0xFFFF
    jne .next_col
    mov ax, [.c]
    mov [.run], ax
    jmp .next_col
.gap:
    call .flush
.next_col:
    inc word [.c]
    jmp .col
.row_flush:
    call .flush
    inc word [.r]
    jmp .row
.done:
    popa
    ret

.flush:
    cmp word [.run], 0xFFFF
    je .flush_ret
    mov cx, [.x]
    add cx, [.run]
    mov bx, [.x]
    add bx, [.c]
    dec bx
    mov dx, [.y]
    add dx, [.r]
    mov al, 15
    call surf_hline
    mov word [.run], 0xFFFF
.flush_ret:
    ret
.x    dw 0
.y    dw 0
.w    dw 0
.h    dw 0
.r    dw 0
.c    dw 0
.run  dw 0
.bits db 0

; ========================================================================
; num_to_str - render AX into num_buf without leading zeroes
; IN:  AX = value (0..999)
; OUT: num_buf holds the digits, null terminated
; ========================================================================
num_to_str:
    pusha
    mov di, num_buf
    xor cx, cx
    mov bx, 10
.split:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .split
.emit:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    loop .emit
    mov byte [di], 0
    popa
    ret

; ========================================================================
; find_gui_task - task id of the running window manager
; IN:  nothing
; OUT: AL = task id, CF = 1 when no task is called GUI.PLE
; ========================================================================
find_gui_task:
    push bx
    push cx
    push si
    push di
    mov bl, 1
.probe:
    cmp bl, MAX_TASKS
    jae .none

    push bx
    mov ah, 0x17
    int 0x23
    pop bx
    jc .next
    test al, al
    jz .next

    push bx
    mov di, task_name_buf
    mov ah, 0x19
    int 0x23
    pop bx
    jc .next

    mov si, gui_file
    mov di, task_name_buf
.cmp:
    mov al, [si]
    cmp al, [di]
    jne .next
    test al, al
    jz .hit
    inc si
    inc di
    jmp .cmp
.next:
    inc bl
    jmp .probe
.hit:
    mov al, bl
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret
.none:
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

; ========================================================================
; restart_gui - kill the window manager, start it again and quit
; IN:  nothing
; OUT: does not return once the new WM is up
; ========================================================================
restart_gui:
    pusha
    call find_gui_task
    jc .done
    mov bl, al

    mov ah, 0x17
    int 0x23
    mov [.parent], dl

    mov ah, 0x18
    int 0x23

    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov ah, 0x09
    mov si, ple_dir_name
    int 0x22
    jc .restore

    mov ah, 0x11
    mov si, gui_file
    int 0x23
    jc .restore

    mov bl, al
    mov bh, [.parent]
    cmp bh, 0xFF
    je .restore
    mov ah, 0x34
    int 0x23
.restore:
    mov ah, 0x0F
    int 0x22

    mov ah, 0x12
    int 0x23
.done:
    popa
    ret
.parent db 0xFF

; ========================================================================
; enter_gui_conf - move into A:/CONF.DIR/GUI.DIR, creating it if needed
; IN:  nothing
; OUT: CF = 1 if the directory could not be entered
; ========================================================================
enter_gui_conf:
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot

    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22
    jc .fail

    mov ah, 0x09
    mov si, gui_dir_name
    int 0x22
    jnc .ok

    mov ah, 0x0B
    mov si, gui_dir_name
    int 0x22
    jc .fail
    mov ah, 0x09
    mov si, gui_dir_name
    int 0x22
    jc .fail
.ok:
    clc
    ret
.fail:
    mov ah, 0x0F
    int 0x22
    stc
    ret

; ========================================================================
; leave_gui_conf - restore the directory saved by enter_gui_conf
; IN:  nothing
; OUT: nothing
; ========================================================================
leave_gui_conf:
    mov ah, 0x0F
    int 0x22
    ret

; ========================================================================
; parse_cfg_num - read a decimal number out of cfg_buf
; IN:  BX = byte count in cfg_buf
; OUT: AX = value, CF = 1 if no digit was found
; ========================================================================
parse_cfg_num:
    push bx
    push cx
    push dx
    push si
    mov si, cfg_buf
    xor ax, ax
    xor cx, cx
.scan:
    test bx, bx
    jz .done
    mov dl, [si]
    inc si
    dec bx
    cmp dl, '0'
    jb .done
    cmp dl, '9'
    ja .done
    mov cx, 1
    push dx
    mov dx, 10
    mul dx
    pop dx
    sub dl, '0'
    xor dh, dh
    add ax, dx
    jmp .scan
.done:
    test cx, cx
    jz .none
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret
.none:
    pop si
    pop dx
    pop cx
    pop bx
    stc
    ret

parse_cfg_tile:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, cfg_buf
    mov di, wall_tmp
    xor cx, cx
.next_num:
    cmp cx, TILE_N
    jae .full
    test bx, bx
    jz .short
.skip:
    mov dl, [si]
    cmp dl, '0'
    jb .not_digit
    cmp dl, '9'
    jbe .number
.not_digit:
    inc si
    dec bx
    jnz .skip
    jmp .short
.number:
    xor ax, ax
.digits:
    test bx, bx
    jz .store
    mov dl, [si]
    cmp dl, '0'
    jb .store
    cmp dl, '9'
    ja .store
    push dx
    mov dx, 10
    mul dx
    pop dx
    sub dl, '0'
    xor dh, dh
    add ax, dx
    inc si
    dec bx
    jmp .digits
.store:
    mov [di], al
    inc di
    inc cx
    jmp .next_num
.full:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.short:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; ========================================================================
; write_cfg_num - store AX as decimal text in the named file
; IN:  AX = value, SI = file name
; OUT: nothing
; ========================================================================
write_cfg_num:
    pusha
    mov [.name], si
    call num_to_str

    mov si, num_buf
    mov di, cfg_buf
    xor cx, cx
.copy:
    mov al, [si]
    test al, al
    jz .copied
    mov [di], al
    inc si
    inc di
    inc cx
    jmp .copy
.copied:
    mov [.len], cx

    mov ah, 0x06
    mov si, [.name]
    int 0x22

    mov ah, 0x03
    mov si, [.name]
    mov bx, cfg_buf
    mov cx, [.len]
    int 0x22
    popa
    ret
.name dw 0
.len  dw 0

; ========================================================================
; load_round_cfg - read IC_ROUND.CFG into cfg_round
; IN:  nothing
; OUT: cfg_round set, left at its default when the file is missing
; ========================================================================
load_round_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov ah, 0x02
    mov si, round_cfg_file
    mov cx, cfg_buf
    int 0x22
    jc .leave

    call parse_cfg_num
    jc .leave
    cmp ax, ROUND_MAX
    ja .leave
    mov [cfg_round], ax
.leave:
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; load_gap_cfg - read NAME_GAP.CFG into cfg_gap
; IN:  nothing
; OUT: cfg_gap set, left at its default when the file is missing
; ========================================================================
load_gap_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov ah, 0x02
    mov si, gap_cfg_file
    mov cx, cfg_buf
    int 0x22
    jc .leave

    call parse_cfg_num
    jc .leave
    cmp ax, GAP_MAX
    ja .leave
    mov [cfg_gap], ax
.leave:
    call leave_gui_conf
.done:
    popa
    ret

load_wall_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov ah, 0x02
    mov si, wall_cfg_file
    mov cx, cfg_buf
    int 0x22
    jc .leave

    call parse_cfg_tile
    jc .leave

    mov si, wall_tmp
    mov di, cfg_wall
    mov cx, TILE_N
.copy:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop .copy
.leave:
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; save_round_cfg - write cfg_round to IC_ROUND.CFG
; IN:  nothing
; OUT: nothing
; ========================================================================
save_round_cfg:
    pusha
    call enter_gui_conf
    jc .done
    mov ax, [cfg_round]
    mov si, round_cfg_file
    call write_cfg_num
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; save_gap_cfg - write cfg_gap to NAME_GAP.CFG
; IN:  nothing
; OUT: nothing
; ========================================================================
save_gap_cfg:
    pusha
    call enter_gui_conf
    jc .done
    mov ax, [cfg_gap]
    mov si, gap_cfg_file
    call write_cfg_num
    call leave_gui_conf
.done:
    popa
    ret

save_wall_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov di, cfg_buf
    xor bx, bx
.row:
    cmp bx, TILE_N
    jae .write
    mov al, [cfg_wall + bx]
    xor ah, ah
    call num_to_str

    mov si, num_buf
.copy:
    mov al, [si]
    test al, al
    jz .newline
    mov [di], al
    inc si
    inc di
    jmp .copy
.newline:
    mov byte [di], 10
    inc di
    inc bx
    jmp .row

.write:
    mov ax, di
    sub ax, cfg_buf
    mov [.len], ax

    mov ah, 0x06
    mov si, wall_cfg_file
    int 0x22

    mov ah, 0x03
    mov si, wall_cfg_file
    mov bx, cfg_buf
    mov cx, [.len]
    int 0x22

    call leave_gui_conf
.done:
    popa
    ret
.len dw 0

conf_dir_name   db 'CONF.DIR', 0
gui_dir_name    db 'GUI.DIR', 0
round_cfg_file  db 'IC_ROUND.CFG', 0
gap_cfg_file    db 'NAME_GAP.CFG', 0
wall_cfg_file   db 'WALLPAP.CFG', 0

str_round       db 'Icon corner rounding', 0
str_gap         db 'Icon to label gap', 0
str_save        db 'Save', 0
str_restart     db 'Restart GUI', 0
str_restart_short db 'Restart', 0
str_back        db 'Back', 0
str_done        db 'Saved successfully.', 0
str_nav_main    db 'General settings', 0
str_nav_wall    db 'Wallpaper', 0
str_pattern     db 'Pattern', 0
str_preview     db 'Preview', 0
gui_file        db 'GUI.PLE', 0
ple_dir_name    db 'PLE.DIR', 0
task_name_buf   times 16 db 0

cfg_round       dw 2
cfg_gap         dw 6
cfg_wall        db 0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00
wall_tmp        times TILE_N db 0

screen          db SCREEN_MENU
top_h           dw 0

nav_x           dw 0
nav_w           dw 0
nav1_y          dw 0
nav2_y          dw 0

round_x         dw 0
round_y         dw 0
gap_x           dw 0
gap_y           dw 0

grid_x          dw 0
grid_y          dw 0
grid_w          dw 0
grid_cell       dw CELL_MIN
prev_x          dw 0
prev_y          dw 0
hit_row         dw 0
hit_col         dw 0
tile_bit        db 0
paint_set       db 0

back_x          dw 0
back_w          dw 0
save_x          dw 0
save_w          dw 0
rst_x           dw 0
rst_w           dw 0
btn_y           dw 0
hint_y          dw 0

drag_row        db DRAG_NONE
saved           db 0

last_ox         dw 0xFFFF
last_w          dw 0xFFFF
last_h          dw 0xFFFF

num_buf         times 8 db 0
cfg_buf         times 512 db 0

%include "grafx.inc"
%include "surf.inc"

PLE_END
