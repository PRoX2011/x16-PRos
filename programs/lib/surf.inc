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
surf_keys     db 0
surf_mouse_on db 0
surf_key      dw 0

; ========================================================================
; surf_sync - query the WM for this task's window and update the surface
; IN:  nothing
; OUT: [surf_windowed] = 1 if hosted in a window, else 0
;      [surf_close]    = 1 if the WM asked us to close
;      [surf_dirty]    = 1 if the WM wants a repaint this frame
;      [surf_key]      = key of this frame (scan << 8 | ascii, 0 = none)
;                        when the program set [surf_keys] = 1; in a window
;                        the GUI hands keys over while the window is focused
;      surface origin/size in [surf_ox]/[surf_oy]/[surf_w]/[surf_h]
;      the windows covering ours loaded into the grafx clip list
;
; NOTE: Recomended to call once per frame.
; ========================================================================
surf_sync:
    pusha
    push es
    mov word [surf_key], 0
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
    cmp byte [surf_keys], 0
    je .nkeys
    or byte [es:di + WM_E_WANT], WM_W_KEYS
    mov ax, [es:di + WM_E_KEY]
    test ax, ax
    jz .nkeys
    mov word [es:di + WM_E_KEY], 0
    mov [surf_key], ax
.nkeys:
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
    cmp byte [surf_mouse_on], 0
    jne .fs_mouse
    mov byte [surf_mouse_on], 1
    mov ax, 0x2401
    int 0x23
    mov ah, 0x23
    int 0x23
.fs_mouse:
    cmp byte [surf_keys], 0
    je .fs_nkeys
    mov ah, 0x01
    int 0x16
    jz .fs_nkeys
    xor ah, ah
    int 0x16
    mov [surf_key], ax
.fs_nkeys:
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
; surf_idle - give the rest of the frame away (call once per loop); a
;             frame that got a key goes on at once
; IN:  nothing
; OUT: nothing (all registers preserved)
; ========================================================================
surf_idle:
    cmp word [surf_key], 0
    jne .busy
    pusha
    cmp byte [surf_windowed], 0
    je .bios
    mov ah, 0x14
    mov cx, 1
    int 0x23
    popa
    ret
.bios:
    mov ah, 0x86
    xor cx, cx
    mov dx, 20000
    int 0x15
    popa
.busy:
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

; ========================================================================
; surf_vbar - draw the knob of a vertical scroll bar
; IN:  CX = x
;      DX = y
;      DI = bar length in pixels
;      AX = items
;      SI = items shown
;      BP = first item shown
; OUT: nothing (all registers preserved); no knob while all items show
; ========================================================================
surf_vbar:
    pusha
    cmp ax, si
    jbe .done
    call surf_vbar_knob
    add dx, bx
    mov di, ax
    mov si, SURF_VBAR_W
    mov al, 8
    call surf_fill_rect
.done:
    popa
    ret

; ========================================================================
; surf_vbar_grab - start dragging a bar at the cursor
; IN:  as surf_vbar, without CX
; OUT: nothing (all registers preserved)
; ========================================================================
surf_vbar_grab:
    pusha
    call surf_vbar_knob
    mov cx, [surf_my]
    sub cx, dx
    sub cx, bx
    jb .centre
    cmp cx, ax
    jb .keep
.centre:
    shr ax, 1
    mov cx, ax
.keep:
    mov [surf_vbar_off], cx
    popa
    ret

; ========================================================================
; surf_vbar_pos - first item to show while a bar is dragged
; IN:  DX = bar y
;      DI = bar length
;      AX = items
;      SI = items shown
; OUT: AX = first item to show, clamped
; ========================================================================
surf_vbar_pos:
    push bx
    push cx
    push dx
    push di
    push bp
    cmp ax, si
    jbe .zero
    mov cx, ax
    sub cx, si
    xor bp, bp
    call surf_vbar_knob
    sub di, ax
    jz .zero
    mov ax, [surf_my]
    sub ax, dx
    sub ax, [surf_vbar_off]
    jns .above
    xor ax, ax
.above:
    cmp ax, di
    jbe .scale
    mov ax, di
.scale:
    mul cx
    div di
    jmp .out
.zero:
    xor ax, ax
.out:
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    ret

surf_vbar_knob:
    push cx
    push dx
    push di
    mov cx, ax
    mov ax, di
    mul si
    div cx
    cmp ax, 8
    jae .long
    mov ax, 8
.long:
    sub di, ax
    push ax
    sub cx, si
    mov ax, bp
    cmp ax, cx
    jbe .place
    mov ax, cx
.place:
    mul di
    div cx
    mov bx, ax
    pop ax
    pop di
    pop dx
    pop cx
    ret

surf_vbar_off   dw 0
SURF_VBAR_W     equ 6

surf_mx       dw 0
surf_my       dw 0
surf_mb       db 0
surf_mb_prev  db 0
surf_mpress   db 0
surf_mrelease db 0

%ifdef SURF_TEXT

; ========================================================================
; Text field (define SURF_TEXT before including surf.inc)
;
; A field is a SURF_TF_SIZE-byte block, its text a NUL-terminated buffer
; in any segment with lines split by LF. It covers COLS*8+4 x ROWS*16+4
; pixels.
; ========================================================================

SURF_TF_X       equ 0
SURF_TF_Y       equ 2
SURF_TF_COLS    equ 4
SURF_TF_ROWS    equ 6
SURF_TF_SEG     equ 8
SURF_TF_BUF     equ 10
SURF_TF_CAP     equ 12
SURF_TF_LEN     equ 14
SURF_TF_CUR     equ 16
SURF_TF_TOP     equ 18
SURF_TF_LEFT    equ 20
SURF_TF_FLAGS   equ 22
SURF_TF_SIZE    equ 24

SURF_TF_EDIT    equ 0x01
SURF_TF_DRAG    equ 0x40
SURF_TF_CHANGED equ 0x80

; ========================================================================
; surf_tf_init - set up a text field, caret at the end of its text
; surf_te_init - set up an edit field, caret at the start
; IN:  BX = field
;      CX = x
;      DX = y
;      SI = columns
;      DI = rows
;      ES:AX = buffer with a NUL-terminated text, BP = buffer size
; OUT: nothing (all registers preserved)
; ========================================================================
surf_te_init:
    mov byte [bx + SURF_TF_FLAGS], SURF_TF_EDIT
    jmp surf_tf_setup
surf_tf_init:
    mov byte [bx + SURF_TF_FLAGS], 0
surf_tf_setup:
    pusha
    mov [bx + SURF_TF_X], cx
    mov [bx + SURF_TF_Y], dx
    mov [bx + SURF_TF_COLS], si
    mov [bx + SURF_TF_ROWS], di
    mov [bx + SURF_TF_SEG], es
    mov [bx + SURF_TF_BUF], ax
    mov [bx + SURF_TF_CAP], bp
    mov di, ax
    mov cx, bp
    dec cx
    xor al, al
    cld
    repne scasb
    jne .cut
    dec di
.cut:
    mov byte [es:di], 0
    sub di, [bx + SURF_TF_BUF]
    mov [bx + SURF_TF_LEN], di
    test byte [bx + SURF_TF_FLAGS], SURF_TF_EDIT
    jz .caret
    xor di, di
.caret:
    mov [bx + SURF_TF_CUR], di
    mov word [bx + SURF_TF_TOP], 0
    mov word [bx + SURF_TF_LEFT], 0
    popa
    ret

; ========================================================================
; surf_tf_draw - draw a field
; IN:  BX = field
; OUT: nothing (all registers preserved)
; ========================================================================
surf_tf_draw:
    pusha
    push es
    mov es, [bx + SURF_TF_SEG]
    call surf_tf_geom
    mov cx, [bx + SURF_TF_X]
    mov dx, [bx + SURF_TF_Y]
    mov si, [bx + SURF_TF_COLS]
    shl si, 3
    add si, 4
    mov di, [bx + SURF_TF_ROWS]
    shl di, 4
    add di, 4
    mov al, 15
    call surf_fill_rect
    xor al, al
    call surf_rect
    xor bp, bp
.row:
    cmp bp, [surf_tf_tr]
    jae .caret
    mov ax, bp
    add ax, [bx + SURF_TF_TOP]
    call surf_tf_find
    jc .caret
    mov dx, bp
    shl dx, 4
    add dx, [bx + SURF_TF_Y]
    add dx, 2
    test byte [bx + SURF_TF_FLAGS], SURF_TF_EDIT
    jz .text
    inc ax
    call surf_tf_utoa
    push cx
    mov cx, surf_tf_num + 5
    sub cx, si
    shl cx, 3
    neg cx
    add cx, [surf_tf_tx]
    sub cx, 4
    mov al, 8
    call surf_print
    pop cx
.text:
    mov si, di
    add si, [bx + SURF_TF_LEFT]
    sub cx, [bx + SURF_TF_LEFT]
    jbe .next
    cmp cx, [surf_tf_tc]
    jbe .copy
    mov cx, [surf_tf_tc]
.copy:
    mov di, surf_tf_row
.ch:
    mov al, [es:si]
    inc si
    cmp al, ' '
    jae .put
    mov al, ' '
.put:
    mov [di], al
    inc di
    loop .ch
    mov byte [di], 0
    mov cx, [surf_tf_tx]
    mov si, surf_tf_row
    xor al, al
    call surf_print
.next:
    inc bp
    jmp .row
.caret:
    call surf_tf_where
    sub ax, [bx + SURF_TF_TOP]
    sub dx, [bx + SURF_TF_LEFT]
    cmp ax, [surf_tf_tr]
    jae .bar
    cmp dx, [surf_tf_tc]
    ja .bar
    shl dx, 3
    add dx, [surf_tf_tx]
    dec dx
    mov cx, dx
    shl ax, 4
    add ax, [bx + SURF_TF_Y]
    add ax, 2
    mov dx, ax
    mov si, 2
    mov di, 16
    xor al, al
    call surf_fill_rect
.bar:
    call surf_tf_bar
    mov bp, [bx + SURF_TF_TOP]
    call surf_vbar
.done:
    pop es
    popa
    ret

; ========================================================================
; surf_tf_key - edit the text or move the caret, then redraw the field
; IN:  BX = field
;      AX = key (scan << 8 | ascii)
; OUT: CF = 1 if the field took the key (Enter only in a multi-line field)
; ========================================================================
surf_tf_key:
    pusha
    push es
    mov es, [bx + SURF_TF_SEG]
    mov si, [bx + SURF_TF_CUR]
    cmp al, 8
    je .bs
    cmp al, 13
    je .enter
    test al, al
    jz .ext
    cmp al, 0xE0
    je .ext
    cmp al, ' '
    jb .no
.ins:
    mov cx, [bx + SURF_TF_LEN]
    inc cx
    cmp cx, [bx + SURF_TF_CAP]
    jae .done
    mov di, [bx + SURF_TF_BUF]
    add di, cx
    sub cx, si
    push si
    lea si, [di - 1]
    push ds
    push es
    pop ds
    std
    rep movsb
    cld
    pop ds
    pop si
    mov di, [bx + SURF_TF_BUF]
    add di, si
    mov [es:di], al
    inc word [bx + SURF_TF_LEN]
    inc si
    jmp .changed
.bs:
    test si, si
    jz .done
    dec si
    jmp .del
.enter:
    mov al, 10
    test byte [bx + SURF_TF_FLAGS], SURF_TF_EDIT
    jnz .ins
    cmp word [bx + SURF_TF_ROWS], 1
    ja .ins
    jmp .no
.ext:
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp ah, 0x53
    je .del_key
    push ax
    call surf_tf_where
    mov cx, ax
    pop ax
    cmp ah, 0x47
    je .home
    cmp ah, 0x4F
    je .end
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    jne .no
    inc cx
    jmp .go
.up:
    jcxz .done
    dec cx
    jmp .go
.home:
    xor dx, dx
    jmp .go
.end:
    mov dx, 0xFFFF
.go:
    mov ax, cx
    call surf_tf_find
    jc .done
    cmp dx, cx
    jbe .col
    mov dx, cx
.col:
    mov si, di
    sub si, [bx + SURF_TF_BUF]
    add si, dx
    jmp .done
.left:
    test si, si
    jz .done
    dec si
    jmp .done
.right:
    cmp si, [bx + SURF_TF_LEN]
    jae .done
    inc si
    jmp .done
.del_key:
    cmp si, [bx + SURF_TF_LEN]
    jae .done
.del:
    mov di, [bx + SURF_TF_BUF]
    add di, si
    mov cx, [bx + SURF_TF_LEN]
    sub cx, si
    push si
    lea si, [di + 1]
    push ds
    push es
    pop ds
    rep movsb
    pop ds
    pop si
    dec word [bx + SURF_TF_LEN]
.changed:
    or byte [bx + SURF_TF_FLAGS], SURF_TF_CHANGED
.done:
    mov [bx + SURF_TF_CUR], si
    call surf_tf_follow
    call surf_begin_paint
    call surf_tf_draw
    call surf_end_paint
    pop es
    popa
    stc
    ret
.no:
    pop es
    popa
    clc
    ret

; ========================================================================
; surf_tf_click - put the caret where a field was clicked, drag its bar
; IN:  BX = field
; OUT: CF = 1 if the field reacted
; ========================================================================
surf_tf_click:
    pusha
    push es
    mov es, [bx + SURF_TF_SEG]
    call surf_tf_geom
    call surf_tf_bar
    test byte [bx + SURF_TF_FLAGS], SURF_TF_DRAG
    jz .press
    cmp byte [surf_mb], 0
    jne .scroll
    and byte [bx + SURF_TF_FLAGS], ~SURF_TF_DRAG & 0xFF
    jmp .no
.press:
    cmp byte [surf_mpress], 0
    je .no
    cmp ax, si
    jbe .text
    push si
    mov si, SURF_VBAR_W + 2
    dec cx
    call surf_in_rect
    inc cx
    pop si
    jnc .text
    or byte [bx + SURF_TF_FLAGS], SURF_TF_DRAG
    mov bp, [bx + SURF_TF_TOP]
    call surf_vbar_grab
.scroll:
    call surf_vbar_pos
    cmp ax, [bx + SURF_TF_TOP]
    je .yes
    mov [bx + SURF_TF_TOP], ax
    jmp .paint
.text:
    mov cx, [surf_tf_tx]
    mov dx, [bx + SURF_TF_Y]
    add dx, 2
    mov si, [surf_tf_tc]
    shl si, 3
    mov di, [surf_tf_tr]
    shl di, 4
    call surf_in_rect
    jnc .no
    mov ax, [surf_my]
    sub ax, dx
    shr ax, 4
    add ax, [bx + SURF_TF_TOP]
    mov dx, [surf_mx]
    sub dx, cx
    add dx, 4
    shr dx, 3
    add dx, [bx + SURF_TF_LEFT]
.find:
    call surf_tf_find
    jnc .found
    dec ax
    jmp .find
.found:
    cmp dx, cx
    jbe .col
    mov dx, cx
.col:
    sub di, [bx + SURF_TF_BUF]
    add di, dx
    mov [bx + SURF_TF_CUR], di
.paint:
    call surf_begin_paint
    call surf_tf_draw
    call surf_end_paint
.yes:
    pop es
    popa
    stc
    ret
.no:
    pop es
    popa
    clc
    ret

; surf_tf_geom - text x, visible columns and rows, line count
surf_tf_geom:
    push ax
    push cx
    push dx
    push si
    push di
    mov di, [bx + SURF_TF_BUF]
    mov cx, [bx + SURF_TF_LEN]
    mov dx, 1
    mov al, 10
    cld
.count:
    jcxz .counted
    repne scasb
    jne .counted
    inc dx
    jmp .count
.counted:
    mov [surf_tf_lines], dx
    mov ax, [bx + SURF_TF_X]
    add ax, 2
    mov cx, [bx + SURF_TF_COLS]
    test byte [bx + SURF_TF_FLAGS], SURF_TF_EDIT
    jz .set
    push ax
    mov ax, dx
    mov di, 10
    xor si, si
.digit:
    inc si
    xor dx, dx
    div di
    test ax, ax
    jnz .digit
    pop ax
    sub cx, si
    dec cx
    shl si, 3
    add ax, si
    add ax, 4
    mov dx, [surf_tf_lines]
    cmp dx, [bx + SURF_TF_ROWS]
    jbe .set
    dec cx
.set:
    mov [surf_tf_tx], ax
    cmp cx, 1
    jge .cols
    mov cx, 1
.cols:
    mov [surf_tf_tc], cx
    mov ax, [bx + SURF_TF_ROWS]
    mov [surf_tf_tr], ax
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret

; surf_tf_bar - the field's scroll bar for surf_vbar / surf_vbar_pos
surf_tf_bar:
    mov cx, [bx + SURF_TF_COLS]
    shl cx, 3
    add cx, [bx + SURF_TF_X]
    sub cx, 5
    mov dx, [bx + SURF_TF_Y]
    add dx, 2
    mov di, [surf_tf_tr]
    shl di, 4
    mov ax, [surf_tf_lines]
    mov si, [surf_tf_tr]
    ret

; surf_tf_follow - scroll so the caret is in view
surf_tf_follow:
    push ax
    push dx
    call surf_tf_geom
    call surf_tf_where
    cmp ax, [bx + SURF_TF_TOP]
    jae .low
    mov [bx + SURF_TF_TOP], ax
.low:
    sub ax, [surf_tf_tr]
    jb .side
    inc ax
    cmp ax, [bx + SURF_TF_TOP]
    jbe .side
    mov [bx + SURF_TF_TOP], ax
.side:
    cmp dx, [bx + SURF_TF_LEFT]
    jae .right
    mov [bx + SURF_TF_LEFT], dx
.right:
    sub dx, [surf_tf_tc]
    jb .done
    inc dx
    cmp dx, [bx + SURF_TF_LEFT]
    jbe .done
    mov [bx + SURF_TF_LEFT], dx
.done:
    pop dx
    pop ax
    ret

; surf_tf_where - OUT: AX = caret line, DX = caret column
surf_tf_where:
    push cx
    push si
    push di
    mov di, [bx + SURF_TF_BUF]
    mov cx, [bx + SURF_TF_CUR]
    mov si, di
    xor dx, dx
    mov al, 10
    cld
.next:
    jcxz .done
    repne scasb
    jne .done
    inc dx
    mov si, di
    jmp .next
.done:
    mov ax, [bx + SURF_TF_BUF]
    add ax, [bx + SURF_TF_CUR]
    sub ax, si
    xchg ax, dx
    pop di
    pop si
    pop cx
    ret

; surf_tf_find - IN: AX = line. OUT: DI = where it starts, CX = its
; length, CF = 1 if there is no such line
surf_tf_find:
    push ax
    push dx
    mov dx, ax
    mov di, [bx + SURF_TF_BUF]
    mov cx, [bx + SURF_TF_LEN]
    mov al, 10
    cld
.skip:
    test dx, dx
    jz .at
    jcxz .none
    repne scasb
    jne .none
    dec dx
    jmp .skip
.at:
    push di
    jcxz .len
    repne scasb
    jne .len
    dec di
.len:
    mov cx, di
    pop di
    sub cx, di
    clc
    jmp .out
.none:
    stc
.out:
    pop dx
    pop ax
    ret

; surf_tf_utoa - IN: AX = number. OUT: SI = its digits
surf_tf_utoa:
    push ax
    push cx
    push dx
    mov si, surf_tf_num + 5
    mov byte [si], 0
    mov cx, 10
.digit:
    xor dx, dx
    div cx
    add dl, '0'
    dec si
    mov [si], dl
    test ax, ax
    jnz .digit
    pop dx
    pop cx
    pop ax
    ret

surf_tf_tx    dw 0
surf_tf_tc    dw 0
surf_tf_tr    dw 0
surf_tf_lines dw 0
surf_tf_num   times 6 db 0
surf_tf_row   times 82 db 0

%endif ; SURF_TEXT

%ifdef SURF_PICK

SURF_PICK_ROWS  equ 10
SURF_PICK_PATH  equ 64

; ========================================================================
; surf_pick - pick a file in a window
; IN:  SI = title
;      DI = path buffer, SURF_PICK_PATH bytes
; OUT: CF = 0 - DI holds the path from the current folder, e.g. NOTE.TXT,
;               DOCS.DIR/NOTE.TXT or ../NOTE.TXT (see surf_path_go)
;      CF = 1 - cancelled
; ========================================================================
surf_pick:
    pusha
    push es
    push ds
    pop es
    mov [.title], si
    mov [.out], di
    mov byte [.dir], 0
    mov byte [.nm], 0
    mov ah, 0x0E
    int 0x22
.reload:
    mov ah, 0x01
    mov si, surf_pick_list
    int 0x22
    jnc .listed
    xor dx, dx
.listed:
    mov [.count], dx
    xor ax, ax
    mov [.sel], ax
    mov [.top], ax
    dec ax
    mov [.clicked], ax
.redraw:
    call .draw
.loop:
    call surf_idle
    call surf_sync
    cmp byte [surf_close], 0
    jne .cancel
    cmp byte [surf_dirty], 0
    jne .redraw
    call surf_input
    mov ax, [surf_key]
    mov cx, [.sel]
    cmp al, 27
    je .cancel
    cmp al, 13
    je .enter
    cmp ax, 0x4800
    je .up
    cmp ax, 0x48E0
    je .up
    cmp ax, 0x5000
    je .down
    cmp ax, 0x50E0
    je .down
    test ax, ax
    jz .mouse
    mov bx, .field
    call surf_tf_key
.mouse:
    call .bar
    cmp byte [.drag], 0
    je .press
    cmp byte [surf_mb], 0
    je .undrag
    call surf_vbar_pos
    cmp ax, [.top]
    je .loop
    mov [.top], ax
    jmp .redraw
.undrag:
    mov byte [.drag], 0
    jmp .loop
.press:
    cmp byte [surf_mpress], 0
    je .loop
    push si
    mov si, SURF_VBAR_W + 2
    dec cx
    call surf_in_rect
    inc cx
    pop si
    jnc .list
    mov byte [.drag], 1
    mov bp, [.top]
    call surf_vbar_grab
    call surf_vbar_pos
    mov [.top], ax
    jmp .redraw
.list:
    mov cx, [.x]
    add cx, 8
    mov dx, [.y]
    add dx, 24
    mov si, 18 * 8
    mov di, [.rows]
    shl di, 4
    call surf_in_rect
    jnc .loop
    mov cx, [surf_my]
    sub cx, dx
    shr cx, 4
    add cx, [.top]
    cmp cx, [.count]
    ja .loop
    cmp cx, [.clicked]
    je .enter
    mov [.clicked], cx
    jmp .pick
.up:
    test cx, cx
    jz .loop
    dec cx
    jmp .pick
.down:
    cmp cx, [.count]
    jae .loop
    inc cx
.pick:
    mov [.sel], cx
    cmp cx, [.top]
    jae .pick_low
    mov [.top], cx
.pick_low:
    sub cx, [.rows]
    jb .pick_name
    inc cx
    cmp cx, [.top]
    jbe .pick_name
    mov [.top], cx
.pick_name:
    mov ax, [.sel]
    mov di, .nm
    call .entry
    jmp .redraw
.enter:
    mov si, .nm
    cmp byte [si], 0
    je .loop
    call .dir_end
    cmp word [si], '..'
    jne .folder
    mov ah, 0x0A
    int 0x22
    call .dir_up
    jmp .opened
.folder:
    mov ah, 0x0D
    int 0x22
    jc .chosen
    cmp di, .dir + SURF_PICK_PATH - 28
    ja .loop
    mov ah, 0x09
    int 0x22
    jc .loop
.append:
    lodsb
    test al, al
    jz .appended
    stosb
    jmp .append
.appended:
    mov word [di], '/'
.opened:
    mov byte [.nm], 0
    jmp .reload
.chosen:
    mov si, .dir
    mov di, [.out]
.out_dir:
    lodsb
    test al, al
    jz .out_name
    stosb
    jmp .out_dir
.out_name:
    mov si, .nm
.out_ch:
    lodsb
    stosb
    test al, al
    jnz .out_ch
    mov ah, 0x0F
    int 0x22
    pop es
    popa
    clc
    ret
.cancel:
    mov ah, 0x0F
    int 0x22
    pop es
    popa
    stc
    ret

.dir_end:
    mov di, .dir
.dir_scan:
    cmp byte [di], 0
    je .dir_found
    inc di
    jmp .dir_scan
.dir_found:
    ret

.dir_up:
    mov bx, di
    cmp di, .dir
    je .up_add
    dec di
.up_back:
    cmp di, .dir
    je .up_cut
    cmp byte [di - 1], '/'
    je .up_cut
    dec di
    jmp .up_back
.up_cut:
    cmp word [di], '..'
    je .up_add
    mov byte [di], 0
    ret
.up_add:
    cmp bx, .dir + SURF_PICK_PATH - 20
    ja .up_done
    mov word [bx], '..'
    mov word [bx + 2], '/'
.up_done:
    ret

.entry:
    push cx
    push dx
    test ax, ax
    jnz .listed_entry
    mov word [di], '..'
    mov byte [di + 2], 0
    jmp .entry_out
.listed_entry:
    dec ax
    mov dx, 18
    mul dx
    add ax, surf_pick_list
    mov si, ax
    mov cx, 8
    call .part
    add si, 9
    cmp byte [si], ' '
    je .entry_end
    mov al, '.'
    stosb
    mov cx, 3
    call .part
.entry_end:
    mov byte [di], 0
.entry_out:
    pop dx
    pop cx
    ret
.part:
    push si
.part_ch:
    lodsb
    cmp al, ' '
    je .part_end
    stosb
    loop .part_ch
.part_end:
    pop si
    ret

.draw:
    mov ax, [surf_h]
    sub ax, 72
    sar ax, 4
    cmp ax, SURF_PICK_ROWS
    jle .rows_max
    mov ax, SURF_PICK_ROWS
.rows_max:
    cmp ax, 1
    jge .rows_min
    mov ax, 1
.rows_min:
    mov [.rows], ax
    mov cx, [.count]
    inc cx
    sub cx, ax
    jge .top_max
    xor cx, cx
.top_max:
    cmp [.top], cx
    jle .in_view
    mov [.top], cx
.in_view:
    shl ax, 4
    add ax, 64
    mov di, ax
    mov si, 18 * 8 + 16
    mov cx, [surf_w]
    sub cx, si
    sar cx, 1
    mov [.x], cx
    mov dx, [surf_h]
    sub dx, di
    sar dx, 1
    jns .y_ok
    xor dx, dx
.y_ok:
    mov [.y], dx
    call surf_begin_paint
    mov al, 15
    call surf_fill_rect
    xor al, al
    call surf_rect
    add cx, 8
    add dx, 4
    mov si, [.title]
    call surf_print
    add dx, 20
    mov bp, [.top]
.item:
    cmp bp, [.count]
    ja .name_line
    mov ax, bp
    sub ax, [.top]
    cmp ax, [.rows]
    jae .name_line
    mov ax, bp
    mov di, .one
    call .entry
    mov si, .one
    xor al, al
    cmp bp, [.sel]
    jne .item_text
    push si
    mov si, 18 * 8
    mov di, 16
    call surf_fill_rect
    pop si
    mov al, 15
.item_text:
    call surf_print
    add dx, 16
    inc bp
    jmp .item
.name_line:
    call .bar
    mov bp, [.top]
    call surf_vbar
    mov cx, [.x]
    add cx, 8
    mov dx, [.rows]
    shl dx, 4
    add dx, [.y]
    add dx, 32
    mov bx, .field
    mov si, 12
    mov di, 1
    mov ax, .nm
    mov bp, 13
    call surf_tf_init
    call surf_tf_draw
    call surf_end_paint
    ret

.bar:
    mov cx, [.x]
    add cx, 18 * 8 + 9
    mov dx, [.y]
    add dx, 24
    mov di, [.rows]
    shl di, 4
    mov ax, [.count]
    inc ax
    mov si, [.rows]
    ret

.title  dw 0
.out    dw 0
.clicked dw 0
.drag   db 0
.dir    times SURF_PICK_PATH db 0
.nm     times 13 db 0
.count  dw 0
.sel    dw 0
.top    dw 0
.rows   dw 0
.x      dw 0
.y      dw 0
.one    times 13 db 0
.field  times SURF_TF_SIZE db 0

surf_pick_list times 8190 db 0

; ========================================================================
; surf_path_go - enter the folders of a path from surf_pick
; IN:  SI = path
; OUT: SI = the file name in it
;      CF = 1 if a folder is missing
;      on CF = 0 the caller works with the file and then calls
;      surf_path_back; on CF = 1 the old folder is already back
; ========================================================================
surf_path_go:
    push ax
    push di
    mov ah, 0x0E
    int 0x22
.next:
    mov di, si
.find:
    mov al, [di]
    test al, al
    jz .name
    inc di
    cmp al, '/'
    jne .find
    mov byte [di - 1], 0
    cmp word [si], '..'
    jne .into
    mov ah, 0x0A
    int 0x22
    jmp .entered
.into:
    mov ah, 0x09
    int 0x22
    jc .missing
.entered:
    mov byte [di - 1], '/'
    mov si, di
    jmp .next
.missing:
    mov byte [di - 1], '/'
    mov ah, 0x0F
    int 0x22
    pop di
    pop ax
    stc
    ret
.name:
    pop di
    pop ax
    clc
    ret

; ========================================================================
; surf_path_back - back to the folder surf_path_go started from
; IN:  nothing
; OUT: nothing
; ========================================================================
surf_path_back:
    push ax
    mov ah, 0x0F
    int 0x22
    pop ax
    ret

%endif ; SURF_PICK

%endif ; SURF_INC