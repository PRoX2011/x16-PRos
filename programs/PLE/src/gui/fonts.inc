load_font_list:
    pusha
    mov word [font_count], 0
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov ah, 0x09
    mov si, fonts_dir_name
    int 0x22
    jc .restore
    mov ah, 0x01
    mov si, file_list_buf
    int 0x22
    mov si, file_list_buf
.scan:
    cmp byte [si], 0
    je .restore
    test byte [si+16], 0x10
    jnz .next
    cmp byte [si+9], 'F'
    jne .next
    cmp byte [si+10], 'N'
    jne .next
    cmp byte [si+11], 'T'
    jne .next
    call store_font_name
    mov ax, [font_count]
    cmp ax, MAX_FONTS
    jae .restore
.next:
    add si, 18
    jmp .scan
.restore:
    mov ah, 0x0F
    int 0x22
    popa
    ret

store_font_name:
    pusha
    mov ax, [font_count]
    mov bx, 13
    mul bx
    mov di, font_names
    add di, ax
    xor bx, bx
.base:
    cmp bx, 8
    jge .dot
    mov al, [si+bx]
    cmp al, ' '
    je .dot
    mov [di], al
    inc di
    inc bx
    jmp .base
.dot:
    mov byte [di], '.'
    inc di
    mov byte [di], 'F'
    inc di
    mov byte [di], 'N'
    inc di
    mov byte [di], 'T'
    inc di
    mov byte [di], 0
    inc word [font_count]
    popa
    ret

apply_font_idx:
    pusha
    xor ah, ah
    mov bx, 13
    mul bx
    mov si, font_names
    add si, ax
    push si
    mov ah, 0x09
    mov al, 0x02
    int 0x21
    pop si
    jc .done
    call save_font_cfg
.done:
    popa
    ret

save_font_cfg:
    pusha
    mov di, si
    xor cx, cx
.len:
    cmp byte [di], 0
    je .len_done
    inc di
    inc cx
    jmp .len
.len_done:
    mov [.slen], cx
    mov [.sptr], si
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov si, conf_dir_name
    mov ah, 0x09
    int 0x22
    jc .restore
    mov si, font_cfg_name
    mov bx, [.sptr]
    mov cx, [.slen]
    mov ah, 0x03
    int 0x22
.restore:
    mov ah, 0x0F
    int 0x22
    popa
    ret
.sptr dw 0
.slen dw 0

draw_font_menu:
    pusha
    mov ah, 0x22
    int 0x23
    cmp word [font_count], 0
    je .empty
    mov ax, [font_count]
    mov bx, MENU_IH
    mul bx
    mov [.ph], ax
    mov cx, FONT_MENU_X
    mov dx, FONT_MENU_Y
    mov si, FONT_MENU_IW
    mov di, [.ph]
    mov al, 15
    call gfx_fill_rect
    mov word [.i], 0
.item:
    mov ax, [.i]
    cmp ax, [font_count]
    jae .frame
    mov bx, MENU_IH
    mul bx
    add ax, FONT_MENU_Y
    mov [.iy], ax
    mov al, [.i]
    cmp al, [font_sel]
    jne .normal
    mov cx, FONT_MENU_X
    mov dx, [.iy]
    mov si, FONT_MENU_IW
    mov di, MENU_IH
    xor al, al
    call gfx_fill_rect
    mov byte [.tc], 15
    jmp .text
.normal:
    mov byte [.tc], 0
.text:
    mov ax, [.i]
    mov bx, 13
    mul bx
    add ax, font_names
    mov si, ax
    mov cx, FONT_MENU_X + 6
    mov dx, [.iy]
    mov al, [.tc]
    call draw_name_px
    inc word [.i]
    jmp .item
.frame:
    mov cx, FONT_MENU_X
    mov dx, FONT_MENU_Y
    mov si, FONT_MENU_IW
    mov di, [.ph]
    xor al, al
    call gfx_rect
.empty:
    mov ah, 0x23
    int 0x23
    popa
    ret
.i  dw 0
.iy dw 0
.ph dw 0
.tc db 0

font_menu_hit:
    push bx
    push dx
    mov ax, [mx]
    cmp ax, FONT_MENU_X
    jb .out
    cmp ax, FONT_MENU_X + FONT_MENU_IW
    jae .out
    mov ax, [my]
    cmp ax, FONT_MENU_Y
    jb .out
    sub ax, FONT_MENU_Y
    xor dx, dx
    mov bx, MENU_IH
    div bx
    cmp ax, [font_count]
    jae .out
    pop dx
    pop bx
    ret
.out:
    mov al, 0xFF
    pop dx
    pop bx
    ret

font_menu_open db 0
font_sel       db 0xFF
font_count     dw 0
fonts_dir_name db 'FONTS.DIR', 0
conf_dir_name  db 'CONF.DIR', 0
font_cfg_name  db 'FONT.CFG', 0
font_names     times MAX_FONTS * 13 db 0
