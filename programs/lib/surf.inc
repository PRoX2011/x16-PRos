; ========================================================================
; surf.inc - drawing surface that works full-screen or inside a GUI window
; Copyright (C) 2026 PRoX2011
;
; Depends on grafx.inc.
; ========================================================================

%ifndef SURF_INC
%define SURF_INC

%include "wm.inc"

SURF_CLIP_MAX equ GFX_CLIP_MAX
SURF_NO_RUN   equ 0xFFFF

surf_windowed db 0
surf_close    db 0
surf_dirty    db 0
surf_ox       dw 0
surf_oy       dw 0
surf_w        dw 640
surf_h        dw 480
surf_cl       dw 0
surf_ct       dw 0
surf_cr       dw 639
surf_cb       dw 479
surf_clipn    dw 0

; ========================================================================
; surf_sync - query the WM for this task's window and update the surface
; IN:  nothing
; OUT: [surf_windowed] = 1 if hosted in a window, else 0
;      [surf_close]    = 1 if the WM asked us to close
;      [surf_dirty]    = 1 if the WM wants a repaint this frame
;      surface origin/size in [surf_ox]/[surf_oy]/[surf_w]/[surf_h]
;      the windows covering ours loaded into the grafx clip list
;
; NOTE: Recomended to call once per frame.
; ========================================================================
surf_sync:
    pusha
    push es
    call wm_locate
    jc .fullscreen

    mov ah, 0x15
    int 0x23
    mov bl, al
    call wm_entry
    mov di, ax
    mov al, [es:di + WM_E_FLAGS]
    test al, WM_F_WINDOWED
    jz .fullscreen

    mov byte [surf_windowed], 1
    test al, WM_F_CLOSE
    jz .nclose
    mov byte [surf_close], 1
.nclose:
    mov byte [surf_dirty], 0
    test al, WM_F_DIRTY
    jz .ndirty
    mov byte [surf_dirty], 1
    ; taking the repaint request also consumes it
    and byte [es:di + WM_E_FLAGS], ~WM_F_DIRTY & 0xFF
.ndirty:
    mov ax, [es:di + WM_E_X]
    mov [surf_ox], ax
    mov ax, [es:di + WM_E_Y]
    mov [surf_oy], ax
    mov ax, [es:di + WM_E_W]
    mov [surf_w], ax
    mov ax, [es:di + WM_E_H]
    mov [surf_h], ax
    jmp .clip
.fullscreen:
    mov byte [surf_windowed], 0
    mov word [surf_ox], 0
    mov word [surf_oy], 0
    mov word [surf_w], 640
    mov word [surf_h], 480
.clip:
    mov ax, [surf_ox]
    mov [surf_cl], ax
    add ax, [surf_w]
    dec ax
    mov [surf_cr], ax
    mov ax, [surf_oy]
    mov [surf_ct], ax
    add ax, [surf_h]
    dec ax
    mov [surf_cb], ax

    call gfx_clip_reset
    mov word [surf_clipn], 0
    cmp byte [surf_windowed], 0
    je .done
    call surf_clip_fetch
.done:
    pop es
    popa
    ret

; ========================================================================
; surf_clip_fetch - load the windows stacked above ours into the clip list
; IN:  ES:DI = this task's entry in the manager's block
; OUT: [surf_clipn] = rectangle count, the same rectangles handed to the
;      grafx clip list so every surf primitive stays out of them
; ========================================================================
surf_clip_fetch:
    pusha
    mov al, [es:di + WM_E_CLIPN]
    xor ah, ah
    cmp ax, SURF_CLIP_MAX
    jbe .have
    mov ax, SURF_CLIP_MAX
.have:
    mov [surf_clipn], ax
    mov bx, di
    add bx, WM_E_CLIP
    mov word [.i], 0
.add:
    mov ax, [.i]
    cmp ax, [surf_clipn]
    jae .done
    mov cx, [es:bx]
    mov dx, [es:bx + 2]
    mov si, [es:bx + 4]
    mov di, [es:bx + 6]
    call gfx_clip_add
    add bx, 8
    inc word [.i]
    jmp .add
.done:
    popa
    ret
.i dw 0

; ========================================================================
; surf_clear - fill the whole surface with colour
; IN:  AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_clear:
    pusha
    cmp byte [surf_windowed], 0
    jne .win
    call surf_fs_clear
    popa
    ret
.win:
    xor cx, cx
    xor dx, dx
    mov si, [surf_w]
    mov di, [surf_h]
    call surf_fill_rect
    popa
    ret

; ========================================================================
; surf_fs_clear - fill the whole 640x480 screen with colour AL
; IN:  AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_fs_clear:
    pusha
    push es
    and al, 0x0F
    mov bl, al
    mov dx, 0x3CE
    mov al, 0
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    mov dx, 0x3CE
    mov al, 1
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    mov dx, 0x3CE
    mov al, 3
    out dx, al
    inc dx
    xor al, al
    out dx, al
    mov dx, 0x3CE
    mov al, 8
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 19200
    xor ax, ax
    cld
    rep stosw
    mov dx, 0x3CE
    mov al, 1
    out dx, al
    inc dx
    xor al, al
    out dx, al
    pop es
    popa
    ret

; ========================================================================
; surf_hline - horizontal span in surface-relative coords, clipped
; IN:  CX = x1
;      BX = x2
;      DX = y
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_hline:
    pusha
    mov [.col], al
    mov ax, dx
    add ax, [surf_oy]
    cmp ax, [surf_ct]
    jl .skip
    cmp ax, [surf_cb]
    jg .skip
    mov [.y], ax
    mov ax, cx
    add ax, [surf_ox]
    mov [.x1], ax
    mov ax, bx
    add ax, [surf_ox]
    mov [.x2], ax
    mov ax, [.x1]
    mov bx, [.x2]
    cmp ax, bx
    jle .ord
    xchg ax, bx
.ord:
    cmp ax, [surf_cl]
    jge .lok
    mov ax, [surf_cl]
.lok:
    cmp bx, [surf_cr]
    jle .rok
    mov bx, [surf_cr]
.rok:
    cmp ax, bx
    jg .skip
    mov cx, ax
    mov dx, [.y]
    mov al, [.col]
    call gfx_hline
.skip:
    popa
    ret
.col db 0
.x1  dw 0
.x2  dw 0
.y   dw 0

; ========================================================================
; surf_pixel - plot a pixel in surface-relative coords, clipped
; IN:  CX = x
;      DX = y
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_pixel:
    pusha
    mov bx, cx
    call surf_hline
    popa
    ret

; ========================================================================
; surf_vline - vertical span in surface-relative coords, clipped
; IN:  CX = x
;      DX = y1
;      BX = y2
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_vline:
    pusha
    mov [.col], al
    mov [.x], cx
    cmp dx, bx
    jle .ord
    xchg dx, bx
.ord:
    mov [.y], dx
    mov [.y2], bx
.row:
    mov ax, [.y]
    cmp ax, [.y2]
    jg .done
    mov cx, [.x]
    mov bx, cx
    mov dx, [.y]
    mov al, [.col]
    call surf_hline
    inc word [.y]
    jmp .row
.done:
    popa
    ret
.col db 0
.x   dw 0
.y   dw 0
.y2  dw 0

; ========================================================================
; surf_line - straight line between two surface-relative points, clipped
; IN:  CX = x1
;      DX = y1
;      SI = x2
;      DI = y2
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_line:
    pusha
    mov [.col], al
    mov [.x0], cx
    mov [.y0], dx
    mov [.x1], si
    mov [.y1], di

    mov ax, [.x1]
    sub ax, [.x0]
    mov bx, 1
    test ax, ax
    jns .xpos
    neg ax
    mov bx, -1
.xpos:
    mov [.adx], ax
    mov [.sx], bx

    mov ax, [.y1]
    sub ax, [.y0]
    mov bx, 1
    test ax, ax
    jns .ypos
    neg ax
    mov bx, -1
.ypos:
    neg ax
    mov [.ady], ax
    mov [.sy], bx

    mov ax, [.adx]
    add ax, [.ady]
    mov [.err], ax
.step:
    mov cx, [.x0]
    mov dx, [.y0]
    mov al, [.col]
    call surf_pixel

    mov ax, [.x0]
    cmp ax, [.x1]
    jne .move
    mov ax, [.y0]
    cmp ax, [.y1]
    je .done
.move:
    mov ax, [.err]
    add ax, ax
    mov [.e2], ax
    cmp ax, [.ady]
    jl .skipx
    mov ax, [.err]
    add ax, [.ady]
    mov [.err], ax
    mov ax, [.x0]
    add ax, [.sx]
    mov [.x0], ax
.skipx:
    mov ax, [.e2]
    cmp ax, [.adx]
    jg .skipy
    mov ax, [.err]
    add ax, [.adx]
    mov [.err], ax
    mov ax, [.y0]
    add ax, [.sy]
    mov [.y0], ax
.skipy:
    jmp .step
.done:
    popa
    ret
.col db 0
.x0  dw 0
.y0  dw 0
.x1  dw 0
.y1  dw 0
.adx dw 0
.ady dw 0
.sx  dw 0
.sy  dw 0
.err dw 0
.e2  dw 0

; ========================================================================
; surf_visible - is any part of a rectangle actually on screen?
; IN:  CX = x
;      DX = y
;      SI = width
;      DI = height (surface-relative)
; OUT: CF = 1 when at least part of the rectangle can be drawn
; ========================================================================
surf_visible:
    pusha
    add cx, [surf_ox]
    add dx, [surf_oy]
    mov ax, cx
    add ax, si
    dec ax
    mov si, ax
    mov ax, dx
    add ax, di
    dec ax
    mov di, ax

    cmp cx, [surf_cl]
    jge .l_ok
    mov cx, [surf_cl]
.l_ok:
    cmp si, [surf_cr]
    jle .r_ok
    mov si, [surf_cr]
.r_ok:
    cmp dx, [surf_ct]
    jge .t_ok
    mov dx, [surf_ct]
.t_ok:
    cmp di, [surf_cb]
    jle .b_ok
    mov di, [surf_cb]
.b_ok:
    cmp cx, si
    jg .hidden
    cmp dx, di
    jg .hidden

    xor bx, bx
    xor bp, bp
.probe:
    mov al, [gfx_clipn]
    xor ah, ah
    cmp bp, ax
    jae .visible
    cmp cx, [gfx_clip_l + bx]
    jl .next
    cmp si, [gfx_clip_r + bx]
    jg .next
    cmp dx, [gfx_clip_t + bx]
    jl .next
    cmp di, [gfx_clip_b + bx]
    jle .hidden
.next:
    add bx, 2
    inc bp
    jmp .probe
.visible:
    popa
    stc
    ret
.hidden:
    popa
    clc
    ret

; ========================================================================
; surf_begin_paint - hide the mouse pointer while the surface is redrawn
; IN:  nothing
; OUT: nothing (all registers preserved)
; ========================================================================
surf_begin_paint:
    push ax
    push bx
    push cx
    mov ah, 0x20
    int 0x23
    mov [surf_cursor_on], ch
    test ch, ch
    jz .done
    mov ah, 0x22
    int 0x23
.done:
    pop cx
    pop bx
    pop ax
    ret

; ========================================================================
; surf_end_paint - bring the mouse pointer back after surf_begin_paint
; IN:  nothing
; OUT: nothing (all registers preserved)
; ========================================================================
surf_end_paint:
    push ax
    cmp byte [surf_cursor_on], 0
    je .done
    mov ah, 0x23
    int 0x23
.done:
    pop ax
    ret

surf_cursor_on db 0

; ========================================================================
; surf_fill_rect - filled rectangle in surface-relative coords, clipped
; IN:  CX = x
;      DX = y
;      SI = width
;      DI = height
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_fill_rect:
    pusha
    mov [.col], al
    mov [.rx], cx
    mov ax, cx
    add ax, si
    dec ax
    mov [.rx2], ax
    mov [.ry], dx
    mov [.rows], di
.row:
    cmp word [.rows], 0
    jle .done
    mov al, [.col]
    mov cx, [.rx]
    mov bx, [.rx2]
    mov dx, [.ry]
    call surf_hline
    inc word [.ry]
    dec word [.rows]
    jmp .row
.done:
    popa
    ret
.col  db 0
.rx   dw 0
.rx2  dw 0
.ry   dw 0
.rows dw 0

; ========================================================================
; surf_fill_circle - filled circle in surface-relative coords, clipped
; IN:  CX = centre x
;      DX = centre y
;      BX = radius
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_fill_circle:
    pusha
    mov [.col], al
    mov [.cx], cx
    mov [.cy], dx
    mov word [.x], 0
    mov [.y], bx
    mov ax, 1
    sub ax, bx
    mov [.d], ax
.loop:
    mov ax, [.x]
    cmp ax, [.y]
    jg .done
    call .spans
    mov ax, [.d]
    test ax, ax
    js .dneg
    mov ax, [.x]
    sub ax, [.y]
    add ax, ax
    add ax, 5
    add [.d], ax
    dec word [.y]
    jmp .incx
.dneg:
    mov ax, [.x]
    add ax, ax
    add ax, 3
    add [.d], ax
.incx:
    inc word [.x]
    jmp .loop
.done:
    popa
    ret
.spans:
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.x]
    mov bx, [.cx]
    add bx, [.x]
    mov dx, [.cy]
    add dx, [.y]
    call surf_hline
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.x]
    mov bx, [.cx]
    add bx, [.x]
    mov dx, [.cy]
    sub dx, [.y]
    call surf_hline
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    add dx, [.x]
    call surf_hline
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    sub dx, [.x]
    call surf_hline
    ret
.col db 0
.cx  dw 0
.cy  dw 0
.x   dw 0
.y   dw 0
.d   dw 0

; ========================================================================
; surf_print - draw a NUL-terminated string
; IN:  CX = x (top-left, surface-relative)
;      DX = y
;      SI = string pointer
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_print:
    pusha
    call surf_font_get
    mov [.color], al
    mov [.penx], cx
    mov [.peny], dx
    mov [.sptr], si
.ch:
    mov si, [.sptr]
    mov al, [si]
    test al, al
    jz .done
    inc si
    mov [.sptr], si
    cmp al, ' '
    je .advance
    xor ah, ah
    shl ax, 4
    add ax, [surf_font_off]
    mov [.gptr], ax
    mov word [.r], 0
.row:
    cmp word [.r], 16
    jae .advance
    push es
    mov es, [surf_font_seg]
    mov bx, [.gptr]
    add bx, [.r]
    mov al, [es:bx]
    pop es
    mov [.gbyte], al
    mov word [.c], 0
    mov word [.run], SURF_NO_RUN
.col:
    cmp word [.c], 8
    jae .nextrow
    mov cl, [.c]
    mov ah, 0x80
    shr ah, cl
    test [.gbyte], ah
    jz .gap
    cmp word [.run], SURF_NO_RUN
    jne .nextcol
    mov ax, [.c]
    mov [.run], ax
    jmp .nextcol
.gap:
    call .flush
.nextcol:
    inc word [.c]
    jmp .col
.nextrow:
    call .flush
    inc word [.r]
    jmp .row
.advance:
    add word [.penx], 8
    jmp .ch
.done:
    popa
    ret
.flush:
    cmp word [.run], SURF_NO_RUN
    je .flush_ret
    mov cx, [.penx]
    add cx, [.run]
    mov bx, [.penx]
    add bx, [.c]
    dec bx
    mov dx, [.peny]
    add dx, [.r]
    mov al, [.color]
    call surf_hline
    mov word [.run], SURF_NO_RUN
.flush_ret:
    ret
.color db 0
.penx  dw 0
.peny  dw 0
.sptr  dw 0
.gptr  dw 0
.gbyte db 0
.r     dw 0
.c     dw 0
.run   dw 0

; ========================================================================
; surf_font_get - resolve the active 8x16 font once and cache it
; IN:  nothing
; OUT: [surf_font_seg]:[surf_font_off] -> font bitmap
; ========================================================================
surf_font_get:
    cmp byte [surf_font_ready], 0
    jne .ret
    pusha
    push es
    xor ax, ax
    mov es, ax
    mov bp, [es:0x43*4]
    mov ax, [es:0x43*4 + 2]
    mov cx, ax
    or cx, bp
    jnz .have
    mov ax, 0x1130
    mov bh, 0x06
    int 0x10
    mov ax, es
.have:
    mov [surf_font_seg], ax
    mov [surf_font_off], bp
    pop es
    popa
    mov byte [surf_font_ready], 1
.ret:
    ret

surf_font_seg   dw 0
surf_font_off   dw 0
surf_font_ready db 0

SURF_MENU_IH    equ 16

; ========================================================================
; surf_input - sample the mouse into surface-relative state, once per frame
; IN:  nothing
; OUT: [surf_mx]/[surf_my]  = cursor in surface-relative pixels
;      [surf_mb]            = 1 while the left button is held
;      [surf_mpress]        = 1 on the frame the button goes down
;      [surf_mrelease]      = 1 on the frame the button goes up
; ========================================================================
surf_input:
    pusha
    mov ah, 0x20
    int 0x23
    sub ax, [surf_ox]
    mov [surf_mx], ax
    sub bx, [surf_oy]
    mov [surf_my], bx
    and cl, 1
    mov [surf_mb], cl
    mov byte [surf_mpress], 0
    mov byte [surf_mrelease], 0
    mov al, [surf_mb]
    cmp al, [surf_mb_prev]
    je .same
    test al, al
    jz .rel
    mov byte [surf_mpress], 1
    jmp .upd
.rel:
    mov byte [surf_mrelease], 1
.upd:
    mov al, [surf_mb]
    mov [surf_mb_prev], al
.same:
    popa
    ret

; ========================================================================
; surf_in_rect - test the last sampled cursor against a rectangle
; IN:  CX = x, DX = y, SI = width, DI = height (surface-relative)
; OUT: CF = 1 if [surf_mx],[surf_my] lie inside the rectangle
; ========================================================================
surf_in_rect:
    push ax
    push bx
    mov ax, [surf_mx]
    cmp ax, cx
    jb .no
    mov bx, cx
    add bx, si
    cmp ax, bx
    jae .no
    mov ax, [surf_my]
    cmp ax, dx
    jb .no
    mov bx, dx
    add bx, di
    cmp ax, bx
    jae .no
    pop bx
    pop ax
    stc
    ret
.no:
    pop bx
    pop ax
    clc
    ret

; ========================================================================
; surf_text_w - pixel width of a NUL-terminated string in the 8x16 font
; IN:  SI = string pointer
; OUT: AX = width in pixels (length * 8)
; ========================================================================
surf_text_w:
    push si
    push cx
    xor cx, cx
.l:
    cmp byte [si], 0
    je .d
    inc si
    inc cx
    jmp .l
.d:
    mov ax, cx
    shl ax, 3
    pop cx
    pop si
    ret

; ========================================================================
; surf_rect - 1px rectangle outline, surface-relative, clipped
; IN:  CX = x, DX = y, SI = width, DI = height, AL = colour (0..15)
; ========================================================================
surf_rect:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], si
    mov [.h], di
    mov [.col], al
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.w]
    mov di, 1
    mov al, [.col]
    call surf_fill_rect
    mov cx, [.x]
    mov dx, [.y]
    add dx, [.h]
    dec dx
    mov si, [.w]
    mov di, 1
    mov al, [.col]
    call surf_fill_rect
    mov cx, [.x]
    mov dx, [.y]
    mov si, 1
    mov di, [.h]
    mov al, [.col]
    call surf_fill_rect
    mov cx, [.x]
    add cx, [.w]
    dec cx
    mov dx, [.y]
    mov si, 1
    mov di, [.h]
    mov al, [.col]
    call surf_fill_rect
    popa
    ret
.x   dw 0
.y   dw 0
.w   dw 0
.h   dw 0
.col db 0

; ========================================================================
; surf_button - draw a labelled push button with a centred caption
; IN:  CX = x, DX = y, SI = width, DI = height
;      BX = caption pointer, AL = pressed (0 = normal, 1 = held)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_button:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], si
    mov [.h], di
    mov [.lbl], bx
    test al, al
    jz .normal
    mov byte [.bg], 0
    mov byte [.fg], 15
    jmp .draw
.normal:
    mov byte [.bg], 15
    mov byte [.fg], 0
.draw:
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.w]
    mov di, [.h]
    mov al, [.bg]
    call surf_fill_rect
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.w]
    mov di, [.h]
    xor al, al
    call surf_rect
    mov cx, [.x]
    mov dx, [.y]
    mov al, [.bg]
    call surf_pixel
    mov cx, [.x]
    add cx, [.w]
    dec cx
    mov dx, [.y]
    mov al, [.bg]
    call surf_pixel
    mov cx, [.x]
    mov dx, [.y]
    add dx, [.h]
    dec dx
    mov al, [.bg]
    call surf_pixel
    mov cx, [.x]
    add cx, [.w]
    dec cx
    mov dx, [.y]
    add dx, [.h]
    dec dx
    mov al, [.bg]
    call surf_pixel
    mov si, [.lbl]
    call surf_text_w
    mov cx, [.w]
    sub cx, ax
    sar cx, 1
    add cx, [.x]
    mov ax, [.h]
    sub ax, 16
    sar ax, 1
    add ax, [.y]
    mov dx, ax
    mov si, [.lbl]
    mov al, [.fg]
    call surf_print
    popa
    ret
.x   dw 0
.y   dw 0
.w   dw 0
.h   dw 0
.lbl dw 0
.bg  db 0
.fg  db 0

; ========================================================================
; surf_menu - draw a vertical pop-up menu (white box, black frame)
; IN:  CX = x, DX = y (top-left), SI = width, DI = item count
;      BX = pointer to an array of string pointers, AL = highlight index
;           (0xFF for none)
; OUT: nothing (all registers preserved)
; ========================================================================
surf_menu:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], si
    mov [.n], di
    mov [.items], bx
    mov [.hl], al
    mov ax, di
    mov bx, SURF_MENU_IH
    mul bx
    mov [.ph], ax
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.w]
    mov di, [.ph]
    mov al, 15
    call surf_fill_rect
    mov word [.i], 0
.item:
    mov ax, [.i]
    cmp ax, [.n]
    jae .frame
    mov bx, SURF_MENU_IH
    mul bx
    add ax, [.y]
    mov [.iy], ax
    mov al, [.i]
    cmp al, [.hl]
    jne .normal
    mov cx, [.x]
    mov dx, [.iy]
    mov si, [.w]
    mov di, SURF_MENU_IH
    xor al, al
    call surf_fill_rect
    mov byte [.tc], 15
    jmp .text
.normal:
    mov byte [.tc], 0
.text:
    mov ax, [.i]
    add ax, ax
    mov bx, [.items]
    add bx, ax
    mov si, [bx]
    mov cx, [.x]
    add cx, 6
    mov dx, [.iy]
    mov al, [.tc]
    call surf_print
    inc word [.i]
    jmp .item
.frame:
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.w]
    mov di, [.ph]
    xor al, al
    call surf_rect
    popa
    ret
.x     dw 0
.y     dw 0
.w     dw 0
.n     dw 0
.items dw 0
.ph    dw 0
.iy    dw 0
.i     dw 0
.hl    db 0
.tc    db 0

; ========================================================================
; surf_menu_hit - which menu row is under the cursor
; IN:  CX = x, DX = y, SI = width, DI = item count (same as surf_menu)
; OUT: AL = row index under [surf_mx],[surf_my], or 0xFF if outside
; ========================================================================
surf_menu_hit:
    push bx
    push cx
    push dx
    mov ax, [surf_mx]
    cmp ax, cx
    jb .out
    add cx, si
    cmp ax, cx
    jae .out
    mov ax, [surf_my]
    cmp ax, dx
    jb .out
    sub ax, dx
    xor dx, dx
    mov bx, SURF_MENU_IH
    div bx
    cmp ax, di
    jae .out
    pop dx
    pop cx
    pop bx
    ret
.out:
    mov al, 0xFF
    pop dx
    pop cx
    pop bx
    ret

; ========================================================================
; surf_slider - draw a horizontal slider with its knob at the current value
; IN:  CX = x, DX = y, SI = width, DI = height
;      AX = value, BX = minimum, BP = maximum
; OUT: nothing (all registers preserved)
; ========================================================================
surf_slider:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], si
    mov [.h], di
    mov [.val], ax
    mov [.min], bx
    mov [.max], bp

    mov cx, [.x]
    mov ax, [.h]
    shr ax, 1
    add ax, [.y]
    dec ax
    mov dx, ax
    mov si, [.w]
    mov di, 2
    xor al, al
    call surf_fill_rect

    mov ax, [.val]
    sub ax, [.min]
    mov bx, [.w]
    sub bx, SURF_SLIDER_KW
    mul bx
    mov bx, [.max]
    sub bx, [.min]
    test bx, bx
    jz .no_range
    div bx
    jmp .knob
.no_range:
    xor ax, ax
.knob:
    add ax, [.x]
    mov [.kx], ax

    mov cx, [.kx]
    mov dx, [.y]
    mov si, SURF_SLIDER_KW
    mov di, [.h]
    mov al, 15
    call surf_fill_rect
    mov cx, [.kx]
    mov dx, [.y]
    mov si, SURF_SLIDER_KW
    mov di, [.h]
    xor al, al
    call surf_rect

    popa
    ret
.kx  dw 0
.x   dw 0
.y   dw 0
.w   dw 0
.h   dw 0
.val dw 0
.min dw 0
.max dw 0

; ========================================================================
; surf_slider_val - value the cursor points at on a slider
; IN:  CX = x, DX = y, SI = width, DI = height (same as surf_slider)
;      BX = minimum, BP = maximum
; OUT: AX = value under [surf_mx], clamped to the range
;      CF = 1 if the cursor lies on the slider
; ========================================================================
surf_slider_val:
    push cx
    push dx
    push si
    push di
    mov [.min], bx
    mov [.max], bp
    mov [.w], si

    call surf_in_rect
    jnc .outside

    mov ax, [surf_mx]
    sub ax, cx
    sub ax, SURF_SLIDER_KW / 2
    jns .span
    xor ax, ax
.span:
    mov cx, [.w]
    sub cx, SURF_SLIDER_KW
    cmp ax, cx
    jbe .scale
    mov ax, cx
.scale:
    mov bx, [.max]
    sub bx, [.min]
    mul bx
    test cx, cx
    jz .at_min
    div cx
    add ax, [.min]
    pop di
    pop si
    pop dx
    pop cx
    stc
    ret
.at_min:
    mov ax, [.min]
    pop di
    pop si
    pop dx
    pop cx
    stc
    ret
.outside:
    pop di
    pop si
    pop dx
    pop cx
    clc
    ret
.min dw 0
.max dw 0
.w   dw 0

SURF_SLIDER_KW  equ 10

surf_mx       dw 0
surf_my       dw 0
surf_mb       db 0
surf_mb_prev  db 0
surf_mpress   db 0
surf_mrelease db 0

%endif ; SURF_INC