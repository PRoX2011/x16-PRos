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

wp_hit:
    push bx
    push dx
    mov ax, [mx]
    cmp ax, WPMENU_X
    jb .out
    cmp ax, WPMENU_X + WPMENU_IW
    jae .out
    mov ax, [my]
    cmp ax, WPMENU_Y
    jb .out
    cmp ax, WPMENU_Y + WPMENU_H
    jae .out
    sub ax, WPMENU_Y
    xor dx, dx
    mov bx, WPMENU_IH
    div bx
    pop dx
    pop bx
    ret
.out:
    mov al, 0xFF
    pop dx
    pop bx
    ret

draw_wp_menu:
    pusha
    mov ah, 0x22
    int 0x23
    mov cx, WPMENU_X
    mov dx, WPMENU_Y
    mov si, WPMENU_IW
    mov di, WPMENU_H
    mov al, 15
    call gfx_fill_rect
    mov byte [.i], 0
.item:
    mov al, [.i]
    cmp al, WPMENU_N
    jae .frame
    xor ah, ah
    mov bx, WPMENU_IH
    mul bx
    add ax, WPMENU_Y
    mov [.iy], ax
    mov al, [.i]
    cmp al, [wp_sel]
    jne .normal
    mov cx, WPMENU_X
    mov dx, [.iy]
    mov si, WPMENU_IW
    mov di, WPMENU_IH
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
    mov si, [wp_items + bx]
    mov cx, WPMENU_X + 6
    mov dx, [.iy]
    mov al, [.tc]
    call draw_name_px
    inc byte [.i]
    jmp .item
.frame:
    mov cx, WPMENU_X
    mov dx, WPMENU_Y
    mov si, WPMENU_IW
    mov di, WPMENU_H
    xor al, al
    call gfx_rect
    mov ah, 0x23
    int 0x23
    popa
    ret
.i  db 0
.iy dw 0
.tc db 0

menu_handle_press:
    cmp byte [menu_open], 0
    je .closed
    cmp byte [menu_open], 1
    je .main_open
    jmp .sub_open

.closed:
    call hit_dot
    jnc .pass
    mov byte [menu_open], 1
    call menu_hit
    mov [menu_sel], al
    call draw_menu
    stc
    ret

.main_open:
    call hit_dot
    jc .close_all
    call menu_hit
    cmp al, 0xFF
    je .close_all
    cmp al, 3
    jne .do_action
    mov byte [menu_open], 2
    mov byte [wp_sel], 0xFF
    call draw_wp_menu
    stc
    ret
.do_action:
    mov byte [menu_open], 0
    call do_menu_action
    call full_repaint
    stc
    ret

.sub_open:
    call wp_hit
    cmp al, 0xFF
    je .close_all
    mov [bg_style], al
    mov byte [menu_open], 0
    call full_repaint
    stc
    ret

.close_all:
    mov byte [menu_open], 0
    call full_repaint
    stc
    ret

.pass:
    clc
    ret

menu_tick:
    cmp byte [menu_open], 1
    je .tick_main
    cmp byte [menu_open], 2
    je .tick_sub
    ret
.tick_main:
    call menu_hit
    cmp al, [menu_sel]
    je .ret
    mov [menu_sel], al
    call draw_menu
.ret:
    ret
.tick_sub:
    call wp_hit
    cmp al, [wp_sel]
    je .ret2
    mov [wp_sel], al
    call draw_wp_menu
.ret2:
    ret

do_menu_action:
    cmp al, 0
    je .exit
    cmp al, 1
    je do_reboot
    cmp al, 2
    je do_shutdown
    cmp al, 3
    je cycle_wallpaper
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
menu_items  dw mi_exit, mi_reboot, mi_shutdown, mi_wallpaper
mi_exit     db 'Exit GUI', 0
mi_reboot   db 'Reboot', 0
mi_shutdown db 'Shut down', 0
mi_wallpaper db 'Wallpaper', 0