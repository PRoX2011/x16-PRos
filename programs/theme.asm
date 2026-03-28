; ==================================================================
; x16-PRos -- THEME. Theme selector for x16-PRos
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

ENTRY_SIZE      equ 18
FNAME_SIZE      equ 13
MAX_FILES       equ 32
VISIBLE_LINES   equ 14

BOX_X           equ 22
BOX_Y           equ 5
BOX_W           equ 36
BOX_H           equ 20

LIST_X          equ BOX_X + 3
LIST_Y          equ BOX_Y + 3

ATTR_NORMAL     equ 0x0F
ATTR_HIGHLIGHT  equ 0x70
ATTR_BORDER     equ 0x0F
ATTR_DIM        equ 0x07
ATTR_TITLE_BAR  equ 0x1F
ATTR_HINT_BAR   equ 0x1F
ATTR_BG_COLOR   equ 0x00
ATTR_OK_MSG     equ 0x0A
ATTR_ERR_MSG    equ 0x0C

THM_BUF         equ 43008

jmp start

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"
%include "programs/lib/string.inc"

start:
    mov ah, 0x06
    int 0x21

    push cs
    pop ds
    push cs
    pop es
    cld
    call tui_init

    call load_theme_list
    cmp word [file_count], 0
    je .no_themes

    mov word [selected], 0
    mov word [scroll_top], 0

    call draw_screen

.main_loop:
    call tui_wait_for_key

    cmp al, 27
    je .exit
    cmp ah, 0x48
    je .move_up
    cmp ah, 0x50
    je .move_down
    cmp al, 13
    je .apply_theme
    jmp .main_loop

.move_up:
    cmp word [selected], 0
    je .main_loop
    dec word [selected]
    mov ax, [selected]
    cmp ax, [scroll_top]
    jge .redraw
    dec word [scroll_top]
.redraw:
    call draw_list
    jmp .main_loop

.move_down:
    mov ax, [selected]
    inc ax
    cmp ax, [file_count]
    jge .main_loop
    mov [selected], ax
    mov bx, [scroll_top]
    add bx, VISIBLE_LINES
    cmp ax, bx
    jl .redraw2
    inc word [scroll_top]
.redraw2:
    call draw_list
    jmp .main_loop

.apply_theme:
    ; Save current directory
    mov ah, 0x0E
    int 0x22

    ; Goto root
    mov ah, 0x0A
    int 0x22

    ; Enter THEMES.DIR
    mov ah, 0x09
    mov si, themes_dir_name
    int 0x22
    jc .apply_fail
 
    call get_selected_name
    mov si, ax
    mov cx, THM_BUF
    xor bx, bx
    mov ah, 0x02
    int 0x22
    jc .apply_fail

    ; Save file size
    mov [thm_file_size], bx

    ; Go back to root
    mov ah, 0x0A
    int 0x22

    ; Enter CONF.DIR
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22
    jc .apply_fail

    mov ah, 0x03
    mov si, theme_cfg_file
    mov bx, THM_BUF
    mov cx, [thm_file_size]
    int 0x22
    jc .apply_fail

    ; Restore directory
    mov ah, 0x0F
    int 0x22

    call draw_screen

    mov si, ok_msg
    mov cl, BOX_X + 3
    mov ch, BOX_Y + BOX_H
    mov bl, ATTR_OK_MSG
    call font_print_string
    jmp .main_loop

.apply_fail:
    ; Restore directory if error
    mov ah, 0x0F
    int 0x22

    call draw_screen

    mov si, err_msg
    mov cl, BOX_X + 3
    mov ch, BOX_Y + BOX_H
    mov bl, ATTR_ERR_MSG
    call font_print_string
    jmp .main_loop

.no_themes:
    call draw_bg

    mov si, no_themes_msg
    mov cl, 28
    mov ch, 14
    mov bl, ATTR_ERR_MSG
    call font_print_string
    call tui_wait_for_key

.exit:
    mov ax, 0x0012
    int 0x10
    ret

; ==================================================================
; get_selected_name -- Return pointer to selected theme filename
; OUT: AX = pointer to filename string
; ==================================================================
get_selected_name:
    push bx
    push dx
    mov ax, [selected]
    mov bx, FNAME_SIZE
    mul bx
    add ax, name_list
    pop dx
    pop bx
    ret

; ==================================================================
; load_theme_list -- Read THEMES.DIR/ and build name_list[]
; ==================================================================
load_theme_list:
    pusha

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov si, themes_dir_name
    mov ah, 0x09
    int 0x22
    jc .done

    mov ah, 0x01
    mov si, file_list_buf
    int 0x22

    mov ah, 0x0F
    int 0x22

    mov word [file_count], 0
    mov si, file_list_buf
    mov di, name_list

.scan:
    cmp byte [si], 0
    je .done

    test byte [si+16], 0x10
    jnz .skip

    ; Check extension is 'THM'
    cmp byte [si+9], 'T'
    jne .skip
    cmp byte [si+10], 'H'
    jne .skip
    cmp byte [si+11], 'M'
    jne .skip

    push si
    push di

    mov cx, 8
.copy_name:
    lodsb
    cmp al, ' '
    je .name_pad
    stosb
    dec cx
    jnz .copy_name
    jmp .add_ext
.name_pad:
    dec cx
    add si, cx

.add_ext:
    mov al, '.'
    stosb
    mov al, 'T'
    stosb
    mov al, 'H'
    stosb
    mov al, 'M'
    stosb
    xor al, al
    stosb

    pop di
    pop si

    add di, FNAME_SIZE
    inc word [file_count]
    cmp word [file_count], MAX_FILES
    jge .done

.skip:
    add si, ENTRY_SIZE
    jmp .scan

.done:
    popa
    ret

; ==================================================================
; Drawing routines
; ==================================================================

draw_screen:
    call draw_bg
    call draw_box
    call draw_list
    ret

draw_bg:
    pusha

    mov al, ATTR_BG_COLOR
    call font_clear_screen

    mov al, ATTR_TITLE_BAR >> 4
    mov ch, 0
    call font_fill_row

    mov si, title_str
    mov cl, 2
    mov ch, 0
    mov bl, ATTR_TITLE_BAR
    call font_print_string

    mov al, ATTR_HINT_BAR >> 4
    mov ch, 29
    call font_fill_row

    mov si, hint_str
    mov cl, 1
    mov ch, 29
    mov bl, ATTR_HINT_BAR
    call font_print_string

    popa
    ret

draw_box:
    pusha

    mov cl, BOX_X
    mov ch, BOX_Y
    mov dl, BOX_W
    mov dh, BOX_H
    mov bl, ATTR_BORDER
    call tui_draw_box

    mov si, box_title
    mov cl, BOX_X + 2
    mov ch, BOX_Y + 1
    mov bl, ATTR_DIM
    call font_print_string

    popa
    ret

draw_list:
    pusha

    mov al, ATTR_BORDER >> 4
    mov cl, LIST_X - 1
    mov ch, LIST_Y
    mov dl, BOX_W - 4
    mov dh, VISIBLE_LINES
    call font_fill_rect

    cmp word [file_count], 0
    je .done

    mov word [.vis], 0
    mov ax, [scroll_top]
    mov [.idx], ax

.loop:
    mov ax, [.vis]
    cmp ax, VISIBLE_LINES
    jge .done

    mov ax, [.idx]
    cmp ax, [file_count]
    jge .done

    mov bx, FNAME_SIZE
    mul bx
    add ax, name_list
    mov [.name_ptr], ax

    mov ax, [.idx]
    cmp ax, [selected]
    jne .not_sel

    ; Highlight row background
    mov al, [.vis]
    add al, LIST_Y
    mov ch, al
    mov al, ATTR_HIGHLIGHT >> 4
    mov cl, LIST_X - 1
    mov dl, BOX_W - 4
    mov dh, 1
    call font_fill_rect

    ; Arrow indicator
    mov al, 0x10
    mov cl, LIST_X
    mov ch, [.vis]
    add ch, LIST_Y
    mov bl, ATTR_HIGHLIGHT
    call font_put_char

    mov si, [.name_ptr]
    mov cl, LIST_X + 2
    mov ch, [.vis]
    add ch, LIST_Y
    mov bl, ATTR_HIGHLIGHT
    call font_print_string

    jmp .next

.not_sel:
    mov si, [.name_ptr]
    mov cl, LIST_X + 2
    mov ch, [.vis]
    add ch, LIST_Y
    mov bl, ATTR_NORMAL
    call font_print_string

.next:
    inc word [.vis]
    inc word [.idx]
    jmp .loop

.done:
    popa
    ret

.vis      dw 0
.idx      dw 0
.name_ptr dw 0

; ==================================================================
; Data section
; ==================================================================

section .data

title_str       db 'THEME SELECTOR', 0
hint_str        db ' Up/Down: Select   Enter: Apply   Esc: Exit', 0
box_title       db 'Available themes:', 0
no_themes_msg   db 'No .THM files in THEMES.DIR/', 0
ok_msg          db 'Theme applied!', 0
err_msg         db 'Failed to apply theme!', 0
themes_dir_name db 'THEMES.DIR', 0
conf_dir_name   db 'CONF.DIR', 0
theme_cfg_file  db 'THEME.CFG', 0

selected        dw 0
scroll_top      dw 0
file_count      dw 0
thm_file_size   dw 0

file_list_buf   times 2048 db 0
name_list       times MAX_FILES * FNAME_SIZE db 0