set_ctx_win:
    push ax
    push bx
    push cx
    push dx
    push si
    xor ah, ah
    mov si, ax
    add si, si
    mov ax, [w_x + si]
    mov bx, [w_y + si]
    mov cx, [w_w + si]
    mov dx, [w_h + si]
    call win_set_context
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ctx_of_drag:
    push ax
    mov al, [drag_slot]
    call set_ctx_win
    pop ax
    ret

; ========================================================================
; PUBLISH_WINDOW - hand a window's content rect
; IN  : AL = window slot
; OUT : nothing (all registers preserved)
; ========================================================================
publish_window:
    pusha
    mov [.slot], al
    xor ah, ah
    mov bx, ax
    mov bl, [w_task + bx]
    mov [.task], bl
    mov al, [.slot]
    xor ah, ah
    mov si, ax
    add si, si
    mov cx, [w_x + si]
    inc cx
    mov dx, [w_y + si]
    add dx, WIN_TBAR
    mov di, [w_h + si]
    sub di, WIN_TBAR + 1
    mov si, [w_w + si]
    sub si, 2
    mov bl, [.task]
    call wm_set_window

    mov al, [.slot]
    call publish_clips
    popa
    ret
.slot db 0
.task db 0

; ========================================================================
; PUBLISH_CLIPS - refresh just the occluder list of one window
; IN  : AL = window slot
; OUT : nothing (all registers preserved)
; ========================================================================
publish_clips:
    pusha
    call clip_build
    xor ah, ah
    mov bx, ax
    mov bl, [w_task + bx]
    mov cl, [clip_n]
    xor ch, ch
    mov si, clip_rects
    call wm_set_clips
    popa
    ret

; ========================================================================
; PUBLISH_ALL_CLIPS - refresh the occluder list of every open window
; ========================================================================
publish_all_clips:
    pusha
    xor cx, cx
.win:
    cmp cx, MAX_WIN
    jae .done
    mov bx, cx
    cmp byte [w_open + bx], 0
    je .next
    mov al, cl
    call publish_clips
.next:
    inc cx
    jmp .win
.done:
    popa
    ret

; ========================================================================
; OVERLAY_STATE - one byte describing which overlays are on screen
; IN : nothing
; OUT : AL = bit 0 main menu, bit 1 wallpaper list, bit 2 font list,
;       bit 3 calendar
; ========================================================================
overlay_state:
    xor al, al
    cmp byte [menu_open], 0
    je .wp
    or al, 0x01
.wp:
    cmp byte [wp_menu_open], 0
    je .font
    or al, 0x02
.font:
    cmp byte [font_menu_open], 0
    je .cal
    or al, 0x04
.cal:
    cmp byte [cal_open], 0
    je .done
    or al, 0x08
.done:
    ret

; ========================================================================
; SYNC_OVERLAY_CLIP - tell the hosted programs about the menus
; IN  : nothing
; OUT : every window's occluder list refreshed when an overlay opened or closed
; ========================================================================
sync_overlay_clip:
    push ax
    call overlay_state
    cmp al, [overlay_prev]
    je .done
    mov [overlay_prev], al
    call publish_all_clips
.done:
    pop ax
    ret
overlay_prev db 0

; ========================================================================
; CLIP_BUILD - list everything drawn on top of a window
; IN : AL = window slot
; OUT : [clip_n] = rectangle count
;       clip_rects = {x, y, w, h} per rectangle
; ========================================================================
clip_build:
    pusha
    mov byte [clip_n], 0
    xor ah, ah
    mov dx, ax
    mov bx, ax
.scan:
    inc bx
    cmp bx, MAX_WIN
    jae .overlays
    cmp byte [w_open + bx], 0
    je .scan
    mov ax, dx
    call clip_overlaps
    jnc .scan
    call clip_append
    jmp .scan
.overlays:
    call clip_add_overlays
    popa
    ret

; ========================================================================
; CLIP_ADD_OVERLAYS - add the menus the GUI paints over the windows
; IN  : nothing
; OUT : the open overlays appended to the list being built
; ========================================================================
clip_add_overlays:
    pusha
    cmp byte [menu_open], 0
    je .wp
    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_IW
    mov di, MENU_H
    call clip_add_rect
.wp:
    cmp byte [wp_menu_open], 0
    je .font
    mov cx, WPMENU_X
    mov dx, WPMENU_Y
    mov si, WPMENU_IW
    mov di, WPMENU_H
    call clip_add_rect
.font:
    cmp byte [font_menu_open], 0
    je .cal
    mov ax, [font_count]
    mov bx, MENU_IH
    mul bx
    mov di, ax
    mov cx, FONT_MENU_X
    mov dx, FONT_MENU_Y
    mov si, FONT_MENU_IW
    call clip_add_rect
.cal:
    cmp byte [cal_open], 0
    je .done
    mov cx, CAL_X
    mov dx, CAL_Y
    mov si, CAL_W
    mov di, CAL_H
    call clip_add_rect
.done:
    popa
    ret

; ========================================================================
; CLIP_OVERLAPS - do two windows share any pixel?
; IN  : AX = first slot
;       BX = second slot
; OUT : CF = 1 when the two rectangles intersect
; ========================================================================
clip_overlaps:
    push ax
    push bx
    push si
    push di
    add ax, ax
    mov si, ax
    add bx, bx
    mov di, bx

    mov ax, [w_x + di]
    add ax, [w_w + di]
    cmp [w_x + si], ax
    jge .apart
    mov ax, [w_x + si]
    add ax, [w_w + si]
    cmp [w_x + di], ax
    jge .apart
    mov ax, [w_y + di]
    add ax, [w_h + di]
    cmp [w_y + si], ax
    jge .apart
    mov ax, [w_y + si]
    add ax, [w_h + si]
    cmp [w_y + di], ax
    jge .apart

    pop di
    pop si
    pop bx
    pop ax
    stc
    ret
.apart:
    pop di
    pop si
    pop bx
    pop ax
    clc
    ret

; ========================================================================
; CLIP_APPEND - add a window's rectangle to the list being built
; IN  : BX = window slot
; OUT : rectangle stored and [clip_n] advanced, or nothing when full
; ========================================================================
clip_append:
    pusha
    mov si, bx
    add si, si
    mov cx, [w_x + si]
    mov dx, [w_y + si]
    mov di, [w_h + si]
    mov si, [w_w + si]
    call clip_add_rect
    popa
    ret

; ========================================================================
; CLIP_ADD_RECT - add one rectangle to the list being built
; IN  : CX = x
;       DX = y
;       SI = width
;       DI = height
; OUT : rectangle stored and [clip_n] advanced, or nothing when full
; ========================================================================
clip_add_rect:
    pusha
    test si, si
    jle .done
    test di, di
    jle .done
    mov al, [clip_n]
    cmp al, MAX_CLIP
    jae .done
    xor ah, ah
    shl ax, 3
    mov bx, clip_rects
    add bx, ax
    mov [bx], cx
    mov [bx + 2], dx
    mov [bx + 4], si
    mov [bx + 6], di
    inc byte [clip_n]
.done:
    popa
    ret

; ========================================================================
; CLIP_INSTALL - load the built list into the grafx clip layer
; IN  : [clip_n] / clip_rects, as left by clip_build
; OUT : nothing (all registers preserved)
; ========================================================================
clip_install:
    pusha
    call gfx_clip_reset
    mov word [.i], 0
.add:
    mov al, [clip_n]
    xor ah, ah
    cmp [.i], ax
    jae .done
    mov ax, [.i]
    shl ax, 3
    mov bx, clip_rects
    add bx, ax
    mov cx, [bx]
    mov dx, [bx + 2]
    mov si, [bx + 4]
    mov di, [bx + 6]
    call gfx_clip_add
    inc word [.i]
    jmp .add
.done:
    popa
    ret
.i dw 0

win_at:
    pusha
    mov byte [hit_slot], 0xFF
    mov byte [hit_kind], 0
    mov cx, MAX_WIN
.wa_loop:
    test cx, cx
    je .wa_done
    dec cx
    mov bx, cx
    cmp byte [w_open + bx], 0
    je .wa_loop
    mov al, cl
    call set_ctx_win
    mov ax, [mx]
    mov bx, [my]
    call win_hit_close
    jc .wa_close
    mov ax, [mx]
    mov bx, [my]
    call win_hit_max
    jc .wa_max
    mov ax, [mx]
    mov bx, [my]
    call win_hit_title
    jc .wa_title
    xor bh, bh
    mov bl, cl
    cmp byte [w_max + bx], 0
    jne .wa_body
    mov ax, [mx]
    mov bx, [my]
    call win_hit_resize
    jc .wa_resize
.wa_body:
    mov ax, [mx]
    cmp ax, [win_x]
    jl .wa_loop
    mov bx, [win_x]
    add bx, [win_w]
    cmp ax, bx
    jge .wa_loop
    mov ax, [my]
    cmp ax, [win_y]
    jl .wa_loop
    mov bx, [win_y]
    add bx, [win_h]
    cmp ax, bx
    jge .wa_loop
    mov [hit_slot], cl
    mov byte [hit_kind], 3
    jmp .wa_done
.wa_close:
    mov [hit_slot], cl
    mov byte [hit_kind], 1
    jmp .wa_done
.wa_max:
    mov [hit_slot], cl
    mov byte [hit_kind], 4
    jmp .wa_done
.wa_resize:
    mov [hit_slot], cl
    mov byte [hit_kind], 5
    jmp .wa_done
.wa_title:
    mov [hit_slot], cl
    mov byte [hit_kind], 2
.wa_done:
    popa
    ret

update_cursor:
    cmp byte [dragging], 0
    jne .ret
    cmp byte [menu_open], 0
    jne .ret
    call win_at
    mov al, 0
    cmp byte [hit_kind], 5
    jne .have
    mov al, 1
.have:
    cmp al, [cur_shape]
    je .ret
    mov [cur_shape], al
    mov ah, 0x26
    int 0x23
.ret:
    ret

; ========================================================================
; FULL_REPAINT - redraw the desktop and every window frame
; IN : nothing
; OUT : nothing
; ========================================================================
full_repaint:
    mov ah, 0x22
    int 0x23
    call draw_desktop_bg
    call font_init
    call draw_menubar
    call draw_desktop_icons
    xor cx, cx
.fw:
    cmp cx, MAX_WIN
    jae .done
    mov bx, cx
    cmp byte [w_open + bx], 0
    je .skip
    mov al, cl
    call set_ctx_win
    mov bx, cx
    mov al, [w_icon + bx]
    xor ah, ah
    shl ax, 4
    add ax, icon_names
    mov [win_title], ax
    mov al, cl
    call clip_build
    call clip_install
    call win_draw_frame
    call gfx_clip_reset
    mov al, cl
    call publish_window
.skip:
    inc cx
    jmp .fw
.done:
    mov ah, 0x23
    int 0x23
    ret

draw_desktop_bg:
    pusha
    push es
    cld
    mov ax, 0xA000
    mov es, ax
    mov dx, 0x3CE
    mov al, 0x01
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x05
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    mov bp, MENUBAR_H
.row:
    cmp bp, 480
    jae .done
    mov ax, bp
    mov bx, 80
    mul bx
    mov di, ax

    mov bx, bp
    and bx, 7
    mov al, [bg_pattern + bx]
    mov cx, 80
    rep stosb

    inc bp
    jmp .row
.done:
    pop es
    popa
    ret

cycle_wallpaper:
    inc byte [bg_style]
    cmp byte [bg_style], BG_STYLE_COUNT
    jb .done
    mov byte [bg_style], 0
.done:
    call apply_wallpaper
    ret

draw_outline:
    push ax
    mov byte [gfx_xor], 1
    mov cx, [dragx]
    mov dx, [dragy]
    mov si, [dragw]
    mov di, [dragh]
    mov al, 15
    call gfx_rect
    mov byte [gfx_xor], 0
    pop ax
    ret

clamp_wx:
    push bx
    cmp ax, 0
    jge .a
    xor ax, ax
.a:
    mov bx, 640
    sub bx, [dragw]
    cmp ax, bx
    jle .b
    mov ax, bx
.b:
    pop bx
    ret

clamp_wy:
    push bx
    cmp ax, MENUBAR_H
    jge .a
    mov ax, MENUBAR_H
.a:
    mov bx, 480
    sub bx, [dragh]
    cmp ax, bx
    jle .b
    mov ax, bx
.b:
    pop bx
    ret
