; ========================================================================
; surf.inc - drawing surface that works full-screen or inside a GUI window
; Copyright (C) 2026 PRoX2011
;
; Depends on grafx.inc.
; ========================================================================

%ifndef SURF_INC
%define SURF_INC

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

; ========================================================================
; surf_sync - query the WM for this task's window and update the surface
; IN:  nothing
; OUT: [surf_windowed] = 1 if hosted in a window, else 0
;      [surf_close]    = 1 if the WM asked us to close
;      [surf_dirty]    = 1 if the WM wants a repaint this frame
;      surface origin/size in [surf_ox]/[surf_oy]/[surf_w]/[surf_h]
;
; NOTE: Recomended to call once per frame.
; ========================================================================
surf_sync:
    pusha
    mov ah, 0x31
    int 0x23
    test al, 0x01
    jz .fullscreen
    mov byte [surf_windowed], 1
    test al, 0x02
    jz .nclose
    mov byte [surf_close], 1
.nclose:
    mov byte [surf_dirty], 0
    test al, 0x04
    jz .ndirty
    mov byte [surf_dirty], 1
.ndirty:
    mov [surf_ox], cx
    mov [surf_oy], dx
    mov [surf_w], si
    mov [surf_h], di
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
    popa
    ret

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
    mov cx, [surf_ox]
    mov dx, [surf_oy]
    mov si, [surf_w]
    mov di, [surf_h]
    call gfx_fill_rect
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
.col:
    cmp word [.c], 8
    jae .nextrow
    mov cl, [.c]
    mov ah, 0x80
    shr ah, cl
    test [.gbyte], ah
    jz .nextcol
    mov cx, [.penx]
    add cx, [.c]
    mov dx, [.peny]
    add dx, [.r]
    mov al, [.color]
    call surf_pixel
.nextcol:
    inc word [.c]
    jmp .col
.nextrow:
    inc word [.r]
    jmp .row
.advance:
    add word [.penx], 8
    jmp .ch
.done:
    popa
    ret
.color db 0
.penx  dw 0
.peny  dw 0
.sptr  dw 0
.gptr  dw 0
.gbyte db 0
.r     dw 0
.c     dw 0

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

surf_mx       dw 0
surf_my       dw 0
surf_mb       db 0
surf_mb_prev  db 0
surf_mpress   db 0
surf_mrelease db 0

%endif ; SURF_INC