; ==================================================================
; x16-PRos -- GUI. A tiny window manager.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "x16-PRos GUI", "PRoX-dev"
PLE_LOGO          "logo/gui.raw"

%define MENUBAR_H   18
%define WIN_TBAR    18
%define WW          200
%define WH          150
%define MIN_WW      140
%define MIN_WH      80
%define MAX_WIN     5
%define IW          32
%define IH          26
%define ICON_X0     24
%define ICON_Y0     32
%define ICON_DX     96
%define ICON_DY     80
%define ICON_COLS   6
%define MAX_ICONS   16
%define LOGO_LOAD_OFF   0x4000
%define LOGO_LOAD_MAX   0x4000
%define LOGO_CACHE_OFF  0x8000
%define LOGO_PX         32

%define ICON_ROUND      2  ; corner chamfer
%define NAME_GAP        6  ; gap between icon and label

%define STAR_X        4
%define STAR_Y        3
%define STAR_W        11
%define STAR_H        11
%define TILE_X        0
%define TILE_Y        0
%define TILE_W        18
%define TILE_H        (MENUBAR_H - 1)
%define TILE_COL      7
%define DOT_ZONE_W    20
%define MENU_X        2
%define MENU_Y        MENUBAR_H
%define MENU_IW       128
%define MENU_IH       16
%define MENU_N        4
%define MENU_H        (MENU_N * MENU_IH)
%define FONT_ITEM     3
%define FONT_MENU_X   (MENU_X + MENU_IW + 2)
%define FONT_MENU_Y   (MENU_Y + FONT_ITEM * MENU_IH)
%define FONT_MENU_IW  110
%define MAX_FONTS     12

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    mov ah, 0x06
    int 0x21

    mov byte [dragging], 0
    mov byte [prev_lmb], 0
    mov byte [closing], 0
    mov byte [close_slot], 0xFF
    mov word [last_icon], 0xFFFF
    mov word [last_tick], 0
    mov byte [last_title_slot], 0xFF
    xor bx, bx
.clrw:
    cmp bx, MAX_WIN
    jae .clrdone
    mov byte [w_open + bx], 0
    inc bx
    jmp .clrw
.clrdone:
    mov ah, 0x24
    mov al, 1
    int 0x23
    mov ah, 0x23
    int 0x23
    mov ah, 0x25
    mov al, 0
    int 0x23

    call enumerate_ple
    call cache_logos
    call full_repaint

.loop:
    mov ah, 0x20
    int 0x23
    mov [mx], ax
    mov [my], bx
    mov al, cl
    and al, 1
    mov [lmb], al

    cmp byte [dragging], 0
    jne .in_drag

    mov al, [lmb]
    cmp al, [prev_lmb]
    je .after_edge
    test al, al
    jz .released

    call menu_handle_press
    jc .after_edge
    call win_at
    cmp byte [hit_kind], 0
    je .press_icons
    cmp byte [hit_kind], 1
    je .press_close
    cmp byte [hit_kind], 2
    je .press_title
    cmp byte [hit_kind], 4
    je .press_max
    cmp byte [hit_kind], 5
    je .press_resize
    jmp .after_edge

.press_icons:
    call icon_hittest
    cmp ax, 0xFFFF
    je .after_edge
    mov [launch_idx], ax
    mov bx, ax
    mov ah, 0
    int 0x1A
    cmp bx, [last_icon]
    jne .single
    mov ax, dx
    sub ax, [last_tick]
    cmp ax, 9
    jbe .do_open
.single:
    mov [last_icon], bx
    mov [last_tick], dx
    jmp .after_edge
.do_open:
    call open_window
    jmp .after_edge
.press_close:
    mov al, [hit_slot]
    mov [close_slot], al
    mov byte [closing], 1
    jmp .after_edge
.press_title:
    mov ah, 0
    int 0x1A
    mov al, [hit_slot]
    cmp al, [last_title_slot]
    jne .title_arm
    mov ax, dx
    sub ax, [last_title_tick]
    cmp ax, 9
    jbe .title_zoom
.title_arm:
    mov al, [hit_slot]
    mov [last_title_slot], al
    mov [last_title_tick], dx
    mov [drag_slot], al
    xor bh, bh
    mov bl, al
    cmp byte [w_max + bx], 0
    jne .after_edge
    mov ah, 0x22
    int 0x23
    call ctx_of_drag
    mov byte [dragging], 1
    mov byte [drag_resize], 0
    mov ax, [mx]
    sub ax, [win_x]
    mov [dragdx], ax
    mov ax, [my]
    sub ax, [win_y]
    mov [dragdy], ax
    mov ax, [win_x]
    mov [dragx], ax
    mov ax, [win_y]
    mov [dragy], ax
    mov ax, [win_w]
    mov [dragw], ax
    mov ax, [win_h]
    mov [dragh], ax
    call draw_outline
    jmp .after_edge
.press_resize:
    mov al, [hit_slot]
    mov [drag_slot], al
    mov ah, 0x22
    int 0x23
    call ctx_of_drag
    mov byte [dragging], 1
    mov byte [drag_resize], 1
    mov ax, [win_x]
    mov [dragx], ax
    mov ax, [win_y]
    mov [dragy], ax
    mov ax, [win_w]
    mov [dragw], ax
    mov ax, [win_h]
    mov [dragh], ax
    mov ax, [win_x]
    add ax, [win_w]
    sub ax, [mx]
    mov [dragdx], ax
    mov ax, [win_y]
    add ax, [win_h]
    sub ax, [my]
    mov [dragdy], ax
    call draw_outline
    jmp .after_edge
.title_zoom:
    mov byte [last_title_slot], 0xFF
    mov al, [hit_slot]
    call toggle_maximize
    jmp .after_edge
.press_max:
    mov al, [hit_slot]
    call toggle_maximize
    jmp .after_edge
.released:
    cmp byte [closing], 0
    je .after_edge
    mov byte [closing], 0
    call win_at
    cmp byte [hit_kind], 1
    jne .after_edge
    mov al, [hit_slot]
    cmp al, [close_slot]
    jne .after_edge
    call close_window
.after_edge:
    mov al, [lmb]
    mov [prev_lmb], al
    cmp byte [want_quit], 0
    jne gui_quit
    mov ah, 0x01
    int 0x16
    jz .delay
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je gui_quit
.delay:
    cmp byte [menu_open], 0
    jne .skip_reap
    cmp byte [font_menu_open], 0
    jne .skip_reap
    call reap_dead_windows
.skip_reap:
    call tick_clock
    call menu_tick
    call update_cursor
    mov ah, 0x13
    int 0x23
    mov ah, 0x86
    mov cx, 0
    mov dx, 12000
    int 0x15
    jmp .loop
.in_drag:
    cmp byte [drag_resize], 0
    jne .in_resize
    mov al, [lmb]
    test al, al
    jz .drag_release
    mov ax, [mx]
    sub ax, [dragdx]
    call clamp_wx
    mov [ntmpx], ax
    mov ax, [my]
    sub ax, [dragdy]
    call clamp_wy
    mov [ntmpy], ax
    mov ax, [ntmpx]
    cmp ax, [dragx]
    jne .dmove
    mov ax, [ntmpy]
    cmp ax, [dragy]
    je .after_edge
.dmove:
    call draw_outline
    mov ax, [ntmpx]
    mov [dragx], ax
    mov ax, [ntmpy]
    mov [dragy], ax
    call draw_outline
    jmp .after_edge
.in_resize:
    mov al, [lmb]
    test al, al
    jz .drag_release
    mov ax, [mx]
    add ax, [dragdx]
    sub ax, [dragx]
    cmp ax, MIN_WW
    jge .rw_min
    mov ax, MIN_WW
.rw_min:
    mov bx, 640
    sub bx, [dragx]
    cmp ax, bx
    jle .rw_max
    mov ax, bx
.rw_max:
    mov [ntmpw], ax
    mov ax, [my]
    add ax, [dragdy]
    sub ax, [dragy]
    cmp ax, MIN_WH
    jge .rh_min
    mov ax, MIN_WH
.rh_min:
    mov bx, 480
    sub bx, [dragy]
    cmp ax, bx
    jle .rh_max
    mov ax, bx
.rh_max:
    mov [ntmph], ax
    mov ax, [ntmpw]
    cmp ax, [dragw]
    jne .rmove
    mov ax, [ntmph]
    cmp ax, [dragh]
    je .after_edge
.rmove:
    call draw_outline
    mov ax, [ntmpw]
    mov [dragw], ax
    mov ax, [ntmph]
    mov [dragh], ax
    call draw_outline
    jmp .after_edge
.drag_release:
    call draw_outline
    mov byte [dragging], 0
    cmp byte [drag_resize], 0
    jne .dr_resized
    xor ah, ah
    mov al, [drag_slot]
    mov si, ax
    add si, si
    mov ax, [dragx]
    cmp ax, [w_x + si]
    jne .dr_moved
    mov ax, [dragy]
    cmp ax, [w_y + si]
    je .dr_nomove
.dr_moved:
    mov ax, [dragx]
    mov [w_x + si], ax
    mov ax, [dragy]
    mov [w_y + si], ax
    mov al, [drag_slot]
    call publish_window
    call full_repaint
    jmp .after_edge
.dr_resized:
    mov byte [drag_resize], 0
    xor ah, ah
    mov al, [drag_slot]
    mov si, ax
    add si, si
    mov ax, [dragw]
    mov [w_w + si], ax
    mov ax, [dragh]
    mov [w_h + si], ax
    mov al, [drag_slot]
    call publish_window
    call full_repaint
    jmp .after_edge
.dr_nomove:
    mov ah, 0x23
    int 0x23
    jmp .after_edge

gui_quit:
    xor bx, bx
.qk:
    cmp bx, MAX_WIN
    jae .qk_done
    cmp byte [w_open + bx], 0
    je .qk_next
    push bx
    mov bl, [w_task + bx]
    mov ah, 0x32
    int 0x23
    pop bx
.qk_next:
    inc bx
    jmp .qk
.qk_done:
    mov ah, 0x26
    mov al, 0
    int 0x23
    mov ah, 0x25
    mov al, 1
    int 0x23
    mov ah, 0x0C
    int 0x21
    retf

%include "windows.inc"
%include "launch.inc"
%include "bar.inc"
%include "icons.inc"
%include "menu.inc"
%include "fonts.inc"
%include "data.inc"

%include "grafx.inc"
%include "win.inc"
%include "font.inc"

PLE_END
