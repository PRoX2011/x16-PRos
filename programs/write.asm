; ==================================================================
; x16-PRos -- WRITER. Text editor for x16-PRos 
; Copyright (C) 2025 PRoX2011
;
; Usage: writer <filename>
;
; Shortcuts:
;   Ctrl+X  - Exit
;   Ctrl+O  - Save (Write Out)
;   Ctrl+G  - Help
;   Arrows  - Move cursor
;   Home    - Go to start of line
;   End     - Go to end of line
;   PgUp    - Page up
;   PgDn    - Page down
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

TEXT_BUFFER      equ 0xE000
TEXT_BUFFER_SIZE equ 16384

SAVE_BUFFER      equ 0xD000
SAVE_BUFFER_SIZE equ 8192

KEY_CTRL_X  equ 0x18
KEY_CTRL_O  equ 0x0F
KEY_CTRL_G  equ 0x07
KEY_CTRL_K  equ 0x0B
KEY_ENTER   equ 0x0D
KEY_BKSP    equ 0x08
KEY_ESC     equ 0x1B
KEY_TAB     equ 0x09

SCAN_UP     equ 0x48
SCAN_DOWN   equ 0x50
SCAN_LEFT   equ 0x4B
SCAN_RIGHT  equ 0x4D
SCAN_HOME   equ 0x47
SCAN_END    equ 0x4F
SCAN_PGUP   equ 0x49
SCAN_PGDN   equ 0x51
SCAN_DEL    equ 0x53

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

    ; Clear editor state
    mov word [cursor_pos], 0
    mov word [scroll_offset], 0
    mov word [text_size], 0
    mov byte [modified], 0
    mov byte [filename], 0
    mov byte [status_msg], 0

    ; Check for filename argument in SI
    cmp si, 0
    je .setup_screen

    ; Copy filename
    push si
    mov di, filename
    call .copy_param
    pop si

    ; Try to load the file
    call load_file

.setup_screen:
    call full_render
    jmp main_loop

.copy_param:
    mov cx, 15
.cp_loop:
    lodsb
    cmp al, 0
    je .cp_done
    cmp al, ' '
    je .cp_done
    stosb
    loop .cp_loop
.cp_done:
    mov byte [di], 0
    ret

main_loop:
    call update_status
    call draw_cursor

    call tui_wait_for_key

    call erase_cursor

    ; --- Control keys (AL = ASCII) ---
    cmp al, KEY_CTRL_X
    je near exit_editor
    cmp al, KEY_CTRL_O
    je near save_handler
    cmp al, KEY_CTRL_G
    je near help_handler
    cmp al, KEY_CTRL_K
    je near cut_line
    cmp al, KEY_ENTER
    je near handle_enter
    cmp al, KEY_BKSP
    je near handle_backspace
    cmp al, KEY_TAB
    je near handle_tab

    ; --- Scan codes (AH) ---
    cmp ah, SCAN_UP
    je near cursor_up
    cmp ah, SCAN_DOWN
    je near cursor_down
    cmp ah, SCAN_LEFT
    je near cursor_left
    cmp ah, SCAN_RIGHT
    je near cursor_right
    cmp ah, SCAN_HOME
    je near cursor_home
    cmp ah, SCAN_END
    je near cursor_end
    cmp ah, SCAN_PGUP
    je near page_up
    cmp ah, SCAN_PGDN
    je near page_down
    cmp ah, SCAN_DEL
    je near handle_delete

    ; --- Printable characters ---
    cmp al, 32
    jb main_loop
    cmp al, 126
    ja main_loop

    call insert_char
    call full_render
    jmp main_loop

; ==================================================================
; Screen rendering
; ==================================================================

full_render:
    pusha

    ; Fill text area background
    mov al, TUI_TEXT_ATTR >> 4
    mov cl, 0
    mov ch, TUI_TEXT_ROW_FIRST
    mov dl, FONT_COLS
    mov dh, TUI_TEXT_LINES
    call font_fill_rect

    ; Find byte offset of first visible line
    mov si, TEXT_BUFFER
    mov cx, [scroll_offset]
    cmp cx, 0
    je .fr_start_render

.fr_skip_line:
    mov bx, TEXT_BUFFER
    add bx, [text_size]
    cmp si, bx
    jge .fr_start_render
    lodsb
    cmp al, 0x0A
    jne .fr_skip_line
    dec cx
    jnz .fr_skip_line

.fr_start_render:
    mov byte [render_row], TUI_TEXT_ROW_FIRST

.fr_render_line:
    cmp byte [render_row], TUI_TEXT_ROW_FIRST + TUI_TEXT_LINES
    jge .fr_done

    mov byte [render_col], 0

.fr_render_char:
    ; End of text?
    mov bx, TEXT_BUFFER
    add bx, [text_size]
    cmp si, bx
    jge .fr_line_done

    mov al, [si]
    cmp al, 0x0A
    je .fr_next_line

    ; Only draw if column < 80
    cmp byte [render_col], FONT_COLS
    jge .fr_skip_char

    push si
    mov cl, [render_col]
    mov ch, [render_row]
    mov bl, TUI_TEXT_ATTR
    call font_put_char
    pop si

.fr_skip_char:
    inc si
    inc byte [render_col]
    jmp .fr_render_char

.fr_next_line:
    inc si
    inc byte [render_row]
    jmp .fr_render_line

.fr_line_done:

.fr_done:
    popa
    ret

render_row db 0
render_col db 0

; ==================================================================
; Cursor drawing
; ==================================================================

draw_cursor:
    pusha
    call get_cursor_screen_pos
    cmp byte [csr_vis], 0
    je .dc_done

    ; Get character under cursor
    mov bx, [cursor_pos]
    cmp bx, [text_size]
    jge .dc_space
    mov si, TEXT_BUFFER
    add si, bx
    mov al, [si]
    cmp al, 0x0A
    je .dc_space
    jmp .dc_draw

.dc_space:
    mov al, ' '

.dc_draw:
    mov cl, [csr_col]
    mov ch, [csr_row]
    mov bl, TUI_CURSOR_ATTR
    call font_put_char

.dc_done:
    popa
    ret

erase_cursor:
    pusha
    call get_cursor_screen_pos
    cmp byte [csr_vis], 0
    je .ec_done

    ; Get character under cursor
    mov bx, [cursor_pos]
    cmp bx, [text_size]
    jge .ec_space
    mov si, TEXT_BUFFER
    add si, bx
    mov al, [si]
    cmp al, 0x0A
    je .ec_space
    jmp .ec_draw

.ec_space:
    mov al, ' '

.ec_draw:
    mov cl, [csr_col]
    mov ch, [csr_row]
    mov bl, TUI_TEXT_ATTR
    call font_put_char

.ec_done:
    popa
    ret


get_cursor_screen_pos:
    pusha

    ; Get cursor line and column
    call count_line
    mov [csr_line], ax
    call get_col
    mov [csr_col], al

    ; Check if cursor is visible
    mov ax, [csr_line]
    sub ax, [scroll_offset]
    cmp ax, 0
    jl .not_vis
    cmp ax, TUI_TEXT_LINES
    jge .not_vis

    add al, TUI_TEXT_ROW_FIRST
    mov [csr_row], al
    mov byte [csr_vis], 1
    popa
    ret

.not_vis:
    mov byte [csr_vis], 0
    popa
    ret

csr_col  db 0
csr_row  db 0
csr_vis  db 0
csr_line dw 0

; ==================================================================
; Status bar
; ==================================================================

update_status:
    pusha

    mov al, 0x00
    mov ch, TUI_STATUS_ROW
    call font_fill_row

    ; Fill shortcut bar
    mov al, TUI_SHORTCUT_ATTR >> 4
    mov ch, TUI_SHORTCUT_ROW
    call font_fill_row

    ; Print shortcut hints
    mov si, shortcut_str
    mov cl, 1
    mov ch, TUI_SHORTCUT_ROW
    mov bl, TUI_SHORTCUT_ATTR
    call font_print_string

    ; Status: "  Ln X, Col Y"
    mov di, status_buf

    mov si, .ln_str
    call .copy_to_buf

    call count_line
    inc ax
    call string_int_to_string
    mov si, ax
    call .copy_to_buf

    mov si, .col_str
    call .copy_to_buf

    call get_col
    inc ax
    call string_int_to_string
    mov si, ax
    call .copy_to_buf

    mov byte [di], 0

    ; Print status
    mov si, status_buf
    mov cl, 2
    mov ch, TUI_STATUS_ROW
    mov bl, 0x0E
    call font_print_string

    ; Print filename
    cmp byte [filename], 0
    je .no_fn
    mov si, filename
    mov cl, 50
    mov ch, TUI_STATUS_ROW
    mov bl, 0x0E
    call font_print_string
.no_fn:

    ; Print modified indicator
    cmp byte [modified], 0
    je .no_mod
    mov si, .mod_str
    mov cl, 70
    mov ch, TUI_STATUS_ROW
    mov bl, 0x0E
    call font_print_string
.no_mod:

    ; Print status message if any
    cmp byte [status_msg], 0
    je .no_msg
    mov si, status_msg
    mov cl, 25
    mov ch, TUI_STATUS_ROW
    mov bl, 0x0E
    call font_print_string
    mov byte [status_msg], 0
.no_msg:

    ; Title bar
    mov al, TUI_TITLE_ATTR >> 4
    mov ch, 0
    call font_fill_row
    mov si, title_str
    mov cl, 2
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string

    ; Show filename in title
    cmp byte [filename], 0
    je .no_tfn
    mov si, .file_str
    mov cl, 30
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
    mov si, filename
    mov cl, 36
    mov ch, 0
    mov bl, TUI_TITLE_ATTR
    call font_print_string
.no_tfn:

    popa
    ret

.copy_to_buf:
    lodsb
    cmp al, 0
    je .ctb_done
    stosb
    jmp .copy_to_buf
.ctb_done:
    ret

.ln_str    db 'Ln ', 0
.col_str   db ', Col ', 0
.mod_str   db 'Modified', 0
.file_str  db 'File: ', 0

status_buf times 40 db 0


count_line:
    push si
    push cx
    mov si, TEXT_BUFFER
    xor ax, ax
    mov cx, [cursor_pos]
    cmp cx, 0
    je .cl_done
.cl_loop:
    cmp byte [si], 0x0A
    jne .cl_nolf
    inc ax
.cl_nolf:
    inc si
    dec cx
    jnz .cl_loop
.cl_done:
    pop cx
    pop si
    ret

get_col:
    push si
    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    xor ax, ax
.gc_back:
    cmp si, TEXT_BUFFER
    je .gc_done
    dec si
    cmp byte [si], 0x0A
    je .gc_done
    inc ax
    jmp .gc_back
.gc_done:
    pop si
    ret

goto_line:
    push si
    push cx
    mov si, TEXT_BUFFER
    xor cx, cx
    cmp ax, 0
    je .gl_found
.gl_scan:
    cmp cx, [text_size]
    jge .gl_end
    cmp byte [si], 0x0A
    jne .gl_next
    dec ax
    cmp ax, 0
    je .gl_found_next
.gl_next:
    inc si
    inc cx
    jmp .gl_scan
.gl_found_next:
    inc cx
.gl_found:
    mov ax, cx
.gl_end:
    pop cx
    pop si
    ret

line_length_at:
    push si
    push bx
    mov si, TEXT_BUFFER
    add si, ax
    xor ax, ax
    mov bx, TEXT_BUFFER
    add bx, [text_size]
.lla_loop:
    cmp si, bx
    jge .lla_done
    cmp byte [si], 0x0A
    je .lla_done
    inc si
    inc ax
    jmp .lla_loop
.lla_done:
    pop bx
    pop si
    ret

adjust_scroll:
    pusha
    call count_line
    cmp ax, [scroll_offset]
    jge .as_check_below
    mov [scroll_offset], ax
    jmp .as_done
.as_check_below:
    mov bx, [scroll_offset]
    add bx, TUI_TEXT_LINES - 1
    cmp ax, bx
    jle .as_done
    sub ax, TUI_TEXT_LINES - 1
    mov [scroll_offset], ax
.as_done:
    popa
    ret

cursor_up:
    call count_line
    cmp ax, 0
    je near .cu_done

    push ax
    call get_col
    mov word [saved_col], ax
    pop ax

    dec ax
    call goto_line
    push ax
    call line_length_at
    mov cx, ax
    pop ax

    mov bx, [saved_col]
    cmp bx, cx
    jbe .cu_ok
    mov bx, cx
.cu_ok:
    add ax, bx
    mov [cursor_pos], ax
    call adjust_scroll
    call full_render
.cu_done:
    jmp main_loop

cursor_down:
    call count_line
    push ax
    call get_col
    mov word [saved_col], ax
    pop ax

    inc ax
    call goto_line
    cmp ax, [text_size]
    jge .cd_done

    push ax
    call line_length_at
    mov cx, ax
    pop ax

    mov bx, [saved_col]
    cmp bx, cx
    jbe .cd_ok
    mov bx, cx
.cd_ok:
    add ax, bx
    mov [cursor_pos], ax
    call adjust_scroll
    call full_render
.cd_done:
    jmp main_loop

cursor_left:
    cmp word [cursor_pos], 0
    je .cl_done
    dec word [cursor_pos]
    call adjust_scroll
    call full_render
.cl_done:
    jmp main_loop

cursor_right:
    mov ax, [cursor_pos]
    cmp ax, [text_size]
    jge .cr_done
    inc word [cursor_pos]
    call adjust_scroll
    call full_render
.cr_done:
    jmp main_loop

cursor_home:
    push si
    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov ax, [cursor_pos]
.ch_back:
    cmp ax, 0
    je .ch_set
    dec si
    cmp byte [si], 0x0A
    je .ch_set
    dec ax
    jmp .ch_back
.ch_set:
    mov [cursor_pos], ax
    pop si
    call full_render
    jmp main_loop

cursor_end:
    push si
    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov ax, [cursor_pos]
    mov bx, [text_size]
.ce_fwd:
    cmp ax, bx
    jge .ce_set
    cmp byte [si], 0x0A
    je .ce_set
    inc si
    inc ax
    jmp .ce_fwd
.ce_set:
    mov [cursor_pos], ax
    pop si
    call full_render
    jmp main_loop

page_up:
    pusha
    call count_line
    cmp ax, 0
    je .pu_done

    push ax
    call get_col
    mov word [saved_col], ax
    pop ax

    sub ax, TUI_TEXT_LINES
    cmp ax, 0
    jge .pu_target
    xor ax, ax
.pu_target:
    call goto_line
    push ax
    call line_length_at
    mov cx, ax
    pop ax

    mov bx, [saved_col]
    cmp bx, cx
    jbe .pu_col
    mov bx, cx
.pu_col:
    add ax, bx
    mov [cursor_pos], ax
    call adjust_scroll
.pu_done:
    popa
    call full_render
    jmp main_loop

page_down:
    pusha
    call count_line
    push ax
    call get_col
    mov word [saved_col], ax
    pop ax

    add ax, TUI_TEXT_LINES
    call goto_line

    cmp ax, [text_size]
    jge .pgd_end

    push ax
    call line_length_at
    mov cx, ax
    pop ax

    mov bx, [saved_col]
    cmp bx, cx
    jbe .pgd_col
    mov bx, cx
.pgd_col:
    add ax, bx
    mov [cursor_pos], ax
    call adjust_scroll
    popa
    call full_render
    jmp main_loop

.pgd_end:
    mov ax, [text_size]
    mov [cursor_pos], ax
    call adjust_scroll
    popa
    call full_render
    jmp main_loop

saved_col dw 0

; ==================================================================
; Text editing operations
; ==================================================================

insert_char:
    pusha
    mov bx, [text_size]
    cmp bx, TEXT_BUFFER_SIZE - 1
    jge .ic_done

    mov [.ic_char], al

    mov cx, [text_size]
    sub cx, [cursor_pos]
    cmp cx, 0
    je .ic_no_shift

    mov si, TEXT_BUFFER
    add si, [text_size]
    dec si
    mov di, si
    inc di
    std
    rep movsb
    cld

.ic_no_shift:
    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov al, [.ic_char]
    mov [si], al

    inc word [text_size]
    inc word [cursor_pos]
    mov byte [modified], 1

.ic_done:
    popa
    ret

.ic_char db 0

delete_char_fwd:
    pusha
    mov ax, [cursor_pos]
    cmp ax, [text_size]
    jge .dcf_done

    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov di, si
    inc si
    mov cx, [text_size]
    sub cx, [cursor_pos]
    dec cx
    cmp cx, 0
    je .dcf_no_shift
    cld
    rep movsb
.dcf_no_shift:
    dec word [text_size]
    mov byte [modified], 1
.dcf_done:
    popa
    ret

delete_char_back:
    pusha
    cmp word [cursor_pos], 0
    je .dcb_done
    dec word [cursor_pos]

    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov di, si
    inc si
    mov cx, [text_size]
    sub cx, [cursor_pos]
    dec cx
    cmp cx, 0
    je .dcb_no_shift
    cld
    rep movsb
.dcb_no_shift:
    dec word [text_size]
    mov byte [modified], 1
.dcb_done:
    popa
    ret

handle_enter:
    mov al, 0x0A
    call insert_char
    call adjust_scroll
    call full_render
    jmp main_loop

handle_backspace:
    call delete_char_back
    call adjust_scroll
    call full_render
    jmp main_loop

handle_delete:
    call delete_char_fwd
    call full_render
    jmp main_loop

handle_tab:
    mov cx, 4
.ht_loop:
    push cx
    mov al, ' '
    call insert_char
    pop cx
    loop .ht_loop
    call full_render
    jmp main_loop

cut_line:
    pusha

    call get_col
    mov cx, ax
    sub word [cursor_pos], cx

    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov bx, TEXT_BUFFER
    add bx, [text_size]
    xor dx, dx
.ck_fwd:
    cmp si, bx
    jge .ck_do_del
    cmp byte [si], 0x0A
    je .ck_inc_lf
    inc si
    inc dx
    jmp .ck_fwd
.ck_inc_lf:
    inc dx
.ck_do_del:
    cmp dx, 0
    je .ck_done

    mov si, TEXT_BUFFER
    add si, [cursor_pos]
    mov di, si
    add si, dx
    mov cx, [text_size]
    sub cx, [cursor_pos]
    sub cx, dx
    cmp cx, 0
    jle .ck_no_shift
    cld
    rep movsb
.ck_no_shift:
    sub word [text_size], dx
    mov byte [modified], 1

.ck_done:
    popa
    call adjust_scroll
    call full_render
    jmp main_loop

; ==================================================================
; File I/O
; ==================================================================

load_file:
    pusha
    cmp byte [filename], 0
    je .lf_done

    mov si, filename
    mov ah, 0x02
    mov cx, TEXT_BUFFER
    int 0x22
    jc .lf_fail

    cmp bx, TEXT_BUFFER_SIZE
    jbe .lf_size_ok
    mov bx, TEXT_BUFFER_SIZE
.lf_size_ok:
    mov [text_size], bx
    mov [.lf_orig_size], bx

    mov si, TEXT_BUFFER
    mov di, TEXT_BUFFER
    mov cx, bx
    xor dx, dx
.lf_strip:
    cmp cx, 0
    je .lf_stripped
    lodsb
    cmp al, 0x0D
    je .lf_skip_cr
    stosb
    inc dx
.lf_skip_cr:
    dec cx
    jmp .lf_strip
.lf_stripped:
    mov [text_size], dx

    cmp dx, [.lf_orig_size]
    je .lf_no_crlf
    mov byte [had_crlf], 1
    jmp .lf_done
.lf_no_crlf:
    mov byte [had_crlf], 0
    jmp .lf_done

.lf_orig_size dw 0

.lf_fail:
    mov word [text_size], 0

.lf_done:
    popa
    ret

save_handler:
    cmp byte [filename], 0
    jne .sh_save

    mov ax, save_prompt_str
    mov di, filename
    mov si, 12
    call tui_input_dialog
    jc .sh_cancel

    cmp byte [filename], 0
    je .sh_cancel

.sh_save:
    call prepare_save_buffer

    mov si, filename
    mov bx, [save_ptr]
    mov cx, [save_size]
    mov ah, 0x03
    int 0x22
    jc .sh_fail

    mov byte [modified], 0

    mov si, .saved_str
    mov di, status_msg
    call .copy_msg

    call full_render
    jmp main_loop

.sh_fail:
    mov si, .fail_str
    mov di, status_msg
    call .copy_msg

    call full_render
    jmp main_loop

.sh_cancel:
    call full_render
    jmp main_loop

.copy_msg:
    lodsb
    stosb
    cmp al, 0
    jne .copy_msg
    ret

.saved_str db '[ File saved ]', 0
.fail_str  db '[ Save FAILED ]', 0

; ==================================================================
; Help screen (Ctrl+G)
; ==================================================================

help_handler:
    mov ax, .h1
    mov bx, .h2
    mov cx, .h3
    mov dx, 0
    call tui_dialog_box

    call full_render
    jmp main_loop

.h1 db 'Arrows:  Move      Home/End:  Line st/end', 0
.h2 db '^O:      Save      ^X:        Exit', 0
.h3 db '^K:      Cut line  PgUp/PgDn: Scroll', 0

; ==================================================================
; Exit handler (Ctrl+X)
; ==================================================================

exit_editor:
    cmp byte [modified], 0
    je .do_exit

    mov ax, .q1
    mov bx, .q2
    mov cx, 0
    mov dx, 1
    call tui_dialog_box
    cmp ax, 0
    jne .do_exit

    cmp byte [filename], 0
    jne .save_then_exit

    mov ax, save_prompt_str
    mov di, filename
    mov si, 12
    call tui_input_dialog
    jc .do_exit

.save_then_exit:
    call prepare_save_buffer
    mov si, filename
    mov bx, [save_ptr]
    mov cx, [save_size]
    mov ah, 0x03
    int 0x22

.do_exit:
    mov ax, 0x12
    int 0x10
    ret

.q1 db 'Buffer has unsaved changes.', 0
.q2 db 'Save before exit?', 0

; ==================================================================
; Save buffer preparation (LF -> CR+LF conversion)
; ==================================================================

prepare_save_buffer:
    pusha
    cmp byte [had_crlf], 1
    jne .psb_direct

    mov si, TEXT_BUFFER
    mov di, SAVE_BUFFER
    mov cx, [text_size]
    xor dx, dx
.psb_loop:
    cmp cx, 0
    je .psb_done
    lodsb
    dec cx
    cmp al, 0x0A
    jne .psb_no_cr
    cmp dx, SAVE_BUFFER_SIZE - 1
    jge .psb_done
    mov byte [di], 0x0D
    inc di
    inc dx
.psb_no_cr:
    cmp dx, SAVE_BUFFER_SIZE
    jge .psb_done
    stosb
    inc dx
    jmp .psb_loop
.psb_done:
    mov word [save_ptr], SAVE_BUFFER
    mov [save_size], dx
    popa
    ret

.psb_direct:
    mov word [save_ptr], TEXT_BUFFER
    mov ax, [text_size]
    mov [save_size], ax
    popa
    ret

save_ptr  dw 0
save_size dw 0

; ==================================================================
; Data section
; ==================================================================

section .data 

title_str       db 'PRos WRITER v2.0', 0
shortcut_str    db '^X Exit  ^O Save  ^G Help  ^K Cut Line', 0
save_prompt_str db 'Enter filename to save:', 0

cursor_pos      dw 0
scroll_offset   dw 0
text_size       dw 0
modified        db 0
had_crlf        db 0

filename        times 16 db 0
status_msg      times 30 db 0