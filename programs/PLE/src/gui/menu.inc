hit_dot:
    mov ax, [mx]
    cmp ax, DOT_ZONE_W
    jae .no
    mov ax, [my]
    cmp ax, MENUBAR_H
    jae .no
    stc
    ret
.no:
    clc
    ret

menu_hit:
    push bx
    push dx
    mov ax, [mx]
    cmp ax, MENU_X
    jb .out
    cmp ax, MENU_X + MENU_IW
    jae .out
    mov ax, [my]
    cmp ax, MENU_Y
    jb .out
    cmp ax, MENU_Y + MENU_H
    jae .out
    sub ax, MENU_Y
    xor dx, dx
    mov bx, MENU_IH
    div bx
    pop dx
    pop bx
    ret
.out:
    mov al, 0xFF
    pop dx
    pop bx
    ret

draw_menu:
    pusha
    mov ah, 0x22
    int 0x23

    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_IW
    mov di, MENU_H
    mov al, 15
    call gfx_fill_rect

    mov byte [.i], 0
.item:
    mov al, [.i]
    cmp al, MENU_N
    jae .frame
    xor ah, ah
    mov bx, MENU_IH
    mul bx
    add ax, MENU_Y
    mov [.iy], ax

    mov al, [.i]
    cmp al, [menu_sel]
    jne .normal
    mov cx, MENU_X
    mov dx, [.iy]
    mov si, MENU_IW
    mov di, MENU_IH
    xor al, al
    call gfx_fill_rect
    mov byte [.tc], 15
    jmp .text
.normal:
    mov byte [.tc], 0
.text:
    mov al, [.i]
    xor ah, ah
    shl ax, 1
    mov bx, ax
    mov si, [menu_items + bx]
    mov cx, MENU_X + 6
    mov dx, [.iy]
    mov al, [.tc]
    call draw_name_px
    cmp byte [.i], FONT_ITEM
    jne .noarrow
    mov al, [.tc]
    mov dx, [.iy]
    call draw_menu_arrow
.noarrow:
    inc byte [.i]
    jmp .item
.frame:
    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_IW
    mov di, MENU_H
    xor al, al
    call gfx_rect

    mov ah, 0x23
    int 0x23
    popa
    ret
.i  db 0
.iy dw 0
.tc db 0

draw_menu_arrow:
    pusha
    mov [.col], al
    add dx, 4
    mov [.top], dx
    mov word [.r], 0
.row:
    cmp word [.r], 7
    jae .done
    mov ax, [.r]
    sub ax, 3
    jns .pos
    neg ax
.pos:
    mov bx, 3
    sub bx, ax
    mov cx, MENU_X + MENU_IW - 9
    mov ax, cx
    add ax, bx
    mov dx, [.top]
    add dx, [.r]
    mov bx, ax
    mov al, [.col]
    call gfx_hline
    inc word [.r]
    jmp .row
.done:
    popa
    ret
.col db 0
.top dw 0
.r   dw 0

open_font_submenu:
    call load_font_list
    mov byte [font_menu_open], 1
    mov byte [font_sel], 0xFF
    call draw_font_menu
    ret

menu_handle_press:
    cmp byte [menu_open], 0
    je .closed

    cmp byte [font_menu_open], 0
    je .main_click
    call font_menu_hit
    cmp al, 0xFF
    je .main_click
    mov byte [font_menu_open], 0
    mov byte [menu_open], 0
    call apply_font_idx
    call full_repaint
    stc
    ret

.main_click:
    call hit_dot
    jc .dismiss
    call menu_hit
    cmp al, 0xFF
    je .dismiss
    cmp al, FONT_ITEM
    je .on_parent
    mov byte [font_menu_open], 0
    mov byte [menu_open], 0
    call do_menu_action
    call full_repaint
    stc
    ret
.on_parent:
    cmp byte [font_menu_open], 0
    jne .keep
    call open_font_submenu
.keep:
    stc
    ret
.dismiss:
    mov byte [font_menu_open], 0
    mov byte [menu_open], 0
    call full_repaint
    stc
    ret

.closed:
    call hit_dot
    jnc .pass
    mov byte [menu_open], 1
    mov byte [font_menu_open], 0
    call menu_hit
    mov [menu_sel], al
    call draw_menu
    stc
    ret
.pass:
    clc
    ret

menu_tick:
    cmp byte [menu_open], 0
    je .ret

    cmp byte [font_menu_open], 0
    je .hover_main

    call font_menu_hit
    cmp al, 0xFF
    je .sub_outside
    cmp al, [font_sel]
    je .ret
    mov [font_sel], al
    call draw_font_menu
    ret
.sub_outside:
    call menu_hit
    cmp al, FONT_ITEM
    je .ret
    cmp al, 0xFF
    je .ret
    mov byte [font_menu_open], 0
    mov [menu_sel], al
    call full_repaint
    call draw_menu
    ret

.hover_main:
    call menu_hit
    cmp al, [menu_sel]
    je .ret
    mov [menu_sel], al
    call draw_menu
    cmp al, FONT_ITEM
    jne .ret
    call open_font_submenu
.ret:
    ret

do_menu_action:
    cmp al, 0
    je .exit
    cmp al, 1
    je do_reboot
    cmp al, 2
    je do_shutdown
    ret
.exit:
    mov byte [want_quit], 1
    ret

do_reboot:
    cli
    mov al, 0xFE
    out 0x64, al
    jmp 0xFFFF:0x0000

do_shutdown:
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    mov ax, 0x530E
    xor bx, bx
    mov cx, 0x0102
    int 0x15
    mov ax, 0x5308
    mov bx, 0x0001
    mov cx, 0x0001
    int 0x15
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret

menu_open   db 0
menu_sel    db 0xFF
want_quit   db 0
menu_items  dw mi_exit, mi_reboot, mi_shutdown, mi_fonts
mi_exit     db 'Exit GUI', 0
mi_reboot   db 'Reboot', 0
mi_shutdown db 'Shut down', 0
mi_fonts    db 'Fonts', 0
