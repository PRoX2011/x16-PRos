enumerate_ple:
    pusha
    mov word [icon_count], 0
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov ah, 0x09
    mov si, pledir_name
    int 0x22
    jc .restore
    mov ah, 0x09
    mov si, guidir_name
    int 0x22
    jc .restore
    mov ah, 0x01
    mov si, file_list_buf
    int 0x22
    mov si, file_list_buf
.pe_loop:
    cmp byte [si], 0
    je .restore
    test byte [si+16], 0x10
    jnz .pe_next
    cmp byte [si+9], 'P'
    jne .pe_next
    cmp byte [si+10], 'L'
    jne .pe_next
    cmp byte [si+11], 'E'
    jne .pe_next
    call store_icon_name
    mov ax, [icon_count]
    cmp ax, MAX_ICONS
    jge .restore
.pe_next:
    add si, 18
    jmp .pe_loop
.restore:
    mov ah, 0x0F
    int 0x22
    popa
    ret

store_icon_name:
    pusha
    mov ax, [icon_count]
    shl ax, 4
    mov di, icon_names
    add di, ax
    xor bx, bx
.sn_base:
    cmp bx, 9
    jge .sn_dot
    mov al, [si+bx]
    cmp al, ' '
    je .sn_dot
    mov [di], al
    inc di
    inc bx
    jmp .sn_base
.sn_dot:
    mov byte [di], '.'
    inc di
    mov bx, 9
.sn_ext:
    cmp bx, 12
    jge .sn_end
    mov al, [si+bx]
    cmp al, ' '
    je .sn_end
    mov [di], al
    inc di
    inc bx
    jmp .sn_ext
.sn_end:
    mov byte [di], 0
    inc word [icon_count]
    popa
    ret

draw_desktop_icons:
    pusha
    mov word [ico_i], 0
.di_loop:
    mov ax, [ico_i]
    cmp ax, [icon_count]
    jge .di_done
    xor dx, dx
    mov bx, ICON_COLS
    div bx
    mov [ico_row], ax
    mov [ico_col], dx
    mov ax, [ico_col]
    mov bx, ICON_DX
    mul bx
    add ax, ICON_X0
    mov [ico_x], ax
    mov ax, [ico_row]
    mov bx, ICON_DY
    mul bx
    add ax, ICON_Y0
    mov [ico_y], ax
    call draw_one_icon
    call draw_icon_name
    inc word [ico_i]
    jmp .di_loop
.di_done:
    popa
    ret

draw_one_icon:
    pusha
    mov bx, [ico_i]
    cmp byte [icon_has_logo + bx], 0
    je .generic
    call draw_icon_logo
    popa
    ret
.generic:
    mov cx, [ico_x]
    mov dx, [ico_y]
    mov si, IW
    mov di, IH
    mov al, 15
    call gfx_fill_rect
    mov cx, [ico_x]
    mov dx, [ico_y]
    mov si, IW
    mov di, IH
    mov al, 0
    call gfx_rect
    mov al, 0
    mov cx, [ico_x]
    add cx, IW - 9
    mov dx, [ico_y]
    mov si, [ico_x]
    add si, IW - 1
    mov di, [ico_y]
    add di, 8
    call gfx_line
    mov al, 0
    mov cx, [ico_x]
    add cx, IW - 9
    mov dx, [ico_y]
    mov si, [ico_x]
    add si, IW - 9
    mov di, [ico_y]
    add di, 8
    call gfx_line
    mov al, 0
    mov cx, [ico_x]
    add cx, 5
    mov bx, [ico_x]
    add bx, IW - 6
    mov dx, [ico_y]
    add dx, 13
    call gfx_hline
    mov al, 0
    mov cx, [ico_x]
    add cx, 5
    mov bx, [ico_x]
    add bx, IW - 6
    mov dx, [ico_y]
    add dx, 17
    call gfx_hline
    mov al, 0
    mov cx, [ico_x]
    add cx, 5
    mov bx, [ico_x]
    add bx, IW - 11
    mov dx, [ico_y]
    add dx, 21
    call gfx_hline
    popa
    ret

cache_logos:
    pusha
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov ah, 0x09
    mov si, pledir_name
    int 0x22
    jc .restore
    mov ah, 0x09
    mov si, guidir_name
    int 0x22
    jc .restore

    mov word [.i], 0
.loop:
    mov ax, [.i]
    cmp ax, [icon_count]
    jae .restore
    shl ax, 4
    mov si, icon_names
    add si, ax
    mov [.fn], si

    mov ah, 0x08
    int 0x22
    jc .next
    cmp bx, LOGO_LOAD_MAX
    ja .next

    mov si, [.fn]
    mov cx, LOGO_LOAD_OFF
    mov ah, 0x02
    int 0x22
    jc .next

    cmp byte [LOGO_LOAD_OFF + 0], 'P'
    jne .next
    cmp byte [LOGO_LOAD_OFF + 1], 'L'
    jne .next
    cmp byte [LOGO_LOAD_OFF + 2], 'E'
    jne .next

    mov ax, [.i]
    call downscale_logo
    mov bx, [.i]
    mov byte [icon_has_logo + bx], 1
.next:
    inc word [.i]
    jmp .loop
.restore:
    mov ah, 0x0F
    int 0x22
    popa
    ret
.i  dw 0
.fn dw 0

downscale_logo:
    pusha
    mov bx, ax
    shl bx, 10
    add bx, LOGO_CACHE_OFF
    mov di, bx
    xor bp, bp
.row:
    cmp bp, LOGO_PX
    jae .done
    mov ax, bp
    shl ax, 7
    add ax, LOGO_LOAD_OFF + 0x40
    mov si, ax
    xor cx, cx
.col:
    cmp cx, LOGO_PX
    jae .rowdone
    mov bx, cx
    shl bx, 1
    mov al, [si + bx]
    mov [di], al
    inc di
    inc cx
    jmp .col
.rowdone:
    inc bp
    jmp .row
.done:
    popa
    ret

draw_icon_logo:
    pusha
    mov bx, [ico_i]
    shl bx, 10
    add bx, LOGO_CACHE_OFF
    mov si, bx
    xor bp, bp
.row:
    cmp bp, LOGO_PX
    jae .done
    xor di, di
.col:
    cmp di, LOGO_PX
    jae .rowdone
    mov al, [si]
    inc si
    push ax
    mov ax, di
    mov bx, LOGO_PX - 1
    sub bx, di
    cmp ax, bx
    jle .dxok
    mov ax, bx
.dxok:
    mov bx, bp
    mov cx, LOGO_PX - 1
    sub cx, bp
    cmp bx, cx
    jle .dyok
    mov bx, cx
.dyok:
    add ax, bx
    cmp ax, [icon_round]
    pop ax
    jl .skippx
    mov cx, [ico_x]
    add cx, di
    mov dx, [ico_y]
    add dx, bp
    call gfx_pixel
.skippx:
    inc di
    jmp .col
.rowdone:
    inc bp
    jmp .row
.done:
    popa
    ret

draw_icon_name:
    pusha
    mov ax, [ico_i]
    shl ax, 4
    mov si, icon_names
    add si, ax
    mov [.sptr], si
    xor cx, cx
.dn_len:
    cmp byte [si], 0
    je .dn_have
    inc si
    inc cx
    jmp .dn_len
.dn_have:
    mov ax, cx
    shl ax, 3
    mov [.w], ax
    mov ax, [ico_x]
    add ax, IW / 2
    mov bx, [.w]
    shr bx, 1
    sub ax, bx
    jns .dn_xok
    xor ax, ax
.dn_xok:
    mov [.x], ax
    mov ax, [ico_y]
    add ax, LOGO_PX
    add ax, [name_gap]
    mov [.y], ax

    mov si, [.sptr]
    mov cx, [.x]
    mov dx, [.y]
    mov al, 0x0F
    call draw_name_outlined
    popa
    ret

    mov si, [.sptr]
    mov cx, [.x]
    mov dx, [.y]
    mov al, 0x0F
    call draw_name_px
    popa
    ret
.sptr dw 0
.w    dw 0
.x    dw 0
.y    dw 0

draw_name_outlined:
    pusha
    mov [.color], al
    mov [.penx0], cx
    mov [.peny0], dx
    mov [.sptr0], si

    mov si, [.sptr0]
    mov cx, [.penx0]
    dec cx
    mov dx, [.peny0]
    mov al, 0
    call draw_name_px

    mov si, [.sptr0]
    mov cx, [.penx0]
    inc cx
    mov dx, [.peny0]
    mov al, 0
    call draw_name_px

    mov si, [.sptr0]
    mov cx, [.penx0]
    mov dx, [.peny0]
    dec dx
    mov al, 0
    call draw_name_px

    mov si, [.sptr0]
    mov cx, [.penx0]
    mov dx, [.peny0]
    inc dx
    mov al, 0
    call draw_name_px

    mov si, [.sptr0]
    mov cx, [.penx0]
    mov dx, [.peny0]
    mov al, [.color]
    call draw_name_px

    popa
    ret
.color  db 0
.penx0  dw 0
.peny0  dw 0
.sptr0  dw 0

draw_name_px:
    pusha
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
    xor ah, ah
    shl ax, 4
    add ax, [font_data_off]
    mov [.gptr], ax
    mov word [.r], 0
.row:
    cmp word [.r], 16
    jae .nextch
    push es
    mov es, [font_data_seg]
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
    call gfx_pixel
.nextcol:
    inc word [.c]
    jmp .col
.nextrow:
    inc word [.r]
    jmp .row
.nextch:
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

icon_hittest:
    push bx
    push cx
    push dx
    push si
    xor si, si
.ih_loop:
    mov ax, si
    cmp ax, [icon_count]
    jge .ih_none
    xor dx, dx
    mov bx, ICON_COLS
    div bx
    push ax
    mov ax, dx
    mov bx, ICON_DX
    mul bx
    add ax, ICON_X0
    mov cx, ax
    pop ax
    mov bx, ICON_DY
    mul bx
    add ax, ICON_Y0
    mov bx, [mx]
    cmp bx, cx
    jl .ih_next
    mov dx, cx
    add dx, IW - 1
    cmp bx, dx
    jg .ih_next
    mov bx, [my]
    cmp bx, ax
    jl .ih_next
    mov dx, ax
    add dx, IH - 1
    cmp bx, dx
    jg .ih_next
    mov ax, si
    jmp .ih_ret
.ih_next:
    inc si
    jmp .ih_loop
.ih_none:
    mov ax, 0xFFFF
.ih_ret:
    pop si
    pop cx
    pop dx
    pop bx
    ret