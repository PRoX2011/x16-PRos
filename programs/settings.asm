; ==================================================================
; x16-PRos -- SETTINGS. System configuration editor for x16-PRos
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

ENTRY_SIZE      equ 18
MENU_ITEMS      equ 8

MAX_USER_LEN    equ 16
MAX_PROMPT_LEN  equ 32
MAX_LOGO_LEN    equ 32

TZ_MIN          equ -12
TZ_MAX          equ 14

TRAMPOLINE_ADDR equ 0xFC00
TRAMPOLINE_TGT  equ 0xFD00
TRAMPOLINE_SELF equ 0xFD20
TRAMPOLINE_BIN  equ 0xFD40

LIST_COL        equ 1
LIST_ROW        equ 3
LIST_WIDTH      equ 31

INFO_COL        equ 35
INFO_ROW        equ 2

ICON_COL        equ INFO_COL + 5
ICON_ROW        equ INFO_ROW + 2
ICON_W          equ 14
ICON_H          equ 6

ICON_SEP_ROW    equ 12
TITLE_ROW       equ 14
DESC_ROW        equ 16
CFG_ROW         equ 18
VLABEL_ROW      equ 20
VALUE_ROW       equ 21
VALUE_COL       equ INFO_COL + 4
HINT_ROW        equ 27

SEL_TITLE_ROW   equ 4
SEL_TITLE_COL   equ INFO_COL + 2
SEL_LIST_ROW    equ 6
SEL_LIST_COL    equ INFO_COL + 3
SEL_LIST_W      equ 41
SEL_VIS_LINES   equ 18
TZ_COUNT        equ 27

SEP_COL         equ 33
ATTR_NORMAL     equ 0x0F
ATTR_HIGHLIGHT  equ 0x70
ATTR_TITLE_COL  equ 0x0E
ATTR_GRAY       equ 0x07
ATTR_VALUE      equ 0x0B
ATTR_ARROW      equ 0x0E
ATTR_HINT       equ 0x0E
ATTR_DIM        equ 0x08
ATTR_PAGE_BODY  equ 0x70
ATTR_OK_MSG     equ 0x0A
ATTR_ERR_MSG    equ 0x0C

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

    call load_all_cfg

    mov word [selected], 0

    call draw_ui
    call draw_menu
    call draw_info_panel

.main_loop:
    call tui_wait_for_key

    cmp al, 27
    je .exit
    cmp ah, 0x48
    je .move_up
    cmp ah, 0x50
    je .move_down
    cmp al, 13
    je .activate
    jmp .main_loop

.move_up:
    cmp word [selected], 0
    je .main_loop
    dec word [selected]
    jmp .redraw

.move_down:
    mov ax, [selected]
    inc ax
    cmp ax, MENU_ITEMS
    jge .main_loop
    mov [selected], ax

.redraw:
    call draw_menu
    call draw_info_panel
    jmp .main_loop

.activate:
    mov bx, [selected]
    shl bx, 1
    add bx, action_table
    mov ax, [bx]
    call ax

    call draw_ui
    call draw_menu
    call draw_info_panel
    jmp .main_loop

.exit:
    mov ax, 0x12
    int 0x10
    ret

action_table:
    dw act_username
    dw act_timezone
    dw act_prompt
    dw act_logo
    dw act_stretch
    dw act_sound
    dw act_theme
    dw act_font

; ==================================================================
; act_username -- popup TUI dialog for USER.CFG
; ==================================================================
act_username:
    mov byte [edit_buf], 0
    mov ax, prompt_username
    mov di, edit_buf
    mov si, MAX_USER_LEN
    call tui_input_dialog
    jc .done

    cmp byte [edit_buf], 0
    je .done

    mov si, edit_buf
    mov di, username
    call copy_str

    mov ax, user_cfg_file
    mov bx, username
    mov dx, conf_dir_name
    call write_cfg

.done:
    ret

; ==================================================================
; act_prompt -- popup TUI dialog for PROMPT.CFG
; ==================================================================
act_prompt:
    mov byte [edit_buf], 0
    mov ax, prompt_prompt
    mov di, edit_buf
    mov si, MAX_PROMPT_LEN
    call tui_input_dialog
    jc .done

    cmp byte [edit_buf], 0
    je .done

    mov si, edit_buf
    mov di, promptstr
    call copy_str

    mov ax, prompt_cfg_file
    mov bx, promptstr
    mov dx, conf_dir_name
    call write_cfg

.done:
    ret

; ==================================================================
; act_logo -- popup TUI dialog for SYSTEM.CFG/LOGO=
; ==================================================================
act_logo:
    mov byte [edit_buf], 0
    mov ax, prompt_logo
    mov di, edit_buf
    mov si, MAX_LOGO_LEN
    call tui_input_dialog
    jc .done

    cmp byte [edit_buf], 0
    je .done

    mov si, edit_buf
    mov di, logo_file
    call copy_str

    call save_system_cfg

.done:
    ret


; ==================================================================
; act_timezone -- in-pane numeric selector
; ==================================================================
act_timezone:
    mov ax, [tz_offset]
    add ax, 12                  ; idx = tz + 12, range 0..26
    mov [sel_idx], ax
    mov word [sel_top], 0
    cmp ax, SEL_VIS_LINES
    jl .tz_have_top
    sub ax, SEL_VIS_LINES - 1
    mov [sel_top], ax
.tz_have_top:

    mov si, hdr_tz
    call sel_draw_frame
    call sel_draw_tz_list

.tz_loop:
    call tui_wait_for_key
    cmp al, 27
    je .tz_cancel
    cmp al, 13
    je .tz_save
    cmp ah, 0x48
    je .tz_up
    cmp ah, 0x50
    je .tz_down
    jmp .tz_loop

.tz_up:
    cmp word [sel_idx], 0
    je .tz_loop
    dec word [sel_idx]
    mov ax, [sel_idx]
    cmp ax, [sel_top]
    jge .tz_redraw
    dec word [sel_top]
    jmp .tz_redraw

.tz_down:
    mov ax, [sel_idx]
    inc ax
    cmp ax, TZ_COUNT
    jge .tz_loop
    mov [sel_idx], ax
    mov bx, [sel_top]
    add bx, SEL_VIS_LINES
    cmp ax, bx
    jl .tz_redraw
    inc word [sel_top]

.tz_redraw:
    call sel_draw_tz_list
    jmp .tz_loop

.tz_save:
    mov ax, [sel_idx]
    sub ax, 12
    mov [tz_offset], ax
    call format_tz
    mov ax, timezone_cfg_file
    mov bx, num_buf
    mov dx, conf_dir_name
    call write_cfg

.tz_cancel:
    ret

; ==================================================================
; act_stretch -- full-pane TRUE/FALSE list selector for LOGO_STRETCH
; ==================================================================
act_stretch:
    mov al, [logo_stretch]
    xor al, 1                   ; idx 0 = TRUE, idx 1 = FALSE
    xor ah, ah
    mov [sel_idx], ax
    mov word [sel_top], 0

    mov si, hdr_stretch
    call sel_draw_frame
    call sel_draw_bool_list

.bs_loop:
    call tui_wait_for_key
    cmp al, 27
    je .bs_cancel
    cmp al, 13
    je .bs_save
    cmp ah, 0x48
    je .bs_up
    cmp ah, 0x50
    je .bs_dn
    jmp .bs_loop

.bs_up:
    cmp word [sel_idx], 0
    je .bs_loop
    dec word [sel_idx]
    call sel_draw_bool_list
    jmp .bs_loop

.bs_dn:
    mov ax, [sel_idx]
    inc ax
    cmp ax, 2
    jge .bs_loop
    mov [sel_idx], ax
    call sel_draw_bool_list
    jmp .bs_loop

.bs_save:
    mov ax, [sel_idx]
    xor al, 1
    mov [logo_stretch], al
    call save_system_cfg

.bs_cancel:
    ret

; ==================================================================
; act_sound -- full-pane TRUE/FALSE list selector for START_SOUND
; ==================================================================
act_sound:
    mov al, [start_sound]
    xor al, 1
    xor ah, ah
    mov [sel_idx], ax
    mov word [sel_top], 0

    mov si, hdr_sound
    call sel_draw_frame
    call sel_draw_bool_list

.bs_loop:
    call tui_wait_for_key
    cmp al, 27
    je .bs_cancel
    cmp al, 13
    je .bs_save
    cmp ah, 0x48
    je .bs_up
    cmp ah, 0x50
    je .bs_dn
    jmp .bs_loop

.bs_up:
    cmp word [sel_idx], 0
    je .bs_loop
    dec word [sel_idx]
    call sel_draw_bool_list
    jmp .bs_loop

.bs_dn:
    mov ax, [sel_idx]
    inc ax
    cmp ax, 2
    jge .bs_loop
    mov [sel_idx], ax
    call sel_draw_bool_list
    jmp .bs_loop

.bs_save:
    mov ax, [sel_idx]
    xor al, 1
    mov [start_sound], al
    call save_system_cfg

.bs_cancel:
    ret

; ==================================================================
; act_theme -- launch THEME.BIN
; ==================================================================
act_theme:
    mov si, theme_bin_name
    call run_program
    ret

; ==================================================================
; act_font -- launch FONT.BIN
; ==================================================================
act_font:
    mov si, font_bin_name
    call run_program
    ret

; ==================================================================
; run_program -- Trampoline-based launch of a sibling .BIN
; IN: SI = filename string ptr
; ==================================================================
run_program:
    pusha

    mov di, TRAMPOLINE_TGT
    call copy_str

    mov si, self_bin_name
    mov di, TRAMPOLINE_SELF
    call copy_str

    mov si, bin_dir_name
    mov di, TRAMPOLINE_BIN
    call copy_str

    mov si, trampoline_code
    mov di, TRAMPOLINE_ADDR
    mov cx, trampoline_end - trampoline_code
    rep movsb

    popa
    jmp TRAMPOLINE_ADDR

trampoline_code:
    push cs
    pop ax
    mov ds, ax
    mov es, ax

    mov ax, 0x0012
    int 0x10

    mov ah, 0x0A
    int 0x22

    mov ah, 0x09
    mov si, TRAMPOLINE_BIN
    int 0x22

    mov ah, 0x02
    mov si, TRAMPOLINE_TGT
    mov cx, 0x8000
    int 0x22
    jc .t_fail

    mov ah, 0x0A
    int 0x22

    mov ax, 0x8000
    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor si, si
    xor di, di
    call ax

    push cs
    pop ax
    mov ds, ax
    mov es, ax

    mov ax, 0x0012
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

; ==================================================================
; write_cfg -- Replace contents of <dir>/<file> (or root/<file>)
; IN:  AX = filename ptr, BX = null-terminated content ptr,
;      DX = directory name ptr, or 0 to write at root
; OUT: CF = set on error
; ==================================================================
write_cfg:
    pusha
    mov [.fname], ax
    mov [.cont],  bx
    mov [.dir],   dx

    mov ax, bx
    call string_string_length
    mov [.size], ax

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    cmp word [.dir], 0
    je .at_root
    mov ah, 0x09
    mov si, [.dir]
    int 0x22
    jc .fail_outer
.at_root:

    mov ah, 0x03
    mov si, [.fname]
    mov bx, [.cont]
    mov cx, [.size]
    int 0x22
    jc .fail_inner

    mov ah, 0x0F
    int 0x22

    popa
    clc
    ret

.fail_inner:
    mov ah, 0x0F
    int 0x22
.fail_outer:
    mov ah, 0x0F
    int 0x22
    popa
    stc
    ret

.fname dw 0
.cont  dw 0
.dir   dw 0
.size  dw 0

; ==================================================================
; save_system_cfg -- Build SYSTEM.CFG content and write it
; ==================================================================
save_system_cfg:
    pusha

    mov di, write_buf

    mov si, sys_tpl_1
    call append_str

    mov si, logo_file
    cmp byte [si], 0
    jne .has_logo
    mov si, default_logo_file
.has_logo:
    call append_str
    mov al, 10
    stosb

    mov si, sys_tpl_2
    call append_str

    cmp byte [logo_stretch], 0
    je .stretch_false
    mov si, str_TRUE
    jmp .stretch_w
.stretch_false:
    mov si, str_FALSE
.stretch_w:
    call append_str
    mov al, 10
    stosb

    mov si, sys_tpl_3
    call append_str

    cmp byte [start_sound], 0
    je .sound_false
    mov si, str_TRUE
    jmp .sound_w
.sound_false:
    mov si, str_FALSE
.sound_w:
    call append_str
    mov al, 10
    stosb

    xor al, al
    stosb

    mov ax, system_cfg_file
    mov bx, write_buf
    xor dx, dx                  ; root directory
    call write_cfg

    popa
    ret

append_str:
.a:
    lodsb
    cmp al, 0
    je .done
    stosb
    jmp .a
.done:
    ret

; ==================================================================
; load_all_cfg -- Read every CFG file
; ==================================================================
load_all_cfg:
    pusha

    mov ax, user_cfg_file
    mov dx, conf_dir_name
    call load_cfg
    jc .skip_user
    mov si, load_buf
    call strip_eol
    mov si, load_buf
    mov di, username
    call copy_str
.skip_user:

    mov ax, prompt_cfg_file
    mov dx, conf_dir_name
    call load_cfg
    jc .skip_prompt
    mov si, load_buf
    call strip_eol
    mov si, load_buf
    mov di, promptstr
    call copy_str
.skip_prompt:

    mov ax, timezone_cfg_file
    mov dx, conf_dir_name
    call load_cfg
    jc .skip_tz
    mov si, load_buf
    call strip_eol
    mov si, load_buf
    call parse_signed
    mov [tz_offset], ax
.skip_tz:

    mov ax, system_cfg_file
    xor dx, dx                  ; root directory
    call load_cfg
    jc .skip_sys
    call parse_system_cfg
.skip_sys:

    mov ax, theme_cfg_file
    mov dx, conf_dir_name
    call load_cfg
    jc .skip_theme
    mov si, load_buf
    call strip_eol
    mov si, load_buf
    mov di, theme_name
    call copy_str
.skip_theme:

    mov ax, font_cfg_file
    mov dx, conf_dir_name
    call load_cfg
    jc .skip_font
    mov si, load_buf
    call strip_eol
    mov si, load_buf
    mov di, font_name
    call copy_str
.skip_font:

    popa
    ret

load_cfg:
    pusha
    mov [.fname], ax
    mov [.dir],   dx

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    cmp word [.dir], 0
    je .at_root
    mov ah, 0x09
    mov si, [.dir]
    int 0x22
    jc .fail_outer
.at_root:

    mov ah, 0x02
    mov si, [.fname]
    mov cx, load_buf
    int 0x22
    jc .fail_inner

    mov di, load_buf
    add di, bx
    mov byte [di], 0

    mov ah, 0x0F
    int 0x22

    popa
    clc
    ret

.fail_inner:
    mov ah, 0x0F
    int 0x22
.fail_outer:
    mov ah, 0x0F
    int 0x22
    popa
    stc
    ret

.fname dw 0
.dir   dw 0

; ==================================================================
; parse_system_cfg -- Walk load_buf, fill logo_file/stretch/sound
; ==================================================================
parse_system_cfg:
    pusha
    mov si, load_buf

.scan:
    mov al, [si]
    cmp al, 0
    je .done

    cmp al, 13
    je .next
    cmp al, 10
    je .next
    cmp al, ' '
    je .next_char
    cmp al, 9
    je .next_char
    cmp al, '#'
    je .skip_line

    push si
    mov di, key_logo
    call match_key
    jc .ml_no
    pop ax
    mov di, logo_file
    mov cx, MAX_LOGO_LEN
    call copy_value
    jmp .skip_line
.ml_no:
    pop si

    push si
    mov di, key_stretch
    call match_key
    jc .ms_no
    pop ax
    call read_bool
    mov [logo_stretch], al
    jmp .skip_line
.ms_no:
    pop si

    push si
    mov di, key_sound
    call match_key
    jc .mn_no
    pop ax
    call read_bool
    mov [start_sound], al
    jmp .skip_line
.mn_no:
    pop si

.skip_line:
    mov al, [si]
    cmp al, 0
    je .done
    cmp al, 10
    je .next
    inc si
    jmp .skip_line

.next:
    inc si
    jmp .scan

.next_char:
    inc si
    jmp .scan

.done:
    popa
    ret

match_key:
.m:
    mov al, [di]
    cmp al, 0
    je .ok
    mov ah, [si]
    cmp al, ah
    jne .nm
    inc si
    inc di
    jmp .m
.ok:
    clc
    ret
.nm:
    stc
    ret

copy_value:
    push bx
    mov bx, di
.cv:
    mov al, [si]
    cmp al, 0
    je .end
    cmp al, 10
    je .end
    cmp al, 13
    je .end
    test cx, cx
    jz .end
    mov [bx], al
    inc bx
    inc si
    dec cx
    jmp .cv
.end:
    mov byte [bx], 0
    pop bx
    ret

read_bool:
    mov al, [si]
    cmp al, 'T'
    je .true
    cmp al, 't'
    je .true
    xor al, al
    ret
.true:
    mov al, 1
    ret

strip_eol:
    push si
    push ax
    mov ax, si
.find:
    cmp byte [si], 0
    je .trim
    inc si
    jmp .find
.trim:
    cmp si, ax
    jbe .done
    dec si
    cmp byte [si], 10
    je .cut
    cmp byte [si], 13
    je .cut
    cmp byte [si], ' '
    je .cut
    cmp byte [si], 9
    je .cut
    jmp .done
.cut:
    mov byte [si], 0
    jmp .trim
.done:
    pop ax
    pop si
    ret

parse_signed:
    push bx
    push cx
    push dx
    push si

    xor bx, bx
    mov cx, 1

.skip:
    mov al, [si]
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    jmp .check_sign
.adv:
    inc si
    jmp .skip

.check_sign:
    cmp al, '-'
    jne .check_plus
    mov cx, -1
    inc si
    jmp .digits
.check_plus:
    cmp al, '+'
    jne .digits
    inc si

.digits:
    mov al, [si]
    cmp al, '0'
    jb .end
    cmp al, '9'
    ja .end
    sub al, '0'
    mov dl, al
    push dx
    mov ax, bx
    mov bx, 10
    mul bx
    mov bx, ax
    pop dx
    xor dh, dh
    add bx, dx
    inc si
    jmp .digits

.end:
    mov ax, bx
    cmp cx, 0
    jge .pos
    neg ax
.pos:
    pop si
    pop dx
    pop cx
    pop bx
    ret

format_tz:
    pusha
    mov di, num_buf
    test ax, ax
    js .neg
    mov byte [di], '+'
    inc di
    jmp .conv
.neg:
    mov byte [di], '-'
    inc di
    neg ax
.conv:
    xor cx, cx
    mov bx, 10
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.write:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    loop .write
    mov byte [di], 0
    popa
    ret

copy_str:
    lodsb
    stosb
    cmp al, 0
    jne copy_str
    ret

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

    mov si, sep_l
    mov cl, LIST_COL
    mov ch, 26
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, info_title
    mov cl, 36
    mov ch, 2
    mov bl, ATTR_NORMAL
    call font_print_string

    mov si, sep_r
    mov cl, 36
    mov ch, 26
    mov bl, ATTR_NORMAL
    call font_print_string

    popa
    ret

.row db 0

; ==================================================================
; UI: left list
; ==================================================================
draw_menu:
    pusha

    mov al, 0x00
    mov cl, 0
    mov ch, LIST_ROW
    mov dl, SEP_COL
    mov dh, 23
    call font_fill_rect

    mov word [.idx], 0

.dm_loop:
    mov ax, [.idx]
    cmp ax, MENU_ITEMS
    jge .done

    cmp ax, [selected]
    jne .not_sel
    mov byte [.attr], ATTR_HIGHLIGHT
    jmp .draw_bg
.not_sel:
    mov byte [.attr], ATTR_NORMAL

.draw_bg:
    mov al, [.idx]
    add al, LIST_ROW
    mov ch, al
    mov al, [.attr]
    shr al, 4
    mov cl, LIST_COL
    mov dl, LIST_WIDTH
    mov dh, 1
    call font_fill_rect

    mov bx, [.idx]
    shl bx, 1
    add bx, menu_items
    mov si, [bx]

    mov cl, LIST_COL + 2
    mov al, [.idx]
    add al, LIST_ROW
    mov ch, al
    mov bl, [.attr]
    call font_print_string

    inc word [.idx]
    jmp .dm_loop

.done:
    popa
    ret

.idx  dw 0
.attr db 0

; ==================================================================
; UI: right info pane (icon + title + description + value)
; ==================================================================
draw_info_panel:
    pusha

    mov al, 0x00
    mov cl, INFO_COL - 1
    mov ch, LIST_ROW
    mov dl, 80 - INFO_COL + 1
    mov dh, 23
    call font_fill_rect

    call draw_setting_icon

    ; Horizontal separator between icon and title
    mov al, TUI_LINE_H
    mov ch, ICON_SEP_ROW
    mov cl, INFO_COL + 2
.uline_loop:
    mov bl, ATTR_GRAY
    call font_put_char
    inc cl
    cmp cl, 79
    jb .uline_loop

    mov bx, [selected]
    shl bx, 1
    add bx, info_titles
    mov si, [bx]
    mov cl, INFO_COL + 2
    mov ch, TITLE_ROW
    mov bl, ATTR_NORMAL
    call font_print_string

    mov bx, [selected]
    shl bx, 1
    add bx, info_descrs
    mov si, [bx]
    mov cl, INFO_COL + 2
    mov ch, DESC_ROW
    mov bl, ATTR_NORMAL
    call font_print_string

    ; "Config: " label + filename string
    mov si, lbl_config
    mov cl, INFO_COL + 2
    mov ch, CFG_ROW
    mov bl, ATTR_GRAY
    call font_print_string

    mov bx, [selected]
    shl bx, 1
    add bx, info_cfg_files
    mov si, [bx]
    mov cl, INFO_COL + 2 + 8
    mov ch, CFG_ROW
    mov bl, ATTR_VALUE
    call font_print_string

    cmp word [selected], 6      ; theme: nothing to show
    je .skip_value

    mov si, lbl_current
    mov cl, INFO_COL + 2
    mov ch, VLABEL_ROW
    mov bl, ATTR_GRAY
    call font_print_string

    call draw_value_passive

.skip_value:
    popa
    ret

; ==================================================================
; draw_value_passive -- Show the current value without arrow indicator
; ==================================================================
draw_value_passive:
    pusha

    ; Clear the value row in the right pane
    mov al, 0x00
    mov cl, INFO_COL
    mov ch, VALUE_ROW
    mov dl, 80 - INFO_COL
    mov dh, 1
    call font_fill_rect

    mov ax, [selected]

    cmp ax, 0
    jne .not_user
    mov si, username
    cmp byte [si], 0
    jne .show_str
    mov si, str_empty
    jmp .show_str
.not_user:
    cmp ax, 1
    jne .not_tz
    mov ax, [tz_offset]
    call format_tz
    mov si, num_buf
    jmp .show_str
.not_tz:
    cmp ax, 2
    jne .not_pr
    mov si, promptstr
    cmp byte [si], 0
    jne .show_str
    mov si, str_empty
    jmp .show_str
.not_pr:
    cmp ax, 3
    jne .not_lg
    mov si, logo_file
    cmp byte [si], 0
    jne .show_str
    mov si, str_empty
    jmp .show_str
.not_lg:
    cmp ax, 4
    jne .not_st
    mov al, [logo_stretch]
    call bool_to_str
    jmp .show_str
.not_st:
    cmp ax, 5
    jne .not_sn
    mov al, [start_sound]
    call bool_to_str
    jmp .show_str
.not_sn:
    mov si, font_name
    cmp byte [si], 0
    jne .show_str
    mov si, str_empty

.show_str:
    mov cl, VALUE_COL
    mov ch, VALUE_ROW
    mov bl, ATTR_VALUE
    call font_print_string

    popa
    ret

sel_draw_frame:
    pusha
    push si

    mov al, 0x00
    mov cl, INFO_COL - 1
    mov ch, LIST_ROW
    mov dl, 80 - INFO_COL + 1
    mov dh, 23
    call font_fill_rect

    pop si
    mov cl, SEL_TITLE_COL
    mov ch, SEL_TITLE_ROW
    mov bl, ATTR_NORMAL
    call font_print_string

    mov byte [.uc], SEL_TITLE_COL
.uloop:
    mov al, TUI_LINE_H
    mov cl, [.uc]
    mov ch, SEL_TITLE_ROW + 1
    mov bl, ATTR_GRAY
    call font_put_char
    inc byte [.uc]
    cmp byte [.uc], 79
    jb .uloop

    mov al, 0x00
    mov cl, INFO_COL
    mov ch, HINT_ROW
    mov dl, 80 - INFO_COL
    mov dh, 1
    call font_fill_rect

    mov si, sel_hint_ud
    mov cl, INFO_COL + 2
    mov ch, HINT_ROW
    mov bl, ATTR_HINT
    call font_print_string

    popa
    ret

.uc db 0

; ==================================================================
; sel_draw_bool_list -- Draw 2-row TRUE/FALSE list
; ==================================================================
sel_draw_bool_list:
    pusha

    mov al, 0x00
    mov cl, INFO_COL - 1
    mov ch, SEL_LIST_ROW
    mov dl, 80 - INFO_COL + 1
    mov dh, SEL_VIS_LINES
    call font_fill_rect

    mov word [.idx], 0

.loop:
    mov ax, [.idx]
    cmp ax, 2
    jge .done

    mov ax, [.idx]
    add al, SEL_LIST_ROW
    mov [.row], al

    mov bx, [.idx]
    cmp bx, [sel_idx]
    jne .normal
    mov byte [.attr], ATTR_HIGHLIGHT
    jmp .draw_bg
.normal:
    mov byte [.attr], ATTR_NORMAL

.draw_bg:
    mov al, [.attr]
    shr al, 4
    mov cl, INFO_COL
    mov ch, [.row]
    mov dl, SEL_LIST_W
    mov dh, 1
    call font_fill_rect

    mov bx, [.idx]
    cmp bx, [sel_idx]
    jne .no_arrow
    mov al, 0x10
    mov cl, SEL_LIST_COL
    mov ch, [.row]
    mov bl, [.attr]
    call font_put_char
.no_arrow:

    ; Label
    mov bx, [.idx]
    test bx, bx
    jnz .lbl_false
    mov si, str_TRUE
    jmp .show
.lbl_false:
    mov si, str_FALSE
.show:
    mov cl, SEL_LIST_COL + 2
    mov ch, [.row]
    mov bl, [.attr]
    call font_print_string

    inc word [.idx]
    jmp .loop

.done:
    popa
    ret

.idx  dw 0
.row  db 0
.attr db 0

; ==================================================================
; sel_draw_tz_list -- Scrollable timezone list (-12..+14 -> idx 0..26)
; ==================================================================
sel_draw_tz_list:
    pusha

    mov al, 0x00
    mov cl, INFO_COL - 1
    mov ch, SEL_LIST_ROW
    mov dl, 80 - INFO_COL + 1
    mov dh, SEL_VIS_LINES
    call font_fill_rect

    mov word [.vis], 0
    mov ax, [sel_top]
    mov [.cur], ax

.loop:
    mov ax, [.vis]
    cmp ax, SEL_VIS_LINES
    jge .done
    mov ax, [.cur]
    cmp ax, TZ_COUNT
    jge .done

    mov ax, [.vis]
    add al, SEL_LIST_ROW
    mov [.row], al

    mov bx, [.cur]
    cmp bx, [sel_idx]
    jne .normal
    mov byte [.attr], ATTR_HIGHLIGHT
    jmp .draw_bg
.normal:
    mov byte [.attr], ATTR_NORMAL

.draw_bg:
    mov al, [.attr]
    shr al, 4
    mov cl, INFO_COL
    mov ch, [.row]
    mov dl, SEL_LIST_W
    mov dh, 1
    call font_fill_rect

    mov bx, [.cur]
    cmp bx, [sel_idx]
    jne .no_arrow
    mov al, 0x10
    mov cl, SEL_LIST_COL
    mov ch, [.row]
    mov bl, [.attr]
    call font_put_char
.no_arrow:

    mov si, str_UTC
    mov cl, SEL_LIST_COL + 2
    mov ch, [.row]
    mov bl, [.attr]
    call font_print_string

    mov ax, [.cur]
    sub ax, 12
    call format_tz
    mov si, num_buf
    mov cl, SEL_LIST_COL + 6
    mov ch, [.row]
    mov bl, [.attr]
    call font_print_string

    inc word [.vis]
    inc word [.cur]
    jmp .loop

.done:
    popa
    ret

.vis  dw 0
.cur  dw 0
.row  db 0
.attr db 0

bool_to_str:
    test al, al
    jz .f
    mov si, str_TRUE
    ret
.f:
    mov si, str_FALSE
    ret

; ==================================================================
; draw_setting_icon -- Render a small icon
; ==================================================================
draw_setting_icon:
    pusha

    mov bx, [selected]
    shl bx, 3
    add bx, icon_table

    mov al, [bx]
    mov [.bar_attr], al
    mov al, [bx+1]
    mov [.lbl_attr], al
    mov al, [bx+2]
    mov [.glyph_lo], al
    mov al, [bx+3]
    mov [.glyph_attr], al
    mov al, [bx+4]
    mov [.glyph_hi], al
    mov ax, [bx+6]
    mov [.lbl_ptr], ax

    ; Shadow
    mov al, 0x08
    mov cl, ICON_COL + 1
    mov ch, ICON_ROW + 1
    mov dl, ICON_W
    mov dh, ICON_H
    call font_fill_rect

    ; White page body
    mov al, 0x0F
    mov cl, ICON_COL
    mov ch, ICON_ROW + 1
    mov dl, ICON_W
    mov dh, ICON_H - 2
    call font_fill_rect

    ; Top color bar
    mov byte [.cnt], 0
.top_bar:
    mov al, 0xDC
    mov cl, ICON_COL
    add cl, [.cnt]
    mov ch, ICON_ROW
    mov bl, [.bar_attr]
    call font_put_char
    inc byte [.cnt]
    cmp byte [.cnt], ICON_W
    jb .top_bar

    ; Bottom accent strip
    mov al, [.bar_attr]
    shr al, 4
    mov cl, ICON_COL
    mov ch, ICON_ROW + ICON_H - 1
    mov dl, ICON_W
    mov dh, 1
    call font_fill_rect

    ; Glyph (2 chars centered) on white body
    mov al, [.glyph_lo]
    mov cl, ICON_COL + ICON_W / 2 - 1
    mov ch, ICON_ROW + 2
    mov bl, [.glyph_attr]
    call font_put_char

    mov al, [.glyph_hi]
    mov cl, ICON_COL + ICON_W / 2
    mov ch, ICON_ROW + 2
    mov bl, [.glyph_attr]
    call font_put_char

    ; Fold corner on white body (upper right)
    mov al, 0xDC
    mov cl, ICON_COL + ICON_W - 3
    mov ch, ICON_ROW + 1
    mov bl, 0xF8
    call font_put_char
    mov al, 0xDC
    mov cl, ICON_COL + ICON_W - 2
    mov ch, ICON_ROW + 1
    mov bl, 0xF8
    call font_put_char
    mov al, 0xDB
    mov cl, ICON_COL + ICON_W - 1
    mov ch, ICON_ROW + 1
    mov bl, 0x88
    call font_put_char

    ; Label on bottom strip
    mov si, [.lbl_ptr]
    mov cl, ICON_COL + 4
    mov ch, ICON_ROW + ICON_H - 1
    mov bl, [.lbl_attr]
    call font_print_string

    popa
    ret

.cnt        db 0
.bar_attr   db 0
.lbl_attr   db 0
.glyph_lo   db 0
.glyph_hi   db 0
.glyph_attr db 0
.lbl_ptr    dw 0

; ==================================================================
; Data section
; ==================================================================
section .data

title_str         db ' x16-PRos System Settings', 0
shortcut_str      db ' ', 24, 25, ' Select   Enter Edit   Esc Exit', 0
list_title        db 9 dup(0xC4), ' Settings ', 11 dup(0xC4), 0
info_title        db 12 dup(0xC4), ' Info ', 24 dup(0xC4), 0
sep_l             db 29 dup(0xC4), 0
sep_r             db 41 dup(0xC4), 0

menu_items:
    dw mi_user
    dw mi_tz
    dw mi_prompt
    dw mi_logo
    dw mi_stretch
    dw mi_sound
    dw mi_theme
    dw mi_font

mi_user      db ' USERNAME', 0
mi_tz        db ' TIMEZONE', 0
mi_prompt    db ' TERMINAL PROMPT', 0
mi_logo      db ' BOOT LOGO', 0
mi_stretch   db ' BOOT LOGO STRETCH', 0
mi_sound     db ' STARTUP SOUND', 0
mi_theme     db ' THEME', 0
mi_font      db ' FONT', 0

info_titles:
    dw it_user
    dw it_tz
    dw it_prompt
    dw it_logo
    dw it_stretch
    dw it_sound
    dw it_theme
    dw it_font

it_user      db 'USERNAME', 0
it_tz        db 'TIMEZONE', 0
it_prompt    db 'TERMINAL PROMPT', 0
it_logo      db 'BOOT LOGO', 0
it_stretch   db 'BOOT LOGO STRETCH', 0
it_sound     db 'STARTUP SOUND', 0
it_theme     db 'THEME', 0
it_font      db 'FONT', 0

info_descrs:
    dw id_user
    dw id_tz
    dw id_prompt
    dw id_logo
    dw id_stretch
    dw id_sound
    dw id_theme
    dw id_font

id_user     db 'Username. It`s just username.',   0
id_tz       db 'UTC time zone offset',  0
id_prompt   db 'Terminal prompt',      0
id_logo     db 'Path of the BMP shown at boot',   0
id_stretch  db 'Fit logo to full screen', 0
id_sound    db 'Play startup sound on boot',       0
id_theme    db 'System theme', 0
id_font     db 'Current font',  0

info_cfg_files:
    dw cf_user
    dw cf_tz
    dw cf_prompt
    dw cf_logo
    dw cf_logo
    dw cf_logo
    dw cf_theme
    dw cf_font

cf_user    db 'CONF.DIR/USER.CFG',     0
cf_tz      db 'CONF.DIR/TIMEZONE.CFG', 0
cf_prompt  db 'CONF.DIR/PROMPT.CFG',   0
cf_logo    db 'SYSTEM.CFG',            0
cf_theme   db 'CONF.DIR/THEME.CFG',    0
cf_font    db 'CONF.DIR/FONT.CFG',     0

icon_table:
    db 0x1F, 0x1E, 0x02, 0xF0, ' ',  0
    dw ic_lbl_user
    db 0x3F, 0x3E, 0x09, 0xF0, ' ',  0
    dw ic_lbl_tz
    db 0x2F, 0x2E, '$',  0xF0, '_',  0
    dw ic_lbl_prmt
    db 0x5F, 0x5E, 0xFE, 0xF0, 'P',  0
    dw ic_lbl_logo
    db 0x9F, 0x9E, 0x1B, 0xF0, 0x1A, 0
    dw ic_lbl_str
    db 0x4F, 0x4E, 0x0E, 0xF0, ' ',  0
    dw ic_lbl_snd
    db 0x6F, 0x6E, 0x06, 0xF0, ' ',  0
    dw ic_lbl_thm
    db 0x3F, 0x3E, 'A',  0xF0, 'a',  0
    dw ic_lbl_fnt

ic_lbl_user db 'USER',    0
ic_lbl_tz   db 'TIME',    0
ic_lbl_prmt db 'PRMT',    0
ic_lbl_logo db 'LOGO',    0
ic_lbl_str  db 'STR',     0
ic_lbl_snd  db 'SND',     0
ic_lbl_thm  db 'THM',     0
ic_lbl_fnt  db 'FNT',     0

lbl_current      db 'Current value:', 0
lbl_config       db 'Config: ', 0

sel_hint_ud       db ' ', 24, '/', 25, ' change   Enter save   Esc cancel', 0

hdr_tz           db 'Select timezone (hours from UTC):', 0
hdr_stretch      db 'Stretch boot logo to full screen?', 0
hdr_sound        db 'Play startup sound on boot?',       0

prompt_username  db 'Enter username:',           0
prompt_prompt    db 'Enter shell prompt:',       0
prompt_logo      db 'Enter boot logo file path:', 0

str_TRUE         db 'TRUE',  0
str_FALSE        db 'FALSE', 0
str_UTC          db 'UTC ', 0
str_empty        db '<not set>', 0

key_logo         db 'LOGO=', 0
key_stretch      db 'LOGO_STRETCH=', 0
key_sound        db 'START_SOUND=', 0

sys_tpl_1        db '# x16-PRos System Configuration', 10
                 db '# This file controls startup settings', 10, 10
                 db '# Logo file to display at boot', 10
                 db '# Set to FALSE to disable logo display', 10
                 db 'LOGO=', 0
sys_tpl_2        db 10, '# Stretch logo to full screen (320x200)', 10
                 db '# Valid values: TRUE, FALSE', 10
                 db '# Default: FALSE (centered display)', 10
                 db 'LOGO_STRETCH=', 0
sys_tpl_3        db 10, '# Startup sound enabled/disabled', 10
                 db '# Valid values: TRUE, FALSE', 10
                 db 'START_SOUND=', 0

default_logo_file db 'BMP/LOGO.BMP', 0

conf_dir_name     db 'CONF.DIR', 0
bin_dir_name      db 'BIN.DIR',  0

user_cfg_file     db 'USER.CFG', 0
timezone_cfg_file db 'TIMEZONE.CFG', 0
prompt_cfg_file   db 'PROMPT.CFG', 0
system_cfg_file   db 'SYSTEM.CFG', 0
theme_cfg_file    db 'THEME.CFG', 0
font_cfg_file     db 'FONT.CFG', 0

theme_bin_name    db 'THEME.BIN', 0
font_bin_name     db 'FONT.BIN',  0
self_bin_name     db 'SETTINGS.BIN', 0

selected         dw 0
tz_offset        dw 0
sel_idx          dw 0
sel_top          dw 0
logo_stretch     db 0
start_sound      db 0

username         times MAX_USER_LEN + 1   db 0
promptstr        times MAX_PROMPT_LEN + 1 db 0
logo_file        times MAX_LOGO_LEN + 1   db 0
theme_name       times 32 + 1             db 0
font_name        times 32 + 1             db 0

edit_buf         times 64   db 0
num_buf          times 8    db 0
load_buf         times 1024 db 0
write_buf        times 1024 db 0