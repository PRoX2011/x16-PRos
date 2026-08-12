WG_FRAME    equ 0     ; panel border
WG_FACE     equ 15    ; panel background
WG_HEAD     equ 7     ; header strip
WG_SEL      equ 0     ; selected item background
WG_SELTEXT  equ 15    ; selected item text
WG_TEXT     equ 0     ; ordinary text
WG_DIM      equ 8     ; secondary text

; ========================================================================
; WG_PANEL - Draws a framed panel
; IN : CX = x, DX = y, SI = width, DI = height, AL = fill colour
; OUT : nothing
; ========================================================================
wg_panel:
    pusha
    call gfx_fill_rect
    mov al, WG_FRAME
    call gfx_rect
    popa
    ret

; ========================================================================
; WG_STRLEN - Length of a null terminated string
; IN : SI = string
; OUT : CX = length in characters
; ========================================================================
wg_strlen:
    push si
    xor cx, cx
.scan:
    cmp byte [si], 0
    je .done
    inc si
    inc cx
    jmp .scan
.done:
    pop si
    ret

; ========================================================================
; WG_TEXT_AT - Draws a string at a pixel position
; IN : SI = string, CX = x, DX = y, AL = colour
; OUT : nothing
; ========================================================================
wg_text_at:
    call draw_name_px
    ret

; ========================================================================
; WG_TEXT_CENTER - Draws a string centred inside a width
; IN : SI = string, CX = x of the area, DX = y, DI = area width,
;      AL = colour
; OUT : nothing
; ========================================================================
wg_text_center:
    pusha
    mov [.col], al
    mov [.x], cx
    mov [.y], dx
    mov [.w], di
    call wg_strlen
    shl cx, 3
    mov ax, [.w]
    sub ax, cx
    jns .fits
    xor ax, ax
.fits:
    shr ax, 1
    add ax, [.x]
    mov cx, ax
    mov dx, [.y]
    mov al, [.col]
    call draw_name_px
    popa
    ret
.col db 0
.x   dw 0
.y   dw 0
.w   dw 0

; ========================================================================
; WG_BUTTON - Draws a framed button with a single character on it
; IN : CX = x, DX = y, SI = width, DI = height, AL = character
; OUT : nothing
; ========================================================================
wg_button:
    pusha
    mov [.glyph], al
    mov [.x], cx
    mov [.y], dx
    mov [.w], si

    mov al, WG_FACE
    call wg_panel

    mov al, [.glyph]
    mov [.buf], al
    mov byte [.buf+1], 0
    mov si, .buf
    mov cx, [.x]
    mov dx, [.y]
    mov di, [.w]
    mov al, WG_TEXT
    call wg_text_center

    popa
    ret
.glyph db 0
.x     dw 0
.y     dw 0
.w     dw 0
.buf   times 2 db 0

; ========================================================================
; WG_HIT_RECT - Tests the pointer against a rectangle
; IN : CX = x, DX = y, SI = width, DI = height
; OUT : CF = 1 if the pointer is inside
; ========================================================================
wg_hit_rect:
    push ax
    push bx
    mov ax, [mx]
    cmp ax, cx
    jb .out
    mov bx, cx
    add bx, si
    cmp ax, bx
    jae .out
    mov ax, [my]
    cmp ax, dx
    jb .out
    mov bx, dx
    add bx, di
    cmp ax, bx
    jae .out
    pop bx
    pop ax
    stc
    ret
.out:
    pop bx
    pop ax
    clc
    ret

; ========================================================================
; WG_HIT_LIST - Tells which row of a vertical list the pointer is over
; IN : CX = x, DX = y, SI = width, DI = row height, BX = row count
; OUT : AL = row index, 0FFh if the pointer is elsewhere
; ========================================================================
wg_hit_list:
    push bx
    push cx
    push dx
    push si
    push di

    mov [.rowh], di
    mov [.y], dx

    mov ax, di
    mul bx
    mov di, ax
    mov dx, [.y]
    call wg_hit_rect
    jnc .out

    mov ax, [my]
    sub ax, [.y]
    xor dx, dx
    div word [.rowh]

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
.out:
    mov al, 0xFF
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
.rowh dw 0
.y    dw 0

; ========================================================================
; WG_LIST_ROW - Draws one row of a list, highlighted when selected
; IN : SI = caption, CX = x, DX = y, DI = width, BX = row height,
;      AL = 0 for an ordinary row, non-zero for the selected one
; OUT : nothing
; ========================================================================
wg_list_row:
    pusha
    mov [.x], cx
    mov [.y], dx
    mov [.w], di
    mov [.sptr], si
    mov byte [.tc], WG_TEXT

    test al, al
    jz .text
    mov si, di
    mov di, bx
    mov al, WG_SEL
    call gfx_fill_rect
    mov byte [.tc], WG_SELTEXT

.text:
    mov si, [.sptr]
    mov cx, [.x]
    add cx, 6
    mov dx, [.y]
    mov al, [.tc]
    call draw_name_px
    popa
    ret
.x    dw 0
.y    dw 0
.w    dw 0
.sptr dw 0
.tc   db 0
