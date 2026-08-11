; ==================================================================
; x16-PRos -- CALC. Calculator for simple math.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Calculator for simple math", "PRoX-dev"
PLE_LOGO          "logo/calc.raw"

MARGIN  equ 4
MB_H    equ 16
DISP_H  equ 20
MENU_X  equ MARGIN
MENU_Y  equ MB_H
MENU_W  equ 72
MENU_N  equ 3

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    call surf_sync
    cmp byte [surf_windowed], 1
    je .ready
    mov ah, 0x06
    int 0x21
    mov ah, 0x24
    mov al, 1
    int 0x23
    mov ah, 0x23
    int 0x23
.ready:
    xor ax, ax
    mov [lhs], ax
    mov [cur], ax
    mov byte [op], 0
    mov byte [fresh], 1
    mov byte [menu_open], 0
    mov byte [menu_hl], 0xFF
    mov byte [pressed_btn], 0xFF
    mov byte [want_quit], 0
    mov word [last_ox], 0xFFFF
    mov word [last_w], 0xFFFF
    mov word [last_h], 0xFFFF

.loop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .exit
    call compute_layout
    call surf_input

    cmp byte [surf_dirty], 0
    jne .full
    mov ax, [surf_ox]
    cmp ax, [last_ox]
    jne .full
    mov ax, [surf_w]
    cmp ax, [last_w]
    jne .full
    mov ax, [surf_h]
    cmp ax, [last_h]
    jne .full
    jmp .input
.full:
    mov byte [surf_dirty], 0
    mov ax, [surf_ox]
    mov [last_ox], ax
    mov ax, [surf_w]
    mov [last_w], ax
    mov ax, [surf_h]
    mov [last_h], ax
    mov byte [pressed_btn], 0xFF
    call draw_all
    cmp byte [menu_open], 0
    je .input
    call draw_menu_now

.input:
    cmp byte [menu_open], 0
    jne .menu_mode

    call handle_btn_release
    cmp byte [surf_mpress], 0
    je .pace
    mov cx, MARGIN
    mov dx, 0
    mov si, 4 * 8
    mov di, MB_H
    call surf_in_rect
    jc .open_menu
    call handle_btn_press
    jmp .pace
.open_menu:
    mov byte [menu_open], 1
    mov byte [menu_hl], 0xFF
    call draw_menu_now
    jmp .pace

.menu_mode:
    call menu_hover
    cmp byte [surf_mpress], 0
    je .pace
    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_W
    mov di, MENU_N
    call surf_menu_hit
    cmp al, 0xFF
    je .menu_close
    call do_menu_action
    cmp byte [want_quit], 0
    jne .exit
.menu_close:
    mov byte [menu_open], 0
    call draw_all
    jmp .pace

.pace:
    cmp byte [surf_windowed], 1
    je .wpace
    mov ah, 0x01
    int 0x16
    jz .sdelay
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .exit
.sdelay:
    mov ah, 0x86
    mov cx, 0
    mov dx, 20000
    int 0x15
    jmp .loop
.wpace:
    mov ah, 0x14
    mov cx, 1
    int 0x23
    jmp .loop

.exit:
    cmp byte [surf_windowed], 1
    je .wexit
    mov ah, 0x0C
    int 0x21
    retf
.wexit:
    mov ah, 0x12
    int 0x23
    jmp .wexit

compute_layout:
    pusha
    mov word [disp_x], MARGIN
    mov word [disp_y], MB_H + MARGIN
    mov ax, [surf_w]
    sub ax, MARGIN * 2
    mov [disp_w], ax
    mov word [disp_h], DISP_H
    mov ax, [disp_y]
    add ax, DISP_H
    add ax, MARGIN
    mov [grid_top], ax
    mov ax, [surf_w]
    sub ax, MARGIN * 2
    xor dx, dx
    mov cx, 4
    div cx
    mov [cell_w], ax
    mov ax, [surf_h]
    sub ax, [grid_top]
    sub ax, MARGIN
    xor dx, dx
    mov cx, 4
    div cx
    mov [cell_h], ax
    popa
    ret

btn_rect:
    push ax
    push bx
    mov ax, bx
    xor dx, dx
    push cx
    mov cx, 4
    div cx
    pop cx
    push ax
    mov ax, dx
    mul word [cell_w]
    add ax, MARGIN
    mov [.rx], ax
    pop ax
    mul word [cell_h]
    add ax, [grid_top]
    mov [.ry], ax
    pop bx
    pop ax
    mov cx, [.rx]
    mov dx, [.ry]
    mov si, [cell_w]
    sub si, 2
    mov di, [cell_h]
    sub di, 2
    ret
.rx dw 0
.ry dw 0

draw_all:
    pusha
    call hide_cur
    mov al, 7
    call surf_clear
    call draw_menubar
    call draw_display
    xor bx, bx
.bl:
    cmp bx, 16
    jae .done
    xor al, al
    call draw_button_idx
    inc bx
    jmp .bl
.done:
    call show_cur
    popa
    ret

draw_menubar:
    pusha
    mov cx, 0
    mov dx, 0
    mov si, [surf_w]
    mov di, MB_H
    mov al, 15
    call surf_fill_rect
    mov cx, 0
    mov bx, [surf_w]
    dec bx
    mov dx, MB_H - 1
    xor al, al
    call surf_hline
    mov cx, MARGIN
    mov dx, 0
    mov si, lbl_edit
    xor al, al
    call surf_print
    popa
    ret

draw_display:
    pusha
    mov cx, [disp_x]
    mov dx, [disp_y]
    mov si, [disp_w]
    mov di, [disp_h]
    mov al, 15
    call surf_fill_rect
    mov cx, [disp_x]
    mov dx, [disp_y]
    mov si, [disp_w]
    mov di, [disp_h]
    xor al, al
    call surf_rect
    mov di, numbuf
    mov ax, [cur]
    call i16_to_str
    mov si, numbuf
    call surf_text_w
    mov cx, [disp_x]
    add cx, [disp_w]
    sub cx, ax
    sub cx, 5
    mov ax, [disp_h]
    sub ax, 16
    sar ax, 1
    add ax, [disp_y]
    mov dx, ax
    mov si, numbuf
    xor al, al
    call surf_print
    popa
    ret

draw_button_idx:
    pusha
    mov [.pr], al
    call btn_rect
    mov al, [keys + bx]
    mov [keybuf], al
    mov byte [keybuf + 1], 0
    push bx
    mov bx, keybuf
    mov al, [.pr]
    call surf_button
    pop bx
    popa
    ret
.pr db 0

draw_menu_now:
    pusha
    call hide_cur
    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_W
    mov di, MENU_N
    mov bx, menu_tbl
    mov al, [menu_hl]
    call surf_menu
    call show_cur
    popa
    ret

handle_btn_press:
    xor bx, bx
.bl:
    cmp bx, 16
    jae .ret
    push bx
    call btn_rect
    call surf_in_rect
    pop bx
    jc .hit
    inc bx
    jmp .bl
.hit:
    mov [pressed_btn], bl
    call hide_cur
    mov al, 1
    call draw_button_idx
    mov al, bl
    call do_key
    call draw_display
    call show_cur
.ret:
    ret

handle_btn_release:
    cmp byte [pressed_btn], 0xFF
    je .ret
    cmp byte [surf_mb], 0
    jne .ret
    call hide_cur
    xor bx, bx
    mov bl, [pressed_btn]
    xor al, al
    call draw_button_idx
    call show_cur
    mov byte [pressed_btn], 0xFF
.ret:
    ret

menu_hover:
    mov cx, MENU_X
    mov dx, MENU_Y
    mov si, MENU_W
    mov di, MENU_N
    call surf_menu_hit
    cmp al, [menu_hl]
    je .ret
    mov [menu_hl], al
    call draw_menu_now
.ret:
    ret

do_menu_action:
    cmp al, 0
    je .clear
    cmp al, 1
    je .neg
    cmp al, 2
    je .quit
    ret
.clear:
    xor ax, ax
    mov [lhs], ax
    mov [cur], ax
    mov byte [op], 0
    mov byte [fresh], 1
    ret
.neg:
    call do_negate
    ret
.quit:
    mov byte [want_quit], 1
    ret

do_key:
    push bx
    xor bx, bx
    mov bl, al
    mov al, [keys + bx]
    pop bx
    cmp al, '0'
    jb .ctrl
    cmp al, '9'
    ja .ctrl
    call do_digit
    ret
.ctrl:
    cmp al, 'C'
    je .clear
    cmp al, '='
    je .equals
    call do_operator
    ret
.clear:
    xor ax, ax
    mov [lhs], ax
    mov [cur], ax
    mov byte [op], 0
    mov byte [fresh], 1
    ret
.equals:
    cmp byte [op], 0
    je .ret
    call do_compute
    mov [cur], ax
    mov [lhs], ax
    mov byte [op], 0
    mov byte [fresh], 1
.ret:
    ret

do_digit:
    push ax
    push bx
    push dx
    sub al, '0'
    mov bl, al
    xor bh, bh
    cmp byte [fresh], 0
    je .cont
    mov word [cur], 0
    mov byte [fresh], 0
.cont:
    mov ax, [cur]
    mov dx, 10
    mul dx
    test dx, dx
    jnz .skip
    add ax, bx
    js .skip
    jc .skip
    mov [cur], ax
.skip:
    pop dx
    pop bx
    pop ax
    ret

do_operator:
    mov [.newop], al
    cmp byte [op], 0
    je .first
    cmp byte [fresh], 1
    je .setop
    call do_compute
    mov [cur], ax
    mov [lhs], ax
    jmp .setop
.first:
    mov ax, [cur]
    mov [lhs], ax
.setop:
    mov al, [.newop]
    mov [op], al
    mov byte [fresh], 1
    ret
.newop db 0

do_negate:
    push ax
    mov ax, [cur]
    neg ax
    mov [cur], ax
    mov byte [fresh], 1
    pop ax
    ret

do_compute:
    push bx
    mov ax, [lhs]
    mov bx, [cur]
    cmp byte [op], '+'
    je .add
    cmp byte [op], '-'
    je .sub
    cmp byte [op], '*'
    je .mul
    cmp byte [op], '/'
    je .div
    jmp .done
.add:
    add ax, bx
    jmp .done
.sub:
    sub ax, bx
    jmp .done
.mul:
    imul bx
    jmp .done
.div:
    test bx, bx
    jz .dz
    cmp bx, -1
    je .neg1
    cwd
    idiv bx
    jmp .done
.neg1:
    neg ax
    jmp .done
.dz:
    xor ax, ax
.done:
    pop bx
    ret

i16_to_str:
    pusha
    mov byte [.neg], 0
    test ax, ax
    jns .pos
    mov byte [.neg], 1
    neg ax
.pos:
    mov bx, 10
    mov si, .tmp
    xor cx, cx
.dl:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    inc si
    inc cx
    test ax, ax
    jnz .dl
    cmp byte [.neg], 0
    je .rev
    mov byte [di], '-'
    inc di
.rev:
    dec si
    mov al, [si]
    mov [di], al
    inc di
    dec cx
    jnz .rev
    mov byte [di], 0
    popa
    ret
.neg db 0
.tmp times 8 db 0

hide_cur:
    cmp byte [surf_windowed], 1
    jne .r
    mov ah, 0x22
    int 0x23
.r:
    ret

show_cur:
    cmp byte [surf_windowed], 1
    jne .r
    mov ah, 0x23
    int 0x23
.r:
    ret

lhs         dw 0
cur         dw 0
op          db 0
fresh       db 1
want_quit   db 0
pressed_btn db 0xFF
menu_open   db 0
menu_hl     db 0xFF

disp_x      dw 0
disp_y      dw 0
disp_w      dw 0
disp_h      dw 0
grid_top    dw 0
cell_w      dw 0
cell_h      dw 0

last_ox     dw 0
last_w      dw 0
last_h      dw 0

keys        db '789/456*123-0C=+'
keybuf      db 0, 0, 0, 0
numbuf      times 16 db 0

lbl_edit    db 'Edit', 0
mi_clear    db 'Clear', 0
mi_neg      db 'Negate', 0
mi_quit     db 'Quit', 0
menu_tbl    dw mi_clear, mi_neg, mi_quit

%include "grafx.inc"
%include "surf.inc"

PLE_END
