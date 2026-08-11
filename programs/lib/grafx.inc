; ========================================================================
; grafx.inc - 2D primitives drawing for VGA mode 0x12 (640x480x16)
; Copyright (C) 2026 PRoX2011
; ========================================================================

%ifndef GRAFX_INC
%define GRAFX_INC

; ========================================================================
; gfx_pixel - plot a single pixel
; IN:  CX = x
;      DX = y
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_pixel:
    mov [gfx_px_col], al
    pusha
    push es
    pushf
    cli

    mov ax, 0xA000
    mov es, ax

    mov ax, dx
    mov bx, 80
    mul bx
    mov bx, cx
    mov cl, bl
    and cl, 7
    shr bx, 3
    add ax, bx
    mov di, ax
    mov bh, 0x80
    shr bh, cl

    mov dx, 0x3CE
    xor al, al
    out dx, al
    inc dx
    mov al, [gfx_px_col]
    and al, 0x0F
    out dx, al
    dec dx
    mov al, 0x01
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    cmp byte [gfx_xor], 0
    je .fn
    mov al, 0x18
.fn:
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
    mov al, bh
    out dx, al

    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    mov al, [es:di]
    mov [es:di], al

    call gfx_reset_sr
    popf
    pop es
    popa
    ret
gfx_px_col db 0

; ========================================================================
; gfx_plot_cur - plot (CX,DX) in the cached colour [gfx_col]
; IN:  CX = x
;      DX = y
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_plot_cur:
    push ax
    mov al, [gfx_col]
    call gfx_pixel
    pop ax
    ret

gfx_col db 0
gfx_xor db 0

; ========================================================================
; gfx_reset_sr - restore the GC to plain CPU writes (Enable Set/Reset = 0)
; IN:  nothing
; OUT: nothing
; ========================================================================
gfx_reset_sr:
    push ax
    push dx
    mov dx, 0x3CE
    mov al, 0x01
    out dx, al
    inc dx
    xor al, al
    out dx, al
    pop dx
    pop ax
    ret

; ========================================================================
; gfx_hl_putmask - write one Bit-Mask'd byte of the current Set/Reset colour
; IN:  AH    = bit mask
;      ES:DI = byte offset in VRAM
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_hl_putmask:
    push ax
    push dx
    mov dx, 0x3CE
    mov al, 0x08
    out dx, al
    inc dx
    mov al, ah
    out dx, al
    mov al, [es:di]
    mov [es:di], al
    pop dx
    pop ax
    ret

; ========================================================================
; gfx_hline - horizontal span on one row, inclusive
; IN:  CX = x1
;      BX = x2
;      DX = y
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_hline:
    mov [gfx_hl_col], al
    pusha
    push es
    pushf
    cli

    cmp cx, bx
    jle .ord
    xchg cx, bx
.ord:
    mov ax, 0xA000
    mov es, ax

    mov ax, dx
    mov si, 80
    mul si
    mov bp, ax

    mov dx, 0x3CE
    xor al, al
    out dx, al
    inc dx
    mov al, [gfx_hl_col]
    and al, 0x0F
    out dx, al
    dec dx
    mov al, 0x01
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    cmp byte [gfx_xor], 0
    je .fn
    mov al, 0x18
.fn:
    mov [gfx_hl_fn], al
    out dx, al
    dec dx
    mov al, 0x05
    out dx, al
    inc dx
    xor al, al
    out dx, al
    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    mov ax, cx
    mov si, ax
    shr si, 3
    and ax, 7
    mov cl, al
    mov al, 0xFF
    shr al, cl
    mov [gfx_hl_lmask], al

    mov ax, bx
    mov di, ax
    shr di, 3
    and ax, 7
    mov cl, 7
    sub cl, al
    mov al, 0xFF
    shl al, cl
    mov [gfx_hl_rmask], al

    mov [gfx_hl_b1], si
    mov [gfx_hl_b2], di

    cmp si, di
    jne .multi

    mov al, [gfx_hl_lmask]
    and al, [gfx_hl_rmask]
    mov ah, al
    mov di, si
    add di, bp
    call gfx_hl_putmask
    jmp .restore

.multi:
    mov al, [gfx_hl_lmask]
    mov ah, al
    mov di, [gfx_hl_b1]
    add di, bp
    call gfx_hl_putmask

    mov ax, [gfx_hl_b2]
    sub ax, [gfx_hl_b1]
    dec ax
    jbe .rightp
    mov cx, ax
    mov dx, 0x3CE
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    mov di, [gfx_hl_b1]
    inc di
    add di, bp
    cmp byte [gfx_hl_fn], 0
    jne .midxor
    cld
    xor al, al
    rep stosb
    jmp .rightp
.midxor:
    mov al, [es:di]
    mov [es:di], al
    inc di
    loop .midxor

.rightp:
    mov al, [gfx_hl_rmask]
    mov ah, al
    mov di, [gfx_hl_b2]
    add di, bp
    call gfx_hl_putmask

.restore:
    call gfx_reset_sr
    popf
    pop es
    popa
    ret

gfx_hl_col   db 0
gfx_hl_fn    db 0
gfx_hl_lmask db 0
gfx_hl_rmask db 0
gfx_hl_b1    dw 0
gfx_hl_b2    dw 0

; ========================================================================
; gfx_line - Draw line
; IN:  CX = x1
;      DX = y1
;      SI = x2
;      DI = y2
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_line:
    pusha
    mov [gfx_col], al
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
    call gfx_plot_cur

    mov ax, [.x0]
    cmp ax, [.x1]
    jne .move
    mov ax, [.y0]
    cmp ax, [.y1]
    je .fin

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

.fin:
    popa
    ret

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
; gfx_rect - rectangle outline
; IN:  CX = x
;      DX = y
;      SI = width
;      DI = height
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_rect:
    pusha
    mov [gfx_col], al
    mov [.x], cx
    mov [.y], dx
    mov ax, cx
    add ax, si
    dec ax
    mov [.x2], ax
    mov ax, dx
    add ax, di
    dec ax
    mov [.y2], ax

    mov al, [gfx_col]
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.x2]
    mov di, [.y]
    call gfx_line

    mov al, [gfx_col]
    mov cx, [.x]
    mov dx, [.y2]
    mov si, [.x2]
    mov di, [.y2]
    call gfx_line

    mov al, [gfx_col]
    mov cx, [.x]
    mov dx, [.y]
    mov si, [.x]
    mov di, [.y2]
    call gfx_line

    mov al, [gfx_col]
    mov cx, [.x2]
    mov dx, [.y]
    mov si, [.x2]
    mov di, [.y2]
    call gfx_line
    popa
    ret

.x  dw 0
.y  dw 0
.x2 dw 0
.y2 dw 0

; ========================================================================
; gfx_fill_rect - filled rectangle
; IN:  CX = x
;      DX = y
;      SI = width
;      DI = height
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_fill_rect:
    pusha
    mov [gfx_col], al
    mov [.x1], cx
    mov ax, cx
    add ax, si
    dec ax
    mov [.x2], ax
    mov [.rows], di
.row:
    cmp word [.rows], 0
    jle .done
    mov al, [gfx_col]
    mov cx, [.x1]
    mov bx, [.x2]
    call gfx_hline
    inc dx
    dec word [.rows]
    jmp .row
.done:
    popa
    ret

.x1   dw 0
.x2   dw 0
.rows dw 0

; ========================================================================
; gfx_circle - circle outline
; IN:  CX = centre x
;      DX = centre y
;      BX = radius
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_circle:
    pusha
    mov [gfx_col], al
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
    call .plot8
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

.plot8:
    mov cx, [.cx]
    add cx, [.x]
    mov dx, [.cy]
    add dx, [.y]
    call gfx_plot_cur
    mov cx, [.cx]
    sub cx, [.x]
    mov dx, [.cy]
    add dx, [.y]
    call gfx_plot_cur
    mov cx, [.cx]
    add cx, [.x]
    mov dx, [.cy]
    sub dx, [.y]
    call gfx_plot_cur
    mov cx, [.cx]
    sub cx, [.x]
    mov dx, [.cy]
    sub dx, [.y]
    call gfx_plot_cur
    mov cx, [.cx]
    add cx, [.y]
    mov dx, [.cy]
    add dx, [.x]
    call gfx_plot_cur
    mov cx, [.cx]
    sub cx, [.y]
    mov dx, [.cy]
    add dx, [.x]
    call gfx_plot_cur
    mov cx, [.cx]
    add cx, [.y]
    mov dx, [.cy]
    sub dx, [.x]
    call gfx_plot_cur
    mov cx, [.cx]
    sub cx, [.y]
    mov dx, [.cy]
    sub dx, [.x]
    call gfx_plot_cur
    ret

.cx dw 0
.cy dw 0
.x  dw 0
.y  dw 0
.d  dw 0

; ========================================================================
; gfx_fill_circle - filled circle
; IN:  CX = centre x
;      DX = centre y
;      BX = radius
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_fill_circle:
    pusha
    mov [gfx_col], al
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
    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.x]
    mov bx, [.cx]
    add bx, [.x]
    mov dx, [.cy]
    add dx, [.y]
    call gfx_hline
    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.x]
    mov bx, [.cx]
    add bx, [.x]
    mov dx, [.cy]
    sub dx, [.y]
    call gfx_hline
    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    add dx, [.x]
    call gfx_hline
    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.y]
    mov bx, [.cx]
    add bx, [.y]
    mov dx, [.cy]
    sub dx, [.x]
    call gfx_hline
    ret

.cx dw 0
.cy dw 0
.x  dw 0
.y  dw 0
.d  dw 0

; ========================================================================
; gfx_fill_ellipse - filled axis-aligned ellipse
; IN:  CX = centre x
;      DX = centre y
;      SI = x radius
;      DI = y radius
;      AL = colour (0..15)
; OUT: nothing (all registers preserved)
; ========================================================================
gfx_fill_ellipse:
    pusha
    mov [gfx_col], al
    mov [.cx], cx
    mov [.cy], dx
    mov [.rx], si
    mov [.ry], di
    mov ax, di
    mul di
    mov [.ry2], ax
    mov word [.dy], 0
.row:
    mov ax, [.dy]
    cmp ax, [.ry]
    jg .done
    mul ax
    mov bx, ax
    mov ax, [.ry2]
    sub ax, bx
    call gfx_isqrt
    mov bx, [.rx]
    mul bx
    xor dx, dx
    div word [.ry]
    mov [.hw], ax

    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.hw]
    mov bx, [.cx]
    add bx, [.hw]
    mov dx, [.cy]
    add dx, [.dy]
    call gfx_hline
    mov al, [gfx_col]
    mov cx, [.cx]
    sub cx, [.hw]
    mov bx, [.cx]
    add bx, [.hw]
    mov dx, [.cy]
    sub dx, [.dy]
    call gfx_hline

    inc word [.dy]
    jmp .row
.done:
    popa
    ret

.cx  dw 0
.cy  dw 0
.rx  dw 0
.ry  dw 0
.ry2 dw 0
.dy  dw 0
.hw  dw 0

; ========================================================================
; gfx_isqrt - integer square root of a 16-bit value
; IN:  AX = value
; OUT: AX = floor(sqrt(value))
; ========================================================================
gfx_isqrt:
    push bx
    push cx
    push dx
    mov bx, ax
    xor ax, ax
    mov cx, 0x4000
.l:
    test cx, cx
    jz .e
    mov dx, ax
    add dx, cx
    cmp bx, dx
    jb .lower
    sub bx, dx
    shr ax, 1
    add ax, cx
    jmp .next
.lower:
    shr ax, 1
.next:
    shr cx, 2
    jmp .l
.e:
    pop dx
    pop cx
    pop bx
    ret

%endif ; GRAFX_INC
