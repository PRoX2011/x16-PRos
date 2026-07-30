%ifndef WIN_INC
%define WIN_INC

%define WIN_TBAR     18
%define WIN_CLOSE_X  4
%define WIN_CLOSE_Y  4
%define WIN_CLOSE_W  10
%define WIN_BTN_GAP  4
%define WIN_MAX_OFF  (WIN_CLOSE_X + WIN_CLOSE_W + WIN_BTN_GAP + WIN_CLOSE_W)
%define WIN_GRIP     12    ; bottom-right resize grip zone (px)

win_x    dw 0
win_y    dw 0
win_w    dw 0
win_h    dw 0
win_co_x dw 0
win_co_y dw 0
win_cl_l dw 0
win_cl_t dw 0
win_cl_r dw 0
win_cl_b dw 0
win_title dw 0

; ========================================================================
; win_set_context - load the current window geometry
; IN:  AX = win_x
;      BX = win_y
;      CX = win_w
;      DX = win_h
; OUT: nothing; derives the content origin and clip rectangle
; ========================================================================
win_set_context:
    push si
    mov [win_x], ax
    mov [win_y], bx
    mov [win_w], cx
    mov [win_h], dx

    mov si, ax
    inc si
    mov [win_co_x], si
    mov [win_cl_l], si
    mov si, bx
    add si, WIN_TBAR
    mov [win_co_y], si
    mov [win_cl_t], si
    mov si, ax
    add si, cx
    sub si, 2
    mov [win_cl_r], si
    mov si, bx
    add si, dx
    sub si, 2
    mov [win_cl_b], si
    pop si
    ret

; ========================================================================
; win_draw_frame - draw the chrome (title bar, buttons, frame)
; IN:  current window context
; OUT: nothing (all registers preserved)
; ========================================================================
win_draw_frame:
    pusha
    mov cx, [win_x]
    inc cx
    mov dx, [win_y]
    inc dx
    mov si, [win_w]
    sub si, 2
    mov di, WIN_TBAR - 1
    mov al, 15
    call gfx_fill_rect
    call win_draw_stripes
    call win_draw_title
    call win_draw_maxbox
    call win_draw_closebox
    mov al, 0
    mov cx, [win_x]
    mov bx, [win_x]
    add bx, [win_w]
    dec bx
    mov dx, [win_y]
    add dx, WIN_TBAR
    dec dx
    call gfx_hline
    mov al, 0
    mov cx, [win_x]
    mov dx, [win_y]
    mov si, [win_w]
    mov di, [win_h]
    call gfx_rect
    popa
    ret

; ========================================================================
; win_draw_stripes - draw the title bar stripes
; IN:  current window context
; OUT: nothing (all registers preserved)
; ========================================================================
win_draw_stripes:
    pusha
    mov bp, [win_y]
    add bp, 3
.loop:
    mov ax, [win_y]
    add ax, WIN_TBAR
    sub ax, 4
    cmp bp, ax
    jg .done
    mov al, 0
    mov cx, [win_x]
    add cx, 2
    mov bx, [win_x]
    add bx, [win_w]
    sub bx, 3
    mov dx, bp
    call gfx_hline
    add bp, 2
    jmp .loop
.done:
    popa
    ret

; ========================================================================
; win_draw_closebox - draw the close box
; IN:  current window context
; OUT: nothing (all registers preserved)
; ========================================================================
win_draw_closebox:
    pusha
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_CLOSE_X + WIN_CLOSE_W
    mov dx, [win_y]
    add dx, WIN_CLOSE_Y
    mov si, WIN_CLOSE_W
    mov di, WIN_CLOSE_W
    mov al, 15
    call gfx_fill_rect
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_CLOSE_X + WIN_CLOSE_W
    mov dx, [win_y]
    add dx, WIN_CLOSE_Y
    mov si, WIN_CLOSE_W
    mov di, WIN_CLOSE_W
    mov al, 0
    call gfx_rect
    popa
    ret

; ========================================================================
; win_draw_maxbox - draw the maximize box
; IN:  current window context
; OUT: nothing (all registers preserved)
; ========================================================================
win_draw_maxbox:
    pusha
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_MAX_OFF
    mov dx, [win_y]
    add dx, WIN_CLOSE_Y
    mov si, WIN_CLOSE_W
    mov di, WIN_CLOSE_W
    mov al, 15
    call gfx_fill_rect
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_MAX_OFF
    mov dx, [win_y]
    add dx, WIN_CLOSE_Y
    mov si, WIN_CLOSE_W
    mov di, WIN_CLOSE_W
    mov al, 0
    call gfx_rect
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_MAX_OFF
    mov dx, [win_y]
    add dx, WIN_CLOSE_Y
    mov si, WIN_CLOSE_W - 4
    mov di, WIN_CLOSE_W - 4
    mov al, 0
    call gfx_rect
    popa
    ret

; ========================================================================
; win_draw_title - draw prgram name in window title
; IN:  [win_title] = ASCIIZ name (caller DS), or 0 for none
; OUT: nothing (all registers preserved)
; ========================================================================
win_draw_title:
    pusha
    cmp word [win_title], 0
    je .done
    call win_font_get

    mov si, [win_title]
    xor cx, cx
.measure:
    mov al, [si]
    test al, al
    je .measured
    cmp al, '.'
    je .measured
    inc si
    inc cx
    cmp cx, 16
    jl .measure
.measured:
    test cx, cx
    je .done
    mov [.len], cx

    mov ax, cx
    shl ax, 3
    add ax, 4
    mov si, ax
    mov cx, [win_x]
    add cx, 3
    mov dx, [win_y]
    inc dx
    mov di, WIN_TBAR - 2
    mov al, 15
    call gfx_fill_rect

    mov cx, [win_x]
    add cx, 5
    mov [.penx], cx
    mov si, [win_title]
    mov [.sptr], si
    mov word [.i], 0
.ch:
    mov ax, [.i]
    cmp ax, [.len]
    jae .done
    mov si, [.sptr]
    mov al, [si]
    inc si
    mov [.sptr], si
    xor ah, ah
    shl ax, 4
    add ax, [win_font_off]
    mov [.gptr], ax
    mov word [.r], 0
.row:
    cmp word [.r], 16
    jae .nextch
    push es
    mov es, [win_font_seg]
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
    mov dx, [win_y]
    inc dx
    add dx, [.r]
    xor al, al
    call gfx_pixel
.nextcol:
    inc word [.c]
    jmp .col
.nextrow:
    inc word [.r]
    jmp .row
.nextch:
    add word [.penx], 8
    inc word [.i]
    jmp .ch
.done:
    popa
    ret
.len   dw 0
.penx  dw 0
.sptr  dw 0
.gptr  dw 0
.gbyte db 0
.i     dw 0
.r     dw 0
.c     dw 0

; ========================================================================
; win_font_get - resolve the active 8x16 font once and cache it
; IN:  nothing
; OUT: [win_font_seg]:[win_font_off] -> font bitmap
; ========================================================================
win_font_get:
    cmp byte [win_font_ready], 0
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
    mov [win_font_seg], ax
    mov [win_font_off], bp
    pop es
    popa
    mov byte [win_font_ready], 1
.ret:
    ret
win_font_seg   dw 0
win_font_off   dw 0
win_font_ready db 0

; ========================================================================
; win_hline_r - clipped horizontal line in window-relative coords
; IN:  CX = x1
;      BX = x2
;      DX = y
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
win_hline_r:
    pusha
    mov [.col], al
    mov ax, dx
    add ax, [win_co_y]
    cmp ax, [win_cl_t]
    jl .skip
    cmp ax, [win_cl_b]
    jg .skip
    mov [.y], ax
    mov ax, cx
    add ax, [win_co_x]
    mov [.x1], ax
    mov ax, bx
    add ax, [win_co_x]
    mov [.x2], ax
    mov ax, [.x1]
    mov bx, [.x2]
    cmp ax, bx
    jle .ord
    xchg ax, bx
.ord:
    cmp ax, [win_cl_l]
    jge .lok
    mov ax, [win_cl_l]
.lok:
    cmp bx, [win_cl_r]
    jle .rok
    mov bx, [win_cl_r]
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
; win_fill_rect_r - clipped filled rectangle in window-relative coords
; IN:  CX = x
;      DX = y
;      SI = width
;      DI = height
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
win_fill_rect_r:
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
    call win_hline_r
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
; win_fill_circle_r - clipped filled circle in window-relative coords
; IN:  CX = centre x
;      DX = centre y
;      BX = radius
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
win_fill_circle_r:
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
    call win_hline_r
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.x]
    mov bx, [.cx]
    add bx, [.x]
    mov dx, [.cy]
    sub dx, [.y]
    call win_hline_r
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    add dx, [.x]
    call win_hline_r
    mov al, [.col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    sub dx, [.x]
    call win_hline_r
    ret
.col db 0
.cx  dw 0
.cy  dw 0
.x   dw 0
.y   dw 0
.d   dw 0

; ========================================================================
; win_hit_title - is (mouse X / mouse Y) inside the current window's title bar?
; IN:  AX = mouse x
;      BX = mouse y
; OUT: CF = 1 if inside, else 0
; ========================================================================
win_hit_title:
    push cx
    cmp ax, [win_x]
    jl .no
    mov cx, [win_x]
    add cx, [win_w]
    dec cx
    cmp ax, cx
    jg .no
    cmp bx, [win_y]
    jl .no
    mov cx, [win_y]
    add cx, WIN_TBAR
    dec cx
    cmp bx, cx
    jg .no
    pop cx
    stc
    ret
.no:
    pop cx
    clc
    ret

; ========================================================================
; win_hit_close - is (mouse X / mouse Y) inside the current window's close box?
; IN:  AX = mouse x
;      BX = mouse y
; OUT: CF = 1 if inside, else 0
; ========================================================================
win_hit_close:
    push cx
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_CLOSE_X + WIN_CLOSE_W
    cmp ax, cx
    jl .no
    add cx, WIN_CLOSE_W
    dec cx
    cmp ax, cx
    jg .no
    mov cx, [win_y]
    add cx, WIN_CLOSE_Y
    cmp bx, cx
    jl .no
    add cx, WIN_CLOSE_W
    dec cx
    cmp bx, cx
    jg .no
    pop cx
    stc
    ret
.no:
    pop cx
    clc
    ret

; ========================================================================
; win_hit_max - is (mouse X / mouse Y) inside the current window's maximize box?
; IN:  AX = mouse x
;      BX = mouse y
; OUT: CF = 1 if inside, else 0
; ========================================================================
win_hit_max:
    push cx
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_MAX_OFF
    cmp ax, cx
    jl .no
    add cx, WIN_CLOSE_W
    dec cx
    cmp ax, cx
    jg .no
    mov cx, [win_y]
    add cx, WIN_CLOSE_Y
    cmp bx, cx
    jl .no
    add cx, WIN_CLOSE_W
    dec cx
    cmp bx, cx
    jg .no
    pop cx
    stc
    ret
.no:
    pop cx
    clc
    ret

; ========================================================================
; win_hit_resize - is (mouse X / mouse Y) inside the bottom-right corner?
; IN:  AX = mouse x
;      BX = mouse y
; OUT: CF = 1 if inside, else 0
; ========================================================================
win_hit_resize:
    push cx
    mov cx, [win_x]
    add cx, [win_w]
    sub cx, WIN_GRIP
    cmp ax, cx
    jl .no
    mov cx, [win_x]
    add cx, [win_w]
    dec cx
    cmp ax, cx
    jg .no
    mov cx, [win_y]
    add cx, [win_h]
    sub cx, WIN_GRIP
    cmp bx, cx
    jl .no
    mov cx, [win_y]
    add cx, [win_h]
    dec cx
    cmp bx, cx
    jg .no
    pop cx
    stc
    ret
.no:
    pop cx
    clc
    ret

%endif ; WIN_INC
