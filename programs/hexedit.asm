; ==================================================================
; x16-PRos -- HEXEDIT. Hex editor for x16-PRos
; Copyright (C) 2025 PRoX2011
;
; Usage: hexedit <filename>
;
; Shortcuts:
;   Ctrl+X   - Exit
;   Ctrl+O   - Save
;   Ctrl+G   - Goto
;   Ctrl+R   - Revert
;   Tab      - Hex/ASCII toggle
;   F1       - Help
;   Arrows   - Navigate
;   Home/End - Line start/end
;   PgUp/PgDn - Page scroll
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

FILE_BUFFER      equ 0xE000
FILE_BUFFER_SIZE equ 16384
SAVE_BUFFER      equ 0xA800
SAVE_BUFFER_MAX  equ 0x3800
DIRTY_MAP        equ 0xB800

LINES_PER_PAGE   equ 24
BYTES_PER_LINE   equ 16
BYTES_PER_PAGE   equ 384

HEADER_ROW       equ 1
DATA_ROW_FIRST   equ 2
SEPARATOR_ROW    equ 26
INFO_ROW         equ 27

COL_HEX_START    equ 6
COL_ASCII_PIPE   equ 56
COL_ASCII_START  equ 57
COL_ASCII_END    equ 73

KEY_CTRL_X  equ 0x18
KEY_CTRL_O  equ 0x0F
KEY_CTRL_G  equ 0x07
KEY_CTRL_F  equ 0x06
KEY_CTRL_R  equ 0x12
KEY_TAB     equ 0x09

SCAN_UP     equ 0x48
SCAN_DOWN   equ 0x50
SCAN_LEFT   equ 0x4B
SCAN_RIGHT  equ 0x4D
SCAN_HOME   equ 0x47
SCAN_END    equ 0x4F
SCAN_PGUP   equ 0x49
SCAN_PGDN   equ 0x51
SCAN_F1     equ 0x3B

ATTR_HEADER      equ 0x1E
ATTR_OFFSET      equ 0x03
ATTR_NORM        equ 0x07
ATTR_CURSOR_ACT  equ 0x70
ATTR_CURSOR_DIM  equ 0x17
ATTR_DIRTY       equ 0x0E
ATTR_NONPRINT    equ 0x08
ATTR_PIPE        equ 0x08
ATTR_SEP         equ 0x08
ATTR_STATUS      equ 0x0E

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

    mov word [cursor_pos], 0
    mov word [scroll_off], 0
    mov word [file_size], 0
    mov byte [modified], 0
    mov byte [panel], 0
    mov byte [nibble], 0
    mov byte [filename], 0
    mov byte [status_msg], 0

    cmp si, 0
    je .no_file
    cmp byte [si], 0
    je .no_file

    push si
    mov di, filename
    mov cx, 12
.cp:
    lodsb
    cmp al, 0
    je .cp_end
    cmp al, ' '
    je .cp_end
    stosb
    loop .cp
.cp_end:
    mov byte [di], 0
    pop si

    call load_file
    cmp word [file_size], 0
    je .load_fail

    call draw_bg
    call full_render
    jmp main_loop

.no_file:
    mov si, err_noargs
    mov cl, 2
    mov ch, 14
    mov bl, 0x0C
    call font_print_string
    call tui_wait_for_key
    jmp do_exit

.load_fail:
    mov si, err_loadfail
    mov cl, 2
    mov ch, 14
    mov bl, 0x0C
    call font_print_string
    call tui_wait_for_key
    jmp do_exit


main_loop:
    call update_status
    call draw_cursor
    call tui_wait_for_key
    call erase_cursor

    cmp al, KEY_CTRL_X
    je near exit_handler
    cmp al, KEY_CTRL_O
    je near save_handler
    cmp al, KEY_CTRL_G
    je near goto_handler
    cmp al, KEY_CTRL_F
    je near find_handler
    cmp al, KEY_CTRL_R
    je near revert_handler
    cmp al, KEY_TAB
    je near toggle_panel

    cmp ah, SCAN_UP
    je near nav_up
    cmp ah, SCAN_DOWN
    je near nav_down
    cmp ah, SCAN_LEFT
    je near nav_left
    cmp ah, SCAN_RIGHT
    je near nav_right
    cmp ah, SCAN_HOME
    je near nav_home
    cmp ah, SCAN_END
    je near nav_end
    cmp ah, SCAN_PGUP
    je near nav_pgup
    cmp ah, SCAN_PGDN
    je near nav_pgdn
    cmp ah, SCAN_F1
    je near help_handler

    cmp word [file_size], 0
    je main_loop

    cmp byte [panel], 0
    jne .ascii_in
    call is_hex_char
    jnc main_loop
    call hex_input
    jmp main_loop
.ascii_in:
    cmp al, 0x20
    jb main_loop
    cmp al, 0x7E
    ja main_loop
    call ascii_input
    jmp main_loop


draw_bg:
    pusha
    mov ax, title_str
    mov bx, shortcut_str
    call tui_draw_background

    mov al, 0x00
    mov ch, TUI_STATUS_ROW
    call font_fill_row

    mov si, header_str
    mov cl, 0
    mov ch, HEADER_ROW
    mov bl, 0x0E
    call font_print_string

    mov al, TUI_LINE_H
    mov ch, SEPARATOR_ROW
    mov bl, ATTR_SEP
    call tui_draw_horiz_line

    popa
    ret


full_render:
    pusha
    mov al, 0x00
    mov cl, 0
    mov ch, DATA_ROW_FIRST
    mov dl, 80
    mov dh, LINES_PER_PAGE
    call font_fill_rect

    mov byte [fr_ln], 0
.loop:
    cmp byte [fr_ln], LINES_PER_PAGE
    jge .done

    xor ah, ah
    mov al, [fr_ln]
    shl ax, 4
    add ax, [scroll_off]
    cmp ax, [file_size]
    jge .next

    mov [fr_off], ax
    mov al, [fr_ln]
    add al, DATA_ROW_FIRST
    mov [fr_row], al
    call render_line

.next:
    inc byte [fr_ln]
    jmp .loop
.done:
    popa
    ret

fr_ln  db 0
fr_off dw 0
fr_row db 0

render_line:
    pusha

    mov ax, [fr_off]
    push ax
    mov al, ah
    mov cl, 0
    mov ch, [fr_row]
    mov bl, ATTR_OFFSET
    call put_hex_byte
    pop ax
    mov cl, 2
    mov ch, [fr_row]
    mov bl, ATTR_OFFSET
    call put_hex_byte
    mov al, ':'
    mov cl, 4
    mov ch, [fr_row]
    mov bl, ATTR_OFFSET
    call font_put_char

    xor cx, cx
.byte_loop:
    cmp cx, 16
    jge .pipes

    mov ax, [fr_off]
    add ax, cx
    cmp ax, [file_size]
    jge .skip_byte

    push cx
    mov [rl_fpos], ax
    mov si, FILE_BUFFER
    add si, ax
    mov al, [si]
    mov [rl_val], al

    mov ax, [rl_fpos]
    call check_dirty
    jz .clean
    mov byte [rl_attr], ATTR_DIRTY
    jmp .draw_hex
.clean:
    mov byte [rl_attr], ATTR_NORM

.draw_hex:
    pop cx
    push cx
    mov ax, cx
    call get_hex_col
    mov al, [rl_val]
    mov ch, [fr_row]
    mov bl, [rl_attr]
    call put_hex_byte

    pop cx
    push cx
    mov al, cl
    add al, COL_ASCII_START
    mov cl, al
    mov al, [rl_val]
    mov bl, [rl_attr]
    cmp al, 0x20
    jb .dot
    cmp al, 0x7E
    ja .dot
    jmp .put_asc
.dot:
    mov al, '.'
    mov bl, ATTR_NONPRINT
.put_asc:
    mov ch, [fr_row]
    call font_put_char
    pop cx

.skip_byte:
    inc cx
    jmp .byte_loop

.pipes:
    mov al, '|'
    mov cl, COL_ASCII_PIPE
    mov ch, [fr_row]
    mov bl, ATTR_PIPE
    call font_put_char
    mov al, '|'
    mov cl, COL_ASCII_END
    mov ch, [fr_row]
    mov bl, ATTR_PIPE
    call font_put_char

    popa
    ret

rl_fpos dw 0
rl_val  db 0
rl_attr db 0

draw_cursor:
    pusha
    call calc_cursor
    cmp byte [cc_vis], 0
    je .done

    mov si, FILE_BUFFER
    add si, [cursor_pos]
    mov al, [si]
    mov [cc_val], al

    mov ax, [cc_bidx]
    call get_hex_col
    mov al, [cc_val]
    mov ch, [cc_row]
    cmp byte [panel], 0
    jne .hdim
    mov bl, ATTR_CURSOR_ACT
    jmp .hput
.hdim:
    mov bl, ATTR_CURSOR_DIM
.hput:
    call put_hex_byte

    mov ax, [cc_bidx]
    add al, COL_ASCII_START
    mov cl, al
    mov al, [cc_val]
    cmp al, 0x20
    jb .adot
    cmp al, 0x7E
    ja .adot
    jmp .aput
.adot:
    mov al, '.'
.aput:
    mov ch, [cc_row]
    cmp byte [panel], 1
    jne .adim
    mov bl, ATTR_CURSOR_ACT
    jmp .adraw
.adim:
    mov bl, ATTR_CURSOR_DIM
.adraw:
    call font_put_char
.done:
    popa
    ret

erase_cursor:
    pusha
    call calc_cursor
    cmp byte [cc_vis], 0
    je .done

    mov si, FILE_BUFFER
    add si, [cursor_pos]
    mov al, [si]
    mov [cc_val], al

    mov ax, [cursor_pos]
    call check_dirty
    jz .clean
    mov byte [cc_attr], ATTR_DIRTY
    jmp .hex
.clean:
    mov byte [cc_attr], ATTR_NORM
.hex:
    mov ax, [cc_bidx]
    call get_hex_col
    mov al, [cc_val]
    mov ch, [cc_row]
    mov bl, [cc_attr]
    call put_hex_byte

    mov ax, [cc_bidx]
    add al, COL_ASCII_START
    mov cl, al
    mov al, [cc_val]
    mov bl, [cc_attr]
    cmp al, 0x20
    jb .dot
    cmp al, 0x7E
    ja .dot
    jmp .adraw
.dot:
    mov al, '.'
    mov bl, ATTR_NONPRINT
.adraw:
    mov ch, [cc_row]
    call font_put_char
.done:
    popa
    ret

calc_cursor:
    push ax
    push bx
    mov byte [cc_vis], 0
    mov ax, [cursor_pos]
    cmp ax, [file_size]
    jge .no
    cmp ax, [scroll_off]
    jb .no
    sub ax, [scroll_off]
    cmp ax, BYTES_PER_PAGE
    jge .no
    mov bx, ax
    shr ax, 4
    add al, DATA_ROW_FIRST
    mov [cc_row], al
    and bx, 0x0F
    mov [cc_bidx], bx
    mov byte [cc_vis], 1
.no:
    pop bx
    pop ax
    ret

cc_vis  db 0
cc_row  db 0
cc_bidx dw 0
cc_val  db 0
cc_attr db 0

update_status:
    pusha

    mov al, 0x00
    mov ch, TUI_STATUS_ROW
    call font_fill_row

    mov al, 0x00
    mov ch, INFO_ROW
    call font_fill_row

    ; Title bar
    mov al, TUI_TITLE_ATTR >> 4
    mov ch, 0
    call font_fill_row
    mov si, title_str
    mov cl, 2
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string

    cmp byte [filename], 0
    je .no_fn
    mov si, str_dash
    mov cl, 16
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
    mov si, filename
    mov cl, 19
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
    cmp byte [modified], 0
    je .no_fn
    mov si, str_star
    mov cl, 34
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
.no_fn:

    ; Mode
    cmp byte [panel], 0
    jne .asc
    mov si, str_hex
    jmp .pm
.asc:
    mov si, str_ascii
.pm:
    mov cl, 2
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

    ; Offset
    mov si, str_off
    mov cl, 14
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

    mov ax, [cursor_pos]
    call hex_word_to_str
    mov si, hex_buf
    mov cl, 22
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

    ; Byte value
    mov ax, [cursor_pos]
    cmp ax, [file_size]
    jge .no_val

    mov si, str_val
    mov cl, 30
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

    mov si, FILE_BUFFER
    add si, [cursor_pos]
    xor ah, ah
    mov al, [si]
    push ax
    call hex_byte_to_str
    mov si, hex_buf
    mov cl, 35
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string
    mov al, 'h'
    mov cl, 37
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_put_char

    ; Decimal value in parens
    mov al, '('
    mov cl, 39
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_put_char
    pop ax
    call string_int_to_string
    mov si, ax
    mov cl, 40
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

.no_val:

    ; File size
    mov si, str_size
    mov cl, 48
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string
    mov ax, [file_size]
    call string_int_to_string
    mov si, ax
    mov cl, 54
    mov ch, TUI_STATUS_ROW
    mov bl, ATTR_STATUS
    call font_print_string

    ; Modified flag
    cmp byte [modified], 0
    je .no_mod
    mov si, str_mod
    mov cl, 65
    mov ch, TUI_STATUS_ROW
    mov bl, 0x0C
    call font_print_string
.no_mod:

    ; Status message on info row
    cmp byte [status_msg], 0
    je .no_msg
    mov si, status_msg
    mov cl, 2
    mov ch, INFO_ROW
    mov bl, 0x0A
    call font_print_string
    mov byte [status_msg], 0
.no_msg:

    popa
    ret

nav_up:
    cmp word [cursor_pos], 16
    jb .done
    sub word [cursor_pos], 16
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
.done:
    jmp main_loop

nav_down:
    mov ax, [cursor_pos]
    and ax, 0xFFF0
    add ax, BYTES_PER_LINE
    cmp ax, [file_size]
    jge .done
    mov ax, [cursor_pos]
    add ax, BYTES_PER_LINE
    mov bx, [file_size]
    dec bx
    cmp ax, bx
    jbe .set
    mov ax, bx
.set:
    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
.done:
    jmp main_loop

nav_left:
    cmp word [cursor_pos], 0
    je .done
    dec word [cursor_pos]
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
.done:
    jmp main_loop

nav_right:
    mov ax, [cursor_pos]
    inc ax
    cmp ax, [file_size]
    jge .done
    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
.done:
    jmp main_loop

nav_home:
    mov ax, [cursor_pos]
    and ax, 0xFFF0
    mov [cursor_pos], ax
    mov byte [nibble], 0
    jmp main_loop

nav_end:
    cmp word [file_size], 0
    je .done
    mov ax, [cursor_pos]
    or ax, 0x000F
    mov bx, [file_size]
    dec bx
    cmp ax, bx
    jbe .set
    mov ax, bx
.set:
    mov [cursor_pos], ax
    mov byte [nibble], 0
.done:
    jmp main_loop

nav_pgup:
    mov ax, [cursor_pos]
    cmp ax, BYTES_PER_PAGE
    jb .zero
    sub ax, BYTES_PER_PAGE
    jmp .set
.zero:
    xor ax, ax
.set:
    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
    jmp main_loop

nav_pgdn:
    cmp word [file_size], 0
    je .done
    mov ax, [cursor_pos]
    add ax, BYTES_PER_PAGE
    mov bx, [file_size]
    dec bx
    cmp ax, bx
    jbe .set
    mov ax, bx
.set:
    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
    call full_render
.done:
    jmp main_loop

toggle_panel:
    xor byte [panel], 1
    mov byte [nibble], 0
    jmp main_loop

adjust_scroll:
    pusha
    mov ax, [cursor_pos]
    cmp ax, [scroll_off]
    jge .chk_below
    and ax, 0xFFF0
    mov [scroll_off], ax
    jmp .done
.chk_below:
    mov bx, [scroll_off]
    add bx, BYTES_PER_PAGE
    cmp ax, bx
    jb .done
    and ax, 0xFFF0
    sub ax, (LINES_PER_PAGE - 1) * BYTES_PER_LINE
    cmp ax, 0
    jge .set
    xor ax, ax
.set:
    mov [scroll_off], ax
.done:
    popa
    ret

hex_input:
    pusha
    call char_to_hex_val
    mov [hi_nv], al

    mov bx, [cursor_pos]
    mov si, FILE_BUFFER
    add si, bx
    mov al, [si]

    cmp byte [nibble], 0
    jne .low

    and al, 0x0F
    mov cl, [hi_nv]
    shl cl, 4
    or al, cl
    mov [si], al
    mov byte [nibble], 1
    mov ax, bx
    call set_dirty
    jmp .mark

.low:
    and al, 0xF0
    or al, [hi_nv]
    mov [si], al
    mov byte [nibble], 0
    mov ax, bx
    call set_dirty
    inc bx
    cmp bx, [file_size]
    jge .mark
    mov [cursor_pos], bx
    call adjust_scroll

.mark:
    mov byte [modified], 1
    call full_render
    popa
    ret

hi_nv db 0

ascii_input:
    pusha
    mov bx, [cursor_pos]
    cmp bx, [file_size]
    jge .done
    mov si, FILE_BUFFER
    add si, bx
    mov [si], al
    mov byte [modified], 1
    mov ax, bx
    call set_dirty
    inc bx
    cmp bx, [file_size]
    jge .done
    mov [cursor_pos], bx
    call adjust_scroll
.done:
    call full_render
    popa
    ret

save_handler:
    pusha
    cmp word [file_size], 0
    je .done
    call copy_to_save_buf
    mov si, filename
    mov bx, SAVE_BUFFER
    mov cx, [file_size]
    cmp cx, SAVE_BUFFER_MAX
    jbe .sz_ok
    mov cx, SAVE_BUFFER_MAX
.sz_ok:
    mov ah, 0x03
    int 0x22
    jc .fail
    call copy_from_save_buf
    mov byte [modified], 0
    call clear_dirty
    mov si, .ok
    mov di, status_msg
    call copy_str
    jmp .done
.fail:
    call copy_from_save_buf
    mov si, .err
    mov di, status_msg
    call copy_str
.done:
    popa
    call draw_bg
    call full_render
    jmp main_loop
.ok  db '[ Saved successfully ]', 0
.err db '[ Save FAILED ]', 0

goto_handler:
    mov ax, .prompt
    mov di, input_buf
    mov si, 8
    call tui_input_dialog
    jc .cancel

    mov si, input_buf
    call hex_str_to_word
    jnc .cancel
    cmp ax, [file_size]
    jge .cancel

    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
.cancel:
    call draw_bg
    call full_render
    jmp main_loop
.prompt db 'Go to offset (hex, e.g. 1A0):', 0

find_handler:
    mov ax, .prompt
    mov di, input_buf
    mov si, 32
    call tui_input_dialog
    jc .cancel

    mov si, input_buf
    mov di, find_buf
    call parse_hex_str
    cmp cx, 0
    je .cancel
    mov [find_len], cx

    call search_fwd
    jnc .nf

    mov [cursor_pos], ax
    mov byte [nibble], 0
    call adjust_scroll
    mov si, .found
    mov di, status_msg
    call copy_str
    jmp .show
.nf:
    mov si, .notfound
    mov di, status_msg
    call copy_str
.show:
.cancel:
    call draw_bg
    call full_render
    jmp main_loop
.prompt   db 'Find hex (e.g. FF 00 AB):', 0
.found    db '[ Found ]', 0
.notfound db '[ Not found ]', 0

revert_handler:
    mov ax, .q1
    mov bx, .q2
    mov cx, 0
    mov dx, 1
    call tui_dialog_box
    cmp ax, 0
    jne .cancel

    call load_file
    mov word [cursor_pos], 0
    mov word [scroll_off], 0
    mov byte [nibble], 0
.cancel:
    call draw_bg
    call full_render
    jmp main_loop
.q1 db 'Discard all changes and reload?', 0
.q2 db 0

help_handler:
    mov ax, .h1
    mov bx, .h2
    mov cx, .h3
    mov dx, 0
    call tui_dialog_box
    call draw_bg
    call full_render
    jmp main_loop
.h1 db 'Arrows: Navigate  Tab: Hex/ASCII', 0
.h2 db '^O:     Save      ^G: Goto  ^R: Revert', 0
.h3 db '^X:     Exit      ^F: Find', 0

exit_handler:
    cmp byte [modified], 0
    je do_exit

    mov ax, exit_q1
    mov bx, exit_q2
    mov cx, 0
    mov dx, 1
    call tui_dialog_box
    cmp ax, 0
    jne do_exit

    call copy_to_save_buf
    mov si, filename
    mov bx, SAVE_BUFFER
    mov cx, [file_size]
    cmp cx, SAVE_BUFFER_MAX
    jbe .esz_ok
    mov cx, SAVE_BUFFER_MAX
.esz_ok:
    mov ah, 0x03
    int 0x22

do_exit:
    mov ax, 0x0012
    int 0x10
    ret

exit_q1 db 'Unsaved changes. Save before exit?', 0
exit_q2 db 0

load_file:
    pusha
    cmp byte [filename], 0
    je .done

    mov si, filename
    mov ah, 0x02
    mov cx, FILE_BUFFER
    int 0x22
    jc .fail

    cmp bx, FILE_BUFFER_SIZE
    jbe .ok
    mov bx, FILE_BUFFER_SIZE
.ok:
    mov [file_size], bx
    mov byte [modified], 0
    call clear_dirty
    jmp .done
.fail:
    mov word [file_size], 0
.done:
    popa
    ret

put_hex_byte:
    pusha
    mov [phb_v], al
    mov [phb_c], cl
    mov [phb_r], ch
    mov [phb_a], bl

    mov al, [phb_v]
    shr al, 4
    call nibble_char
    mov cl, [phb_c]
    mov ch, [phb_r]
    mov bl, [phb_a]
    call font_put_char

    mov al, [phb_v]
    and al, 0x0F
    call nibble_char
    mov cl, [phb_c]
    inc cl
    mov ch, [phb_r]
    mov bl, [phb_a]
    call font_put_char

    popa
    ret

phb_v db 0
phb_c db 0
phb_r db 0
phb_a db 0

nibble_char:
    cmp al, 9
    jbe .dig
    add al, 'A' - 10
    ret
.dig:
    add al, '0'
    ret

get_hex_col:
    push ax
    push bx
    mov bx, ax
    mov cl, 3
    mul cl
    add al, COL_HEX_START
    cmp bx, 8
    jb .no
    inc al
.no:
    mov cl, al
    pop bx
    pop ax
    ret

is_hex_char:
    cmp al, '0'
    jb .no
    cmp al, '9'
    jbe .yes
    cmp al, 'A'
    jb .no
    cmp al, 'F'
    jbe .yes
    cmp al, 'a'
    jb .no
    cmp al, 'f'
    jbe .yes
.no:
    clc
    ret
.yes:
    stc
    ret

char_to_hex_val:
    cmp al, '9'
    jbe .dig
    cmp al, 'F'
    jbe .up
    sub al, 'a' - 10
    ret
.up:
    sub al, 'A' - 10
    ret
.dig:
    sub al, '0'
    ret

hex_word_to_str:
    pusha
    mov di, hex_buf
    push ax
    mov al, ah
    call .wb
    pop ax
    call .wb
    mov byte [di], 0
    popa
    ret
.wb:
    push ax
    shr al, 4
    call nibble_char
    stosb
    pop ax
    and al, 0x0F
    call nibble_char
    stosb
    ret

hex_byte_to_str:
    pusha
    mov di, hex_buf
    push ax
    shr al, 4
    call nibble_char
    stosb
    pop ax
    and al, 0x0F
    call nibble_char
    stosb
    mov byte [di], 0
    popa
    ret

hex_str_to_word:
    push bx
    push cx
    push si
    xor bx, bx
    xor cx, cx
.next:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .next
    call is_hex_char
    jnc .bad
    call char_to_hex_val
    shl bx, 4
    xor ah, ah
    or bx, ax
    inc cx
    jmp .next
.done:
    cmp cx, 0
    je .bad
    mov ax, bx
    pop si
    pop cx
    pop bx
    stc
    ret
.bad:
    pop si
    pop cx
    pop bx
    clc
    ret

parse_hex_str:
    push si
    push di
    push ax
    push bx
    xor cx, cx
.next:
    cmp byte [si], ' '
    jne .ns
    inc si
    jmp .next
.ns:
    cmp byte [si], 0
    je .done
    mov al, [si]
    call is_hex_char
    jnc .done
    call char_to_hex_val
    shl al, 4
    mov bl, al
    inc si
    cmp byte [si], 0
    je .single
    cmp byte [si], ' '
    je .single
    mov al, [si]
    call is_hex_char
    jnc .done
    call char_to_hex_val
    or bl, al
    inc si
.single:
    mov [di], bl
    inc di
    inc cx
    jmp .next
.done:
    pop bx
    pop ax
    pop di
    pop si
    ret

search_fwd:
    push bx
    push cx
    push dx
    push si
    push di
    mov bx, [cursor_pos]
    inc bx
.loop:
    mov ax, [file_size]
    sub ax, bx
    cmp ax, [find_len]
    jb .nf
    mov si, FILE_BUFFER
    add si, bx
    mov di, find_buf
    mov cx, [find_len]
.cmp:
    mov al, [si]
    cmp al, [di]
    jne .miss
    inc si
    inc di
    dec cx
    jnz .cmp
    mov ax, bx
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    stc
    ret
.miss:
    inc bx
    jmp .loop
.nf:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret

set_dirty:
    pusha
    mov bx, ax
    shr bx, 3
    and ax, 7
    mov cl, al
    mov al, 1
    shl al, cl
    or byte [DIRTY_MAP + bx], al
    popa
    ret

check_dirty:
    push bx
    push cx
    mov bx, ax
    shr bx, 3
    and ax, 7
    mov cl, al
    mov al, 1
    shl al, cl
    test byte [DIRTY_MAP + bx], al
    pop cx
    pop bx
    ret

clear_dirty:
    pusha
    push es
    push cs
    pop es
    mov di, DIRTY_MAP
    xor al, al
    mov cx, 2048
    cld
    rep stosb
    pop es
    popa
    ret

copy_str:
    pusha
.lp:
    lodsb
    stosb
    cmp al, 0
    jne .lp
    popa
    ret

copy_to_save_buf:
    pusha
    push es
    push cs
    pop es
    mov si, FILE_BUFFER
    mov di, SAVE_BUFFER
    mov cx, [file_size]
    cmp cx, SAVE_BUFFER_MAX
    jbe .ok
    mov cx, SAVE_BUFFER_MAX
.ok:
    cld
    rep movsb
    pop es
    popa
    ret

copy_from_save_buf:
    pusha
    push es
    push cs
    pop es
    mov si, SAVE_BUFFER
    mov di, FILE_BUFFER
    mov cx, [file_size]
    cmp cx, SAVE_BUFFER_MAX
    jbe .ok
    mov cx, SAVE_BUFFER_MAX
.ok:
    cld
    rep movsb
    pop es
    popa
    ret

; ==================================================================
; Data section
; ==================================================================

section .data

title_str    db 'HEXEDIT v2.0', 0
shortcut_str db '^X Exit  ^O Save  ^G Goto  ^F Find  ^R Revert  Tab Mode  F1 Help', 0
header_str   db 'Addr  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |     ASCII      |', 0

err_noargs   db 'Usage: hexedit <filename>', 0
err_loadfail db 'Error: Cannot load file', 0

str_dash  db ' - ', 0
str_star  db ' *', 0
str_hex   db 'Mode: HEX', 0
str_ascii db 'Mode: ASCII', 0
str_off   db 'Off: 0x', 0
str_val   db 'Val: ', 0
str_size  db 'Size: ', 0
str_mod   db 'Modified', 0

cursor_pos  dw 0
scroll_off  dw 0
file_size   dw 0
find_len    dw 0
modified    db 0
panel       db 0
nibble      db 0

section .bss
filename    resb 16 
status_msg  resb 30 
hex_buf     resb 8 
input_buf   resb 40 
find_buf    resb 32 