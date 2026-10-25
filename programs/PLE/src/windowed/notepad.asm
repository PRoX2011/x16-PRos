; ==================================================================
; x16-PRos -- NOTEPAD. Simple text editor.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "Text editor", "PRoX-dev", 0, 0xFFF0
PLE_LOGO          "logo/notepad.raw"

%define SURF_TEXT
%define SURF_PICK

TEXT_CAP    equ 0xE000
MB_H        equ 18
MENU_X      equ 2
MENU_W      equ 120
MENU_N      equ 3

start:
    push cs
    pop es
    mov byte [surf_keys], 1
    mov byte [ss:0], 0
    call new_text
.redraw:
    call surf_sync
    call redraw
.loop:
    call surf_idle
    call surf_sync
    cmp byte [surf_close], 0
    jne quit
    cmp byte [surf_dirty], 0
    jne .redraw
    call surf_input
    cmp byte [menu_open], 0
    jne .menu
    mov ax, [surf_key]
    cmp al, 27
    jne .keys
    cmp byte [surf_windowed], 0
    je quit
.keys:
    xor bx, bx
    cmp al, 0x0F
    je .act
    mov bl, 2
    cmp al, 0x13
    je .act
    mov bx, edit
    test ax, ax
    jz .mouse
    call surf_tf_key
.mouse:
    call surf_tf_click
    cmp byte [surf_mpress], 0
    je .loop
    mov cx, MENU_X
    xor dx, dx
    mov si, 40
    mov di, MB_H
    call surf_in_rect
    jnc .loop
    mov byte [menu_open], 1
    jmp .redraw
.menu:
    cmp byte [surf_mpress], 0
    je .loop
    mov byte [menu_open], 0
    mov cx, MENU_X
    mov dx, MB_H
    mov si, MENU_W
    mov di, MENU_N
    call surf_menu_hit
    cmp al, 2
    je quit
    ja .redraw
    xor ah, ah
    shl ax, 1
    mov bx, ax
.act:
    call [menu_acts + bx]
    jmp .redraw

quit:
    cmp byte [surf_windowed], 1
    je .wexit
    mov ah, 0x0C
    int 0x21
    retf
.wexit:
    mov ah, 0x12
    int 0x23
    jmp .wexit

redraw:
    pusha
    call surf_begin_paint
    mov al, 15
    call surf_clear
    mov cx, MENU_X + 4
    mov dx, 1
    mov si, s_file
    xor al, al
    call surf_print
    mov cx, MENU_X + 56
    mov si, fpath
    call surf_print
    mov ax, [surf_w]
    sub ax, 4
    shr ax, 3
    mov [edit + SURF_TF_COLS], ax
    mov ax, [surf_h]
    sub ax, MB_H + 4
    shr ax, 4
    jnz .rows
    inc ax
.rows:
    mov [edit + SURF_TF_ROWS], ax
    mov bx, edit
    call surf_tf_draw
    cmp byte [menu_open], 0
    je .done
    mov cx, MENU_X
    mov dx, MB_H
    mov si, MENU_W
    mov di, MENU_N
    mov bx, menu_items
    mov al, 0xFF
    call surf_menu
.done:
    call surf_end_paint
    popa
    ret

new_text:
    push es
    push ss
    pop es
    xor ax, ax
    mov bx, edit
    xor cx, cx
    mov dx, MB_H
    mov si, [edit + SURF_TF_COLS]
    mov di, [edit + SURF_TF_ROWS]
    mov bp, TEXT_CAP
    call surf_te_init
    pop es
    ret

open_file:
    mov si, s_open
    mov di, fpath
    call surf_pick
    jc .done
    mov si, fpath
    call surf_path_go
    jc .done
    mov ax, 0x1500
    int 0x22
    jc .back
    test cx, cx
    jnz .close
    cmp dx, TEXT_CAP - 1
    jae .close
    mov cx, dx
    mov dx, ss
    xor di, di
    mov ax, 0x1501
    int 0x22
    push bx
    mov cx, ax
    push ds
    push ss
    pop ds
    push ss
    pop es
    xor si, si
    xor di, di
.strip:
    jcxz .end
    lodsb
    dec cx
    cmp al, 13
    je .strip
    stosb
    jmp .strip
.end:
    mov byte [di], 0
    pop ds
    push ds
    pop es
    call new_text
    pop bx
.close:
    mov ax, 0x1504
    int 0x22
.back:
    call surf_path_back
.done:
    ret

save_file:
    cmp byte [fpath], 0
    jne .write
    mov si, s_save
    mov di, fpath
    call surf_pick
    jc .done
.write:
    mov si, fpath
    call surf_path_go
    jc .done
    xor cx, cx
    mov dx, ss
    mov bx, [edit + SURF_TF_LEN]
    xor di, di
    mov ah, 0x13
    int 0x22
    call surf_path_back
.done:
    ret

menu_items  dw s_m_open, s_m_save, s_m_exit
menu_acts   dw open_file, save_file
s_m_open    db 'Open   Ctrl+O', 0
s_m_save    db 'Save   Ctrl+S', 0
s_m_exit    db 'Exit', 0
s_file      db 'File', 0
s_open      db 'Open', 0
s_save      db 'Save as', 0
menu_open   db 0

%include "grafx.inc"
%include "surf.inc"

edit        times SURF_TF_SIZE db 0
fpath       times SURF_PICK_PATH db 0

PLE_END
