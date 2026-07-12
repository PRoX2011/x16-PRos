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
    mov ah, 0x30
    int 0x23
    popa
    ret
.slot db 0
.task db 0

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
.wa_title:
    mov [hit_slot], cl
    mov byte [hit_kind], 2
.wa_done:
    popa
    ret

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
    call win_draw_frame
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

    xor bh, bh
    mov bl, [bg_style]
    shl bx, 3
    mov [.tbl], bx

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
    add bx, [.tbl]
    mov al, [bg_patterns + bx]
    mov cx, 80
    rep stosb

    inc bp
    jmp .row
.done:
    pop es
    popa
    ret
.tbl dw 0

cycle_wallpaper:
    inc byte [bg_style]
    cmp byte [bg_style], BG_STYLE_COUNT
    jb .done
    mov byte [bg_style], 0
.done:
    ret

draw_outline:
    push ax
    mov byte [gfx_xor], 1
    mov cx, [dragx]
    mov dx, [dragy]
    mov si, WW
    mov di, WH
    mov al, 15
    call gfx_rect
    mov byte [gfx_xor], 0
    pop ax
    ret

clamp_wx:
    cmp ax, 0
    jge .a
    xor ax, ax
.a:
    cmp ax, 640 - WW
    jle .b
    mov ax, 640 - WW
.b:
    ret

clamp_wy:
    cmp ax, MENUBAR_H
    jge .a
    mov ax, MENUBAR_H
.a:
    cmp ax, 480 - WH
    jle .b
    mov ax, 480 - WH
.b:
    ret
