draw_menubar:
    pusha
    mov cx, 0
    mov dx, 0
    mov si, 640
    mov di, MENUBAR_H
    mov al, 15
    call gfx_fill_rect
    mov al, 0
    mov cx, 0
    mov bx, 639
    mov dx, MENUBAR_H - 1
    call gfx_hline
    mov cx, TILE_X
    mov dx, TILE_Y
    mov si, TILE_W
    mov di, TILE_H
    mov al, 0x08
    call gfx_fill_rect
    call draw_star
    mov si, menu_str
    mov cl, 3
    mov ch, 0
    mov bl, 0xF0
    call font_print_string
    call draw_clock
    popa
    ret

draw_star:
    pusha
    mov si, star_bmp
    xor bp, bp
.row:
    cmp bp, STAR_H
    jae .done
    mov bx, [si]
    add si, 2
    xor di, di
.col:
    cmp di, STAR_W
    jae .nextrow
    mov ax, 0x0400
    mov cx, di
    shr ax, cl
    test bx, ax
    jz .skip
    mov cx, STAR_X
    add cx, di
    mov dx, STAR_Y
    add dx, bp
    mov al, 0xFF
    call gfx_pixel
.skip:
    inc di
    jmp .col
.nextrow:
    inc bp
    jmp .row
.done:
    popa
    ret
star_bmp dw 0x020, 0x020, 0x070, 0x0F8, 0x1FC, 0x7FF, 0x1FC, 0x0F8, 0x070, 0x020, 0x020

draw_clock:
    pusha
    mov ah, 0x0A
    int 0x21
    mov [.hr], ch
    mov [.min], cl
    mov [.sec], dh
    mov ah, 0x0B
    int 0x21
    mov [.cent], ch
    mov [.yr], cl
    mov [.mon], dh
    mov [.day], dl

    mov di, clk_buf
    mov al, [.hr]
    call bin2_to_buf
    mov byte [di], ':'
    inc di
    mov al, [.min]
    call bin2_to_buf
    mov byte [di], ':'
    inc di
    mov al, [.sec]
    call bin2_to_buf
    mov word [di], '  '
    add di, 2
    mov al, [.day]
    call bin2_to_buf
    mov byte [di], '.'
    inc di
    mov al, [.mon]
    call bin2_to_buf
    mov byte [di], '.'
    inc di
    mov al, [.cent]
    call bin2_to_buf
    mov al, [.yr]
    call bin2_to_buf
    mov byte [di], 0

    mov si, clk_buf
    mov cl, 80 - 20 - 1
    mov ch, 0
    mov bl, 0xF0
    call font_print_string

    mov al, [.sec]
    mov [clk_last_sec], al
    popa
    ret
.hr   db 0
.min  db 0
.sec  db 0
.cent db 0
.yr   db 0
.mon  db 0
.day  db 0

bin2_to_buf:
    push ax
    push bx
    xor ah, ah
    mov bl, 10
    div bl
    add al, '0'
    mov [di], al
    inc di
    add ah, '0'
    mov [di], ah
    inc di
    pop bx
    pop ax
    ret

tick_clock:
    cmp byte [dragging], 0
    jne .ret
    mov ah, 0x0A
    int 0x21
    cmp dh, [clk_last_sec]
    je .ret
    mov ah, 0x22
    int 0x23
    call draw_clock
    mov ah, 0x23
    int 0x23
.ret:
    ret
