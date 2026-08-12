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
    cmp byte [.i], WP_ITEM
    je .arrow
    cmp byte [.i], FONT_ITEM
    jne .noarrow
.arrow:
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

; ========================================================================
; OPEN_FONT_SUBMENU - Opens the font list, keeping what it covers
; IN : nothing
; OUT : font_menu_open = 1, area behind it saved
; ========================================================================
open_font_submenu:
    call load_font_list
    mov byte [font_menu_open], 1
    mov byte [font_sel], 0xFF
    mov ax, [font_count]
    mov bx, MENU_IH
    mul bx
    mov di, ax
    mov cx, FONT_MENU_X
    mov dx, FONT_MENU_Y
    mov si, FONT_MENU_IW
    call popup_set_rect
    mov ah, 0x22
    int 0x23
    call popup_save
    call draw_font_menu
    ret

; ========================================================================
; OPEN_WP_SUBMENU - Opens the wallpaper list, keeping what it covers
; IN : nothing
; OUT : wp_menu_open = 1, area behind it saved
; ========================================================================
open_wp_submenu:
    mov byte [wp_menu_open], 1
    mov byte [wp_sel], 0xFF
    mov cx, WPMENU_X
    mov dx, WPMENU_Y
    mov si, WPMENU_IW
    mov di, WPMENU_H
    call popup_set_rect
    mov ah, 0x22
    int 0x23
    call popup_save
    call draw_wp_menu
    ret

menu_handle_press:
    cmp byte [menu_open], 0
    je .closed
    cmp byte [wp_menu_open], 0
    jne .wp_open
    cmp byte [font_menu_open], 0
    jne .font_open
    jmp .main_click

.closed:
    call hit_dot
    jnc .pass
    mov byte [menu_open], 1
    mov byte [font_menu_open], 0
    mov byte [wp_menu_open], 0
    call menu_hit
    mov [menu_sel], al
    call draw_menu
    stc
    ret

.wp_open:
    call wp_hit
    cmp al, 0xFF
    je .dismiss
    mov [bg_style], al
    mov byte [wp_menu_open], 0
    mov byte [menu_open], 0
    call full_repaint
    stc
    ret

.font_open:
    call font_menu_hit
    cmp al, 0xFF
    je .dismiss
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
    cmp al, WP_ITEM
    je .open_wp
    cmp al, FONT_ITEM
    je .open_font
    mov byte [menu_open], 0
    call do_menu_action
    call full_repaint
    stc
    ret
.open_wp:
    call open_wp_submenu
    stc
    ret
.open_font:
    call open_font_submenu
    stc
    ret
.dismiss:
    mov byte [font_menu_open], 0
    mov byte [wp_menu_open], 0
    mov byte [menu_open], 0
    call full_repaint
    stc
    ret
.pass:
    clc
    ret

menu_tick:
    cmp byte [menu_open], 0
    je .ret
    cmp byte [wp_menu_open], 0
    jne .tick_wp
    cmp byte [font_menu_open], 0
    jne .tick_font
    jmp .hover_main

.tick_wp:
    call wp_hit
    cmp al, 0xFF
    je .sub_outside
    cmp al, [wp_sel]
    je .ret
    mov [wp_sel], al
    call draw_wp_menu
    ret

.tick_font:
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
    cmp al, 0xFF
    je .ret
    cmp al, [menu_sel]
    je .ret
    mov ah, 0x22
    int 0x23
    call popup_restore
    mov byte [wp_menu_open], 0
    mov byte [font_menu_open], 0
    mov [menu_sel], al
    call draw_menu
    cmp al, WP_ITEM
    je .open_wp2
    cmp al, FONT_ITEM
    jne .ret
    call open_font_submenu
    ret

.hover_main:
    call menu_hit
    cmp al, [menu_sel]
    je .ret
    mov [menu_sel], al
    call draw_menu
    cmp al, WP_ITEM
    je .open_wp2
    cmp al, FONT_ITEM
    jne .ret
    call open_font_submenu
    ret
.open_wp2:
    call open_wp_submenu
.ret:
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

menu_open     db 0
menu_sel      db 0xFF
want_quit     db 0
wp_menu_open  db 0
menu_items    dw mi_exit, mi_reboot, mi_shutdown, mi_wallpaper, mi_fonts
mi_exit       db 'Exit GUI', 0
mi_reboot     db 'Reboot', 0
mi_shutdown   db 'Shut down', 0
mi_wallpaper  db 'Wallpaper', 0
mi_fonts      db 'Fonts', 0
