; ==================================================================
; x16-PRos -- LAUNCH. TUI Program Launcher for .BIN and .COM files
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

jmp start

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"

ENTRY_SIZE      equ 18
FENTRY_SIZE     equ 16
MAX_FILES       equ 64
VISIBLE_LINES   equ 23

TRAMPOLINE_ADDR equ 0xFC00
TRAMPOLINE_BIN  equ 0xFD00
TRAMPOLINE_SELF equ 0xFD10
TRAMPOLINE_FILE equ 0xFD20
TRAMPOLINE_FLAG equ 0xFD30
TRAMPOLINE_ARGS equ 0xFD31
TRAMPOLINE_MSG  equ 0xFD60

LIST_COL        equ 1
LIST_ROW        equ 3
LIST_WIDTH      equ 31

INFO_COL        equ 35
INFO_ROW        equ 2

SEP_COL         equ 33
ATTR_NORMAL     equ 0x0F
ATTR_HIGHLIGHT  equ 0x70
ATTR_TITLE_COL  equ 0x0E
ATTR_GRAY       equ 0x07
ATTR_BIN_BOX    equ 0x1F
ATTR_COM_BOX    equ 0x2F
ATTR_BIN_LABEL  equ 0x1E
ATTR_COM_LABEL  equ 0x2E

IC_COL          equ INFO_COL + 5
IC_ROW          equ INFO_ROW + 1
IC_W            equ 14
IC_H            equ 8

start:
    mov ah, 0x06
    int 0x21

    call tui_init

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov ah, 0x09
    mov si, bin_dir_name
    int 0x22

    mov ah, 0x01
    mov si, file_list_buf
    int 0x22

    call filter_files

    mov word [selected], 0
    mov word [scroll_top], 0

    call draw_ui
    call draw_file_list
    call draw_info_panel

    cmp word [file_count], 0
    jne .main_loop

    mov si, no_files_msg
    mov cl, 4
    mov ch, 14
    mov bl, 0x0C
    call font_print_string
    call tui_wait_for_key
    jmp .exit

.main_loop:
    call tui_wait_for_key

    cmp al, 27
    je .exit
    cmp ah, 0x48
    je .move_up
    cmp ah, 0x50
    je .move_down
    cmp al, 13
    je .do_launch
    cmp ax, 0x1C0A
    je .do_launch_arg
    jmp .main_loop

.move_up:
    cmp word [selected], 0
    je .main_loop
    dec word [selected]
    mov ax, [selected]
    cmp ax, [scroll_top]
    jge .redraw
    dec word [scroll_top]
    jmp .redraw

.move_down:
    mov ax, [selected]
    inc ax
    cmp ax, [file_count]
    jge .main_loop
    mov [selected], ax
    mov bx, [scroll_top]
    add bx, VISIBLE_LINES
    cmp ax, bx
    jl .redraw
    inc word [scroll_top]

.redraw:
    call draw_file_list
    call draw_info_panel
    jmp .main_loop

.do_launch:
    mov byte [launch_mode], 0
    call launch_common
    jmp .full_redraw

.do_launch_arg:
    mov ax, arg_prompt
    mov di, arg_buffer
    mov si, 30
    call tui_input_dialog
    jc .full_redraw
    mov byte [launch_mode], 1
    call launch_common

.full_redraw:
    call draw_ui
    call draw_file_list
    call draw_info_panel
    jmp .main_loop

.exit:
    mov ah, 0x0F
    int 0x22
    mov ax, 0x0012
    int 0x10
    ret

filter_files:
    pusha
    mov word [file_count], 0
    mov si, file_list_buf
    mov di, filtered_list

.fl_loop:
    cmp byte [si], 0
    je .fl_done

    test byte [si+16], 0x10
    jnz .fl_skip

    cmp byte [si+9], 'B'
    jne .fl_check_com
    cmp byte [si+10], 'I'
    jne .fl_check_com
    cmp byte [si+11], 'N'
    jne .fl_check_com
    mov byte [.ftype], 0
    jmp .fl_add

.fl_check_com:
    cmp byte [si+9], 'C'
    jne .fl_skip
    cmp byte [si+10], 'O'
    jne .fl_skip
    cmp byte [si+11], 'M'
    jne .fl_skip
    mov byte [.ftype], 1

.fl_add:
    push si
    push di

    mov cx, 9
.fl_copy_name:
    lodsb
    cmp al, ' '
    je .fl_name_pad
    stosb
    dec cx
    jnz .fl_copy_name
    jmp .fl_dot

.fl_name_pad:
    dec cx
    add si, cx

.fl_dot:
    mov al, '.'
    stosb

    mov cx, 3
.fl_copy_ext:
    lodsb
    cmp al, ' '
    je .fl_ext_done
    stosb
    dec cx
    jnz .fl_copy_ext
    jmp .fl_null

.fl_ext_done:
.fl_null:
    xor al, al
    stosb

    pop di
    pop si

    mov ax, [si+12]
    mov [di+14], ax

    mov al, [.ftype]
    mov [di+13], al

    add di, FENTRY_SIZE
    inc word [file_count]
    cmp word [file_count], MAX_FILES
    jge .fl_done

.fl_skip:
    add si, ENTRY_SIZE
    jmp .fl_loop

.fl_done:
    popa
    ret

.ftype db 0

draw_ui:
    pusha

    mov ax, title_str
    mov bx, shortcut_str
    call tui_draw_background

    mov byte [.row], 1
.draw_sep:
    mov al, TUI_BOX_V
    mov cl, SEP_COL
    mov ch, [.row]
    mov bl, ATTR_NORMAL
    call font_put_char
    inc byte [.row]
    cmp byte [.row], 29
    jb .draw_sep

    mov si, list_title
    mov cl, LIST_COL
    mov ch, 2
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, sep
    mov cl, LIST_COL
    mov ch, 26
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, info_title
    mov cl, 36
    mov ch, 2
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, sep2
    mov cl, 36
    mov ch, 26
    mov bl, ATTR_NORMAL
    call font_print_string

    popa
    ret

.row db 0

draw_file_list:
    pusha

    mov al, 0x00
    mov cl, 0
    mov ch, LIST_ROW
    mov dl, SEP_COL
    mov dh, VISIBLE_LINES
    call font_fill_rect

    mov word [.vis_line], 0
    mov ax, [scroll_top]
    mov [.cur_idx], ax

.dfl_loop:
    mov ax, [.vis_line]
    cmp ax, VISIBLE_LINES
    jge .dfl_done

    mov ax, [.cur_idx]
    cmp ax, [file_count]
    jge .dfl_done

    mov bx, ax
    shl bx, 4
    add bx, filtered_list

    mov ax, [.cur_idx]
    cmp ax, [selected]
    jne .dfl_not_sel
    mov byte [.attr], ATTR_HIGHLIGHT
    jmp .dfl_draw_bg

.dfl_not_sel:
    mov byte [.attr], ATTR_NORMAL

.dfl_draw_bg:
    push bx
    mov al, byte [.vis_line]
    add al, LIST_ROW
    mov ch, al
    mov al, [.attr]
    shr al, 4
    mov cl, LIST_COL
    mov dl, LIST_WIDTH
    mov dh, 1
    call font_fill_rect
    pop bx

    mov al, [bx+13]
    cmp al, 0
    jne .dfl_com_marker

    mov si, bin_marker
    jmp .dfl_print_marker

.dfl_com_marker:
    mov si, com_marker

.dfl_print_marker:
    push bx
    mov cl, LIST_COL
    mov ax, [.vis_line]
    add al, LIST_ROW
    mov ch, al
    mov bl, [.attr]
    call font_print_string
    pop bx

    push bx
    mov si, bx
    mov cl, LIST_COL + 6
    mov ax, [.vis_line]
    add al, LIST_ROW
    mov ch, al
    mov bl, [.attr]
    call font_print_string
    pop bx

    inc word [.vis_line]
    inc word [.cur_idx]
    jmp .dfl_loop

.dfl_done:
    popa
    ret

.vis_line dw 0
.cur_idx  dw 0
.attr     db 0

draw_info_panel:
    pusha

    mov al, 0x00
    mov cl, INFO_COL - 1
    mov ch, LIST_ROW
    mov dl, 80 - INFO_COL + 1
    mov dh, VISIBLE_LINES
    call font_fill_rect

    cmp word [file_count], 0
    je .dip_done

    mov bx, [selected]
    shl bx, 4
    add bx, filtered_list
    mov [.entry], bx

    mov bx, [.entry]
    cmp byte [bx+13], 1
    je .dip_com_colors
    mov byte [.accent], 0x01
    mov byte [.bar_attr], 0x01
    mov byte [.lbl_attr], ATTR_BIN_LABEL
    mov si, icon_lbl_bin
    jmp .dip_draw_icon
.dip_com_colors:
    mov byte [.accent], 0x02
    mov byte [.bar_attr], 0x02
    mov byte [.lbl_attr], ATTR_COM_LABEL
    mov si, icon_lbl_com

.dip_draw_icon:
    mov [.lbl_ptr], si

    ; Shadow
    mov al, 0x08
    mov cl, IC_COL + 1
    mov ch, IC_ROW + 1
    mov dl, IC_W
    mov dh, IC_H
    call font_fill_rect

    ; White page body
    mov al, 0x0F
    mov cl, IC_COL
    mov ch, IC_ROW + 1
    mov dl, IC_W
    mov dh, IC_H - 2
    call font_fill_rect

    mov byte [.ic_cnt], 0
.dip_top_bar:
    mov al, 0xDC
    mov cl, IC_COL
    add cl, [.ic_cnt]
    mov ch, IC_ROW
    mov bl, [.bar_attr]
    call font_put_char
    inc byte [.ic_cnt]
    cmp byte [.ic_cnt], IC_W
    jb .dip_top_bar

    ; Bottom accent strip
    mov al, [.accent]
    mov cl, IC_COL
    mov ch, IC_ROW + IC_H - 1
    mov dl, IC_W
    mov dh, 1
    call font_fill_rect

    ; Fold corner on white body
    mov al, 0xDC
    mov cl, IC_COL + IC_W - 3
    mov ch, IC_ROW + 1
    mov bl, 0xF8
    call font_put_char
    mov al, 0xDC
    mov cl, IC_COL + IC_W - 2
    mov ch, IC_ROW + 1
    mov bl, 0xF8
    call font_put_char
    mov al, 0xDB
    mov cl, IC_COL + IC_W - 1
    mov ch, IC_ROW + 1
    mov bl, 0x88
    call font_put_char

    ; Text lines on white body
    mov si, icon_text_line
    mov cl, IC_COL + 2
    mov ch, IC_ROW + 3
    mov bl, 0xF8
    call font_print_string

    mov si, icon_text_line
    mov cl, IC_COL + 2
    mov ch, IC_ROW + 4
    mov bl, 0xF8
    call font_print_string

    mov si, icon_text_short
    mov cl, IC_COL + 2
    mov ch, IC_ROW + 5
    mov bl, 0xF8
    call font_print_string

    ; Extension label on bottom accent strip
    mov si, [.lbl_ptr]
    mov cl, IC_COL + 5
    mov ch, IC_ROW + IC_H - 1
    mov bl, [.lbl_attr]
    call font_print_string

    ; --- File info below icon ---
    mov bx, [.entry]

    mov si, lbl_name
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 12
    mov bl, ATTR_TITLE_COL
    call font_print_string

    mov bx, [.entry]
    mov si, bx
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 13
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, lbl_size
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 15
    mov bl, ATTR_TITLE_COL
    call font_print_string

    mov bx, [.entry]
    mov ax, [bx+14]
    call int_to_str
    mov si, int_buf
    call str_len
    mov [.numlen], al

    mov si, int_buf
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 16
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, str_bytes
    mov cl, INFO_COL + 2
    add cl, [.numlen]
    mov ch, INFO_ROW + 16
    mov bl, ATTR_GRAY
    call font_print_string

    mov si, lbl_type
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 18
    mov bl, ATTR_TITLE_COL
    call font_print_string

    mov bx, [.entry]
    cmp byte [bx+13], 1
    je .dip_com_type
    mov si, str_type_bin
    jmp .dip_print_type
.dip_com_type:
    mov si, str_type_com
.dip_print_type:
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 19
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, lbl_launch
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 21
    mov bl, ATTR_TITLE_COL
    call font_print_string

    mov bx, [.entry]
    cmp byte [bx+13], 1
    je .dip_com_launch
    mov si, str_launch_native
    jmp .dip_print_launch
.dip_com_launch:
    mov si, str_launch_emu
.dip_print_launch:
    mov cl, INFO_COL + 2
    mov ch, INFO_ROW + 22
    mov bl, ATTR_NORMAL
    call font_print_string

.dip_done:
    popa
    ret

.entry   dw 0
.numlen  db 0
.accent  db 0
.bar_attr db 0
.lbl_attr db 0
.lbl_ptr dw 0
.ic_cnt  db 0

launch_common:
    pusha

    mov bx, [selected]
    shl bx, 4
    add bx, filtered_list

    cmp byte [bx+13], 1
    je .lc_com_msg

    push bx
    mov si, bin_dir_name
    mov di, TRAMPOLINE_BIN
    call copy_str

    mov si, launcher_name
    mov di, TRAMPOLINE_SELF
    call copy_str
    pop bx

    mov si, bx
    mov di, TRAMPOLINE_FILE
    call copy_str

    mov al, [launch_mode]
    mov [TRAMPOLINE_FLAG], al

    cmp al, 1
    jne .lc_no_arg

    mov si, arg_buffer
    mov di, TRAMPOLINE_ARGS
    call copy_str

    mov si, press_key_msg
    mov di, TRAMPOLINE_MSG
    call copy_str

.lc_no_arg:
    mov si, trampoline_code
    mov di, TRAMPOLINE_ADDR
    mov cx, trampoline_end - trampoline_code
    rep movsb

    popa
    add sp, 2
    jmp TRAMPOLINE_ADDR

.lc_com_msg:
    mov ax, com_msg1
    mov bx, com_msg2
    mov cx, com_msg3
    mov dx, 0
    call tui_dialog_box

    popa
    ret

trampoline_code:
    mov ax, 0x2000
    mov ds, ax
    mov es, ax

    mov ax, 0x0012
    int 0x10

    mov ah, 0x02
    mov si, TRAMPOLINE_FILE
    mov cx, 0x8000
    int 0x22
    jc .t_fail

    cmp byte [TRAMPOLINE_FLAG], 1
    jne .t_no_args
    mov si, TRAMPOLINE_ARGS
    jmp .t_run
.t_no_args:
    xor si, si

.t_run:
    ; Run launched program in the directory that was active
    ; before launcher switched to BIN.DIR.
    mov ah, 0x0F
    int 0x22

    mov ax, 0x8000
    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor di, di
    call ax

    mov ax, 0x2000
    mov ds, ax
    mov es, ax

    cmp byte [TRAMPOLINE_FLAG], 1
    jne .t_no_wait

    mov si, TRAMPOLINE_MSG
.t_print:
    lodsb
    cmp al, 0
    je .t_wait_key
    mov ah, 0x0E
    xor bx, bx
    mov bl, 0x07
    int 0x10
    jmp .t_print
.t_wait_key:
    xor ax, ax
    int 0x16

.t_no_wait:
    mov ax, 0x12
    int 0x10

    mov ah, 0x0A
    int 0x22

    mov ah, 0x09
    mov si, TRAMPOLINE_BIN
    int 0x22

    mov ah, 0x02
    mov si, TRAMPOLINE_SELF
    mov cx, 0x8000
    int 0x22
    jc .t_fail

    mov ax, 0x8000
    jmp ax

.t_fail:
    ret
trampoline_end:

copy_str:
    lodsb
    stosb
    cmp al, 0
    jne copy_str
    ret

str_len:
    push si
    xor ax, ax
.sl_loop:
    cmp byte [si], 0
    je .sl_done
    inc al
    inc si
    jmp .sl_loop
.sl_done:
    pop si
    ret

int_to_str:
    pusha
    mov di, int_buf + 6
    mov byte [di], 0

    cmp ax, 0
    jne .its_loop
    dec di
    mov byte [di], '0'
    jmp .its_store

.its_loop:
    cmp ax, 0
    je .its_store
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    dec di
    mov [di], dl
    jmp .its_loop

.its_store:
    mov si, di
    mov di, int_buf
.its_copy:
    lodsb
    stosb
    cmp al, 0
    jne .its_copy

    popa
    ret

section .bss

int_buf     resb 8
arg_buffer  resb 32

; ==================================================================
; Data section
; ==================================================================

section .data

title_str         db ' PRos Program Launcher', 0
shortcut_str      db ' ', 24, 25, ' Select    ENTER Run    ^ENTER Run with args    Esc Exit', 0
list_title        db 10 dup(0xC4), ' Programs ', 10 dup(0xC4), 0
info_title        db 12 dup(0xC4), ' Info ', 24 dup(0xC4), 0
sep               db 29 dup(0xC4), 0
sep2              db 41 dup(0xC4), 0
no_files_msg      db 'No executable files found.', 0

bin_dir_name      db 'BIN.DIR', 0
launcher_name     db 'LAUNCH.BIN', 0

bin_marker        db ' BIN ', 0
com_marker        db ' COM ', 0

arg_prompt        db 'Enter argument:', 0
press_key_msg     db 0x0D, 0x0A, 'Press any key...', 0

icon_lbl_bin      db '.BIN', 0
icon_lbl_com      db '.COM', 0
icon_text_line    db 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0
icon_text_short   db 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0xCD, 0

lbl_name          db 'File name:', 0
lbl_size          db 'File size:', 0
lbl_type          db 'File type:', 0
lbl_launch        db 'Launch mode:', 0

str_bytes         db ' bytes', 0
str_type_bin      db 'PRos executable', 0
str_type_com      db 'MS-DOS executable', 0
str_launch_native db 'Native', 0
str_launch_emu    db 'Emulation <may not work well>', 0

com_msg1          db 'COM programs must be run', 0
com_msg2          db 'from the command line.', 0
com_msg3          db 'Use: run <filename>', 0

selected          dw 0
scroll_top        dw 0
file_count        dw 0
launch_mode       db 0

file_list_buf equ $
filtered_list equ $ + (224 * ENTRY_SIZE)