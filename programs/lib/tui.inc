; ==================================================================
; x16-PRos -- TUI library for VGA mode 0x12 (640x480, 16 colors)
; Copyright (C) 2025 PRoX2011
;
; Theme is controlled by TUI_BASE_COLOR (default: blue).
; Override with %define before including this file.
;
; Requires: font.inc must be included before this file.
; ==================================================================

%ifndef TUI_INC
%define TUI_INC

%ifndef TUI_BASE_COLOR
    %define TUI_BASE_COLOR 0x01
%endif

TUI_TITLE_ATTR         equ (TUI_BASE_COLOR << 4) | 0x0F
TUI_TEXT_ATTR          equ 0x0F
TUI_STATUS_ATTR        equ (TUI_BASE_COLOR << 4) | 0x0E
TUI_SHORTCUT_ATTR      equ (TUI_BASE_COLOR << 4) | 0x0F
TUI_SHORTCUT_KEY_ATTR  equ 0x70
TUI_DIALOG_ATTR        equ 0x4F
TUI_DIALOG_BTN_ATTR    equ 0xF0
TUI_INPUT_ATTR         equ 0x0F
TUI_CURSOR_ATTR        equ 0x70

; Box-drawing characters (CP437)
TUI_BOX_TL  equ 0xC9
TUI_BOX_TR  equ 0xBB
TUI_BOX_BL  equ 0xC8
TUI_BOX_BR  equ 0xBC
TUI_BOX_H   equ 0xCD
TUI_BOX_V   equ 0xBA
TUI_LINE_H  equ 0xC4

; Dialog constants
TUI_DLG_X   equ 17
TUI_DLG_Y   equ 8
TUI_DLG_W   equ 46
TUI_DLG_H   equ 13

; Text area layout
TUI_TEXT_ROW_FIRST equ 1
TUI_TEXT_ROW_LAST  equ 27
TUI_TEXT_LINES     equ 27
TUI_STATUS_ROW     equ 28
TUI_SHORTCUT_ROW   equ 29

; ========================================================================
; tui_init -- Initialize the TUI system
; IN:  Nothing
; OUT: Nothing
; ========================================================================
tui_init:
    call font_init
    ret

; ========================================================================
; tui_clear_screen -- Clear screen with theme background color
; IN:  Nothing
; OUT: Nothing
; ========================================================================
tui_clear_screen:
    pusha
    mov al, TUI_BASE_COLOR
    call font_clear_screen
    popa
    ret

; ========================================================================
; tui_draw_background -- Draw title bar, content area, status and shortcuts
; IN:  AX = pointer to title string (or 0)
;      BX = pointer to shortcut string (or 0)
; OUT: Nothing
; ========================================================================
tui_draw_background:
    pusha
    mov [.title], ax
    mov [.footer], bx

    ; Title bar
    mov al, TUI_TITLE_ATTR >> 4
    mov ch, 0
    call font_fill_row

    ; Content area
    mov al, TUI_TEXT_ATTR >> 4
    mov cl, 0
    mov ch, TUI_TEXT_ROW_FIRST
    mov dl, FONT_COLS
    mov dh, TUI_TEXT_LINES
    call font_fill_rect

    ; Shortcut bar
    mov al, TUI_SHORTCUT_ATTR >> 4
    mov ch, TUI_SHORTCUT_ROW
    call font_fill_row

    ; Print title
    mov si, [.title]
    cmp si, 0
    je .no_title
    mov cl, 2
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
.no_title:

    ; Print shortcuts
    mov si, [.footer]
    cmp si, 0
    je .no_footer
    mov cl, 1
    mov ch, TUI_SHORTCUT_ROW
    mov bl, TUI_SHORTCUT_ATTR
    call font_print_string
.no_footer:

    popa
    ret

.title  dw 0
.footer dw 0

; ========================================================================
; tui_print_at -- Print string at position with attribute
; IN:  SI = string, CL = column, CH = row, BL = attribute
; OUT: Nothing
; ========================================================================
tui_print_at:
    call font_print_string
    ret

; ========================================================================
; tui_wait_for_key -- Wait for a keypress
; IN:  Nothing
; OUT: AX = key code (AL = ASCII char, AH = scan code)
; ========================================================================
tui_wait_for_key:
    mov ah, 0x10
    int 0x16
    ret

; ========================================================================
; tui_draw_box -- Draw a bordered rectangle with double-line characters
; IN:  CL = x (column), CH = y (row)
;      DL = width, DH = height
;      BL = attribute
; OUT: Nothing
; ========================================================================
tui_draw_box:
    pusha
    mov [.bx_x], cl
    mov [.bx_y], ch
    mov [.bx_w], dl
    mov [.bx_h], dh
    mov [.bx_a], bl

    mov al, bl
    shr al, 4
    call font_fill_rect

    ; --- Top border ---
    mov al, TUI_BOX_TL
    mov cl, [.bx_x]
    mov ch, [.bx_y]
    mov bl, [.bx_a]
    call font_put_char

    mov byte [.bx_i], 1
.top:
    mov al, [.bx_i]
    mov ah, [.bx_w]
    dec ah
    cmp al, ah
    jge .tr
    mov al, TUI_BOX_H
    mov cl, [.bx_x]
    add cl, [.bx_i]
    mov ch, [.bx_y]
    mov bl, [.bx_a]
    call font_put_char
    inc byte [.bx_i]
    jmp .top

.tr:
    mov al, TUI_BOX_TR
    mov cl, [.bx_x]
    add cl, [.bx_w]
    dec cl
    mov ch, [.bx_y]
    mov bl, [.bx_a]
    call font_put_char

    ; --- Side borders ---
    mov byte [.bx_i], 1
.sides:
    mov al, [.bx_i]
    mov ah, [.bx_h]
    dec ah
    cmp al, ah
    jge .bl
    mov al, TUI_BOX_V
    mov cl, [.bx_x]
    mov ch, [.bx_y]
    add ch, [.bx_i]
    mov bl, [.bx_a]
    call font_put_char
    mov al, TUI_BOX_V
    mov cl, [.bx_x]
    add cl, [.bx_w]
    dec cl
    mov ch, [.bx_y]
    add ch, [.bx_i]
    mov bl, [.bx_a]
    call font_put_char
    inc byte [.bx_i]
    jmp .sides

    ; --- Bottom border ---
.bl:
    mov al, TUI_BOX_BL
    mov cl, [.bx_x]
    mov ch, [.bx_y]
    add ch, [.bx_h]
    dec ch
    mov bl, [.bx_a]
    call font_put_char

    mov byte [.bx_i], 1
.bot:
    mov al, [.bx_i]
    mov ah, [.bx_w]
    dec ah
    cmp al, ah
    jge .br
    mov al, TUI_BOX_H
    mov cl, [.bx_x]
    add cl, [.bx_i]
    mov ch, [.bx_y]
    add ch, [.bx_h]
    dec ch
    mov bl, [.bx_a]
    call font_put_char
    inc byte [.bx_i]
    jmp .bot

.br:
    mov al, TUI_BOX_BR
    mov cl, [.bx_x]
    add cl, [.bx_w]
    dec cl
    mov ch, [.bx_y]
    add ch, [.bx_h]
    dec ch
    mov bl, [.bx_a]
    call font_put_char

    popa
    ret

.bx_x db 0
.bx_y db 0
.bx_w db 0
.bx_h db 0
.bx_a db 0
.bx_i db 0

; ========================================================================
; tui_dialog_box -- Show a dialog box with message and OK/Cancel buttons
; IN:  AX = pointer to message line 1 (or 0)
;      BX = pointer to message line 2 (or 0)
;      CX = pointer to message line 3 (or 0)
;      DX = 0 for OK only, 1 for OK+Cancel
; OUT: AX = 0 if OK, 1 if Cancel
; ========================================================================
tui_dialog_box:
    pusha
    mov [.dm1], ax
    mov [.dm2], bx
    mov [.dm3], cx
    mov [.dmode], dx

    ; Draw box
    mov cl, TUI_DLG_X
    mov ch, TUI_DLG_Y
    mov dl, TUI_DLG_W
    mov dh, TUI_DLG_H
    mov bl, TUI_DIALOG_ATTR
    call tui_draw_box

    ; Print messages
    mov si, [.dm1]
    cmp si, 0
    je .no_m1
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 3
    mov bl, TUI_DIALOG_ATTR
    call font_print_string
.no_m1:
    mov si, [.dm2]
    cmp si, 0
    je .no_m2
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 4
    mov bl, TUI_DIALOG_ATTR
    call font_print_string
.no_m2:
    mov si, [.dm3]
    cmp si, 0
    je .no_m3
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 5
    mov bl, TUI_DIALOG_ATTR
    call font_print_string
.no_m3:

    cmp word [.dmode], 0
    je .one_button

    mov word [.dsel], 0

.two_draw:
    ; OK button
    cmp word [.dsel], 0
    jne .ok_normal
    mov bl, TUI_DIALOG_BTN_ATTR
    jmp .ok_draw
.ok_normal:
    mov bl, TUI_DIALOG_ATTR
.ok_draw:
    mov si, .ok_str
    mov cl, TUI_DLG_X + 12
    mov ch, TUI_DLG_Y + 9
    call font_print_string

    ; Cancel button
    cmp word [.dsel], 1
    jne .cn_normal
    mov bl, TUI_DIALOG_BTN_ATTR
    jmp .cn_draw
.cn_normal:
    mov bl, TUI_DIALOG_ATTR
.cn_draw:
    mov si, .cn_str
    mov cl, TUI_DLG_X + 24
    mov ch, TUI_DLG_Y + 9
    call font_print_string

.two_key:
    call tui_wait_for_key
    cmp ah, 0x4B
    je .sel_left
    cmp ah, 0x4D
    je .sel_right
    cmp al, 13
    je .two_done
    cmp al, 27
    je .two_esc
    jmp .two_key

.sel_left:
    mov word [.dsel], 0
    jmp .two_draw
.sel_right:
    mov word [.dsel], 1
    jmp .two_draw
.two_esc:
    mov word [.dsel], 1
.two_done:
    popa
    mov ax, [tui_dialog_box.dsel]
    ret

    ; --- One-button mode (OK) ---
.one_button:
    mov si, .ok_str
    mov cl, TUI_DLG_X + 18
    mov ch, TUI_DLG_Y + 9
    mov bl, TUI_DIALOG_BTN_ATTR
    call font_print_string

.one_key:
    call tui_wait_for_key
    cmp al, 13
    jne .one_key

    popa
    mov ax, 0
    ret

.dm1   dw 0
.dm2   dw 0
.dm3   dw 0
.dmode dw 0
.dsel  dw 0
.ok_str db '[  OK  ]', 0
.cn_str db '[ Cancel ]', 0

; ========================================================================
; tui_input_string -- Read a string from keyboard at a screen position
; IN:  DI = buffer pointer
;      CX = maximum length
;      CL = start column, CH = row (re-uses CX: max_len passed separately)
;      BL = attribute
; NOTE: Simplified interface -- caller sets up position separately.
;
; Actual interface:
;   DI = buffer, SI = max length
;   CL = column, CH = row, BL = attribute
; OUT: AX = number of characters entered
;      CF = set if user pressed Escape (cancelled)
; ========================================================================
tui_input_string:
    pusha
    mov [.is_buf], di
    mov [.is_max], si
    mov [.is_col], cl
    mov [.is_row], ch
    mov [.is_attr], bl
    mov word [.is_len], 0

    ; Draw initial cursor
    mov al, '_'
    mov cl, [.is_col]
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

.is_loop:
    call tui_wait_for_key

    cmp al, 27
    je .is_cancel
    cmp al, 13
    je .is_done
    cmp al, 8
    je .is_backspace

    ; Printable character check
    cmp al, 32
    jb .is_loop
    cmp al, 126
    ja .is_loop

    ; Check max length
    mov bx, [.is_len]
    cmp bx, [.is_max]
    jge .is_loop

    ; Store character
    mov di, [.is_buf]
    add di, bx
    mov [di], al
    inc word [.is_len]

    ; Draw character at column = is_col + (new_len - 1)
    push ax
    mov cl, [.is_col]
    mov bx, [.is_len]
    dec bx
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    pop ax
    call font_put_char

    ; Draw cursor at next position
    mov al, '_'
    mov cl, [.is_col]
    mov bx, [.is_len]
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

    jmp .is_loop

.is_backspace:
    cmp word [.is_len], 0
    je .is_loop
    dec word [.is_len]

    ; Erase cursor
    mov al, ' '
    mov cl, [.is_col]
    mov bx, [.is_len]
    inc bx
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

    ; Erase character
    mov al, ' '
    mov cl, [.is_col]
    mov bx, [.is_len]
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

    ; Draw cursor at new position
    mov al, '_'
    mov cl, [.is_col]
    mov bx, [.is_len]
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

    jmp .is_loop

.is_done:
    ; Null-terminate
    mov di, [.is_buf]
    add di, [.is_len]
    mov byte [di], 0

    ; Erase cursor
    mov al, ' '
    mov cl, [.is_col]
    mov bx, [.is_len]
    add cl, bl
    mov ch, [.is_row]
    mov bl, [.is_attr]
    call font_put_char

    popa
    mov ax, [tui_input_string.is_len]
    clc
    ret

.is_cancel:
    ; Null-terminate empty
    mov di, [.is_buf]
    mov byte [di], 0

    popa
    xor ax, ax
    stc
    ret

.is_buf  dw 0
.is_max  dw 0
.is_col  db 0
.is_row  db 0
.is_attr db 0
.is_len  dw 0

; ========================================================================
; tui_input_dialog -- Show a dialog with a text input field
; IN:  AX = pointer to prompt string
;      DI = pointer to input buffer
;      SI = max input length
; OUT: CF set if cancelled, clear if OK
;      Buffer filled with user input (null-terminated)
; ========================================================================
tui_input_dialog:
    pusha
    mov [.id_prompt], ax
    mov [.id_buf], di
    mov [.id_max], si

    ; Draw box
    mov cl, TUI_DLG_X
    mov ch, TUI_DLG_Y
    mov dl, TUI_DLG_W
    mov dh, 8
    mov bl, TUI_DIALOG_ATTR
    call tui_draw_box

    ; Print prompt
    mov si, [.id_prompt]
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 2
    mov bl, TUI_DIALOG_ATTR
    call font_print_string

    ; Fill input field background
    mov al, 0x00
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 4
    mov dl, TUI_DLG_W - 6
    mov dh, 1
    call font_fill_rect

    ; Get input
    mov di, [.id_buf]
    mov si, [.id_max]
    mov cl, TUI_DLG_X + 3
    mov ch, TUI_DLG_Y + 4
    mov bl, TUI_INPUT_ATTR
    call tui_input_string

    jc .id_cancel

    popa
    clc
    ret

.id_cancel:
    popa
    stc
    ret

.id_prompt dw 0
.id_buf    dw 0
.id_max    dw 0

; ========================================================================
; tui_draw_horiz_line -- Draw a horizontal separator line across a row
; IN:  CH = row
;      BL = attribute
;      AL = line character (e.g., TUI_LINE_H)
; OUT: Nothing
; ========================================================================
tui_draw_horiz_line:
    pusha
    mov [.hl_row], ch
    mov [.hl_attr], bl
    mov [.hl_char], al
    mov byte [.hl_col], 0

.hl_loop:
    mov al, [.hl_char]
    mov cl, [.hl_col]
    mov ch, [.hl_row]
    mov bl, [.hl_attr]
    call font_put_char
    inc byte [.hl_col]
    cmp byte [.hl_col], FONT_COLS
    jb .hl_loop

    popa
    ret

.hl_row  db 0
.hl_attr db 0
.hl_char db 0
.hl_col  db 0

%endif