; ==================================================================
; x16-PRos - string functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; =======================================================================
; STRING_STRING_LENGTH - Calculates the length of a null-terminated string
; IN  : AX = pointer to string
; OUT : AX = length of string (excluding null terminator)
; =======================================================================
string_string_length:
    pusha
    mov bx, ax
    xor cx, cx

.more:
    cmp byte [bx], 0
    je .done
    inc bx
    inc cx
    jmp .more

.done:
    mov word [.tmp_counter], cx
    popa
    mov ax, [.tmp_counter]
    ret

.tmp_counter dw 0

; =======================================================================
; STRING_STRING_UPPERCASE - Converts a string to uppercase
; IN  : AX = pointer to string
; OUT : String is modified in place
; =======================================================================
string_string_uppercase:
    pusha
    mov si, ax

.more:
    cmp byte [si], 0
    je .done
    cmp byte [si], 'a'
    jb .noatoz
    cmp byte [si], 'z'
    ja .noatoz
    sub byte [si], 20h
    inc si
    jmp .more

.noatoz:
    inc si
    jmp .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_COPY - Copies a null-terminated string
; IN  : SI = pointer to source string
;       DI = pointer to destination buffer
; OUT : String copied to destination (including null terminator)
; =======================================================================
string_string_copy:
    pusha

.more:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    cmp byte al, 0
    jne .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_CHOMP - Removes leading and trailing spaces from string
; IN  : AX = pointer to string
; OUT : String is modified in place, trimmed of whitespace
; =======================================================================
string_string_chomp:
    pusha
    mov dx, ax
    mov di, ax
    xor cx, cx

.keepcounting:
    cmp byte [di], ' '
    jne .counted
    inc cx
    inc di
    jmp .keepcounting

.counted:
    test cx, cx
    je .finished_copy
    mov si, di
    mov di, dx

.keep_copying:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .finished_copy
    inc si
    inc di
    jmp .keep_copying

.finished_copy:
    mov ax, dx
    call string_string_length
    test ax, ax
    je .done
    mov si, dx
    add si, ax

.more:
    dec si
    cmp byte [si], ' '
    jne .done
    mov byte [si], 0
    jmp .more

.done:
    popa
    ret

; =======================================================================
; STRING_STRING_COMPARE - Compares two null-terminated strings
; IN  : SI = pointer to first string
;       DI = pointer to second string
; OUT : CF = 1 if strings are equal, CF = 0 if different
; =======================================================================
string_string_compare:
    pusha

.more:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_same
    cmp al, 0
    je .terminated
    inc si
    inc di
    jmp .more

.not_same:
    popa
    clc
    ret

.terminated:
    popa
    stc
    ret

; =======================================================================
; STRING_STRING_STRINCMP - Compares first CL characters of two strings
; IN  : SI = pointer to first string
;       DI = pointer to second string
;       CL = number of characters to compare
; OUT : CF = 1 if strings match for CL characters, CF = 0 if different
; =======================================================================
string_string_strincmp:
    pusha

.more:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_same
    cmp al, 0
    je .terminated
    inc si
    inc di
    dec cl
    cmp cl, 0
    je .terminated
    jmp .more

.not_same:
    popa
    clc
    ret

.terminated:
    popa
    stc
    ret

; =======================================================================
; STRING_STRING_TOKENIZE - Finds and splits string by delimiter
; IN  : SI = pointer to string
;       AL = delimiter character
; OUT : SI = unchanged (original string start)
;       DI = pointer to next token after delimiter (or 0 if no more)
;       Delimiter in string is replaced with null terminator
; =======================================================================
string_string_tokenize:
    push si

.next_char:
    cmp byte [si], al
    je .return_token
    cmp byte [si], 0
    jz .no_more
    inc si
    jmp .next_char

.return_token:
    mov byte [si], 0
    inc si
    mov di, si
    pop si
    ret

.no_more:
    xor di, di
    pop si
    ret

; =======================================================================
; STRING_INPUT_STRING - Reads a string from keyboard with backspace support
; IN  : AX = pointer to buffer for input (256 bytes recommended)
; OUT : Buffer filled with user input, null-terminated
;       Maximum length is 255 characters
; =======================================================================
string_input_string:
    pusha
    mov [.start_input_buf_addr], ax
    mov di, ax
    xor cx, cx
    mov word [.ac_sug_len], 0

    call string_get_cursor_pos
    mov word [.cursor_col], dx

.read_loop:
    call .ac_update
    call .cur_draw
.wait_key:
    mov ah, 0x01
    int 0x16
    jnz .key_ready
    call .cur_tick
    jmp .wait_key
.key_ready:
    call .cur_erase
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x09
    je .ac_complete_tab
    call .ac_clear
    cmp al, 0x08
    je .handle_backspace
    cmp al, 0x7F
    je .handle_ctrl_backspace
    cmp ah, 0x48
    je .handle_history_scroll_up
    cmp ah, 0x50
    je .handle_history_scroll_down
    cmp cx, 255
    jge .read_loop
    stosb
    mov bl, 0x1F
    call print_char
    inc cx
    jmp .read_loop

.handle_history_scroll_up:
    cmp byte [.history_using], 0
    je .handle_history_scroll_up_to_history_mode
    mov al, [.current_history_pos]
    cmp al, [command_history_top]
    jae .read_loop
    inc byte [.current_history_pos]

.handle_history_scroll_up_to_history_mode:
    mov byte [.history_using], 1

    mov di, [.start_input_buf_addr]
    mov bx, [.current_history_pos]
    shl bx, 8
    lea si, [command_history + bx]
    
    mov bl, 0x1F
.handle_history_scroll_up_clear_loop:
    test cx, cx
    je .handle_history_scroll_up_loop
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    dec cx
    jmp .handle_history_scroll_up_clear_loop

.handle_history_scroll_up_loop:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .handle_history_scroll_up_done
    mov bl, 0x1F
    call print_char
    inc di
    inc si
    inc cx
    jmp .handle_history_scroll_up_loop

.handle_history_scroll_up_done:
    jmp .read_loop


.handle_history_scroll_down:
    cmp byte [.current_history_pos], 0
    je .handle_history_scroll_down_history_exit
    mov byte [.history_using], 1
    dec byte [.current_history_pos]

    mov di, [.start_input_buf_addr]
    mov bx, [.current_history_pos]
    shl bx, 8
    lea si, [command_history + bx]
    
    mov bl, 0x1F
.handle_history_scroll_down_clear_loop:
    test cx, cx
    je .handle_history_scroll_down_loop
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    dec cx
    jmp .handle_history_scroll_down_clear_loop

.handle_history_scroll_down_loop:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je .handle_history_scroll_down_done
    mov bl, 0x1F
    call print_char
    inc di
    inc si
    inc cx
    jmp .handle_history_scroll_down_loop

.handle_history_scroll_down_done:
    jmp .read_loop

.handle_history_scroll_down_history_exit:
    mov byte [.history_using], 0
    mov di, [.start_input_buf_addr]
    mov byte [di], 0

    mov bl, 0x1F
.handle_history_scroll_down_clear_loop_exit:
    test cx, cx
    je .handle_history_scroll_down_clear_loop_done
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    dec cx
    jmp .handle_history_scroll_down_clear_loop_exit

.handle_history_scroll_down_clear_loop_done:
    jmp .read_loop

.handle_backspace:
    test cx, cx
    je .read_loop

    dec di
    dec cx
    call string_get_cursor_pos
    cmp dl, [.cursor_col]
    jbe .read_loop
    mov bl, 0x1F
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    jmp .read_loop


.handle_ctrl_backspace:
    mov byte [.handle_ctrl_backspace_deleting_counter], 0
    test cx, cx
    je .read_loop

.handle_ctrl_backspace_loop:
    test cx, cx
    je .read_loop
    
    mov al, [di - 1]
    push ax

    dec di
    dec cx
    call string_get_cursor_pos
    cmp dl, [.cursor_col]
    jbe .read_loop
    mov bl, 0x1F
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char

    inc byte [.handle_ctrl_backspace_deleting_counter]

    pop ax

    cmp al, 'A'
    jb .handle_ctrl_backspace_not_L
    cmp al, 'Z'
    ja .handle_ctrl_backspace_not_L
    cmp byte [di], 'A'
    jb .handle_ctrl_backspace_end
    cmp byte [di], 'Z'
    ja .handle_ctrl_backspace_end
    jmp .handle_ctrl_backspace_loop

.handle_ctrl_backspace_not_L:  ; saved leter not at upper case
    cmp al, 'a'
    jb .handle_ctrl_backspace_not_l
    cmp al, 'z'
    ja .handle_ctrl_backspace_not_l
    cmp byte [di], 'a'
    jb .handle_ctrl_backspace_end
    cmp byte [di], 'z'
    ja .handle_ctrl_backspace_end
    jmp .handle_ctrl_backspace_loop

.handle_ctrl_backspace_not_l:  ; saved leter not at lower case
    cmp al, '0'
    jb .handle_ctrl_backspace_end
    cmp al, '9'
    ja .handle_ctrl_backspace_end
    cmp byte [di], '0'
    jb .handle_ctrl_backspace_end
    cmp byte [di], '9'
    ja .handle_ctrl_backspace_end
    jmp .handle_ctrl_backspace_loop

.handle_ctrl_backspace_end:
    cmp byte [.handle_ctrl_backspace_deleting_counter], 1
    jbe .read_loop
    mov byte [di], al
    inc di
    inc cx
    mov bl, 0x1F
    call print_char
    jmp .read_loop

.done_read:
    call .cur_erase
    call .ac_clear
    mov byte [di], 0
    popa
    mov byte [.current_history_pos], 0
    mov byte [.history_using], 0
    ret

.start_input_buf_addr dw 0
.handle_ctrl_backspace_deleting_counter db 0
.cursor_col dw 0
.current_history_pos db 0
.history_using db 0
.cur_visible db 0
.cur_last_tick dw 0
.cur_saved_char db 0
.cur_saved_attr db 0x07

; --------------- Blinking block cursor ---------------
.cur_draw:
    pusha
    cmp byte [.cur_visible], 1
    je short .cur_draw_done
    ; Save the character currently at cursor position before drawing block
    mov ah, 0x08
    mov bh, 0
    int 0x10
    mov [.cur_saved_char], al
    mov [.cur_saved_attr], ah
    ; Now draw the block cursor
    mov ah, 0x09
    mov al, 0xDB
    mov bh, 0
    mov bl, 0x1F
    mov cx, 1
    int 0x10
    mov byte [.cur_visible], 1
    mov ah, 0x00
    int 0x1A
    mov [.cur_last_tick], dx
.cur_draw_done:
    popa
    ret

.cur_erase:
    pusha
    cmp byte [.cur_visible], 0
    je short .cur_erase_done
    ; Read the character that was under the cursor before we drew the block
    mov ah, 0x08
    mov bh, 0
    int 0x10
    ; AL = char under cursor, AH = attribute
    ; If it was our block cursor (0xDB), replace with the saved char
    cmp al, 0xDB
    je .cur_erase_use_saved
    ; Otherwise restore whatever was there (shouldn't happen, but be safe)
    mov bl, ah
    mov ah, 0x09
    mov bh, 0
    mov cx, 1
    int 0x10
    jmp .cur_erase_mark_hidden
.cur_erase_use_saved:
    mov ah, 0x09
    mov al, [.cur_saved_char]
    mov bh, 0
    mov bl, [.cur_saved_attr]
    mov cx, 1
    int 0x10
.cur_erase_mark_hidden:
    mov byte [.cur_visible], 0
.cur_erase_done:
    popa
    ret

.cur_tick:
    pusha
    mov ah, 0x00
    int 0x1A
    sub dx, [.cur_last_tick]
    cmp dx, 9              ; ~500ms at 18.2 Hz
    jb short .cur_tick_done
    cmp byte [.cur_visible], 1
    jne short .cur_tick_show
    ; hide cursor
    mov ah, 0x09
    mov al, [.cur_saved_char]
    mov bh, 0
    mov bl, [.cur_saved_attr]
    mov cx, 1
    int 0x10
    mov byte [.cur_visible], 0
    jmp short .cur_tick_update
.cur_tick_show:
    mov ah, 0x09
    mov al, 0xDB
    mov bh, 0
    mov bl, 0x1F
    mov cx, 1
    int 0x10
    mov byte [.cur_visible], 1
.cur_tick_update:
    mov ah, 0x00
    int 0x1A
    mov [.cur_last_tick], dx
.cur_tick_done:
    popa
    ret

; --------------- Autocomplete: Tab handler ---------------
.ac_complete_tab:
    cmp word [.ac_sug_len], 0
    je .read_loop
    call .ac_clear
    mov ax, [.ac_match_off]
    sub di, ax
    sub cx, ax
    push cx
    mov cx, ax
    jcxz .ac_tab_erase_done
.ac_tab_erase:
    mov bl, 0x1F
    mov al, 0x08
    call print_char
    mov al, ' '
    call print_char
    mov al, 0x08
    call print_char
    dec cx
    jnz .ac_tab_erase
.ac_tab_erase_done:
    pop cx
    mov si, [.ac_match_ptr]
    mov bl, 0x1F
.ac_tab_copy:
    mov al, [si]
    cmp al, 0
    je .ac_tab_done
    stosb
    call print_char
    inc cx
    inc si
    cmp cx, 255
    jge .ac_tab_done
    jmp .ac_tab_copy
.ac_tab_done:
    mov word [.ac_sug_len], 0
    jmp .read_loop

; --------------- Autocomplete: clear old suggestion ---------------
.ac_clear:
    push ax
    push bx
    push cx
    push dx
    mov cx, [.ac_sug_len]
    test cx, cx
    je .ac_clear_done
    call string_get_cursor_pos
    push dx
    mov bl, 0x07
    mov al, ' '
.ac_clear_loop:
    call print_char
    dec cx
    jnz .ac_clear_loop
    pop dx
    call string_move_cursor
    mov word [.ac_sug_len], 0
.ac_clear_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------- Autocomplete: update suggestion ---------------
.ac_update:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    cmp byte [autocomplete_enabled], 0
    je .ac_update_ret
    test cx, cx
    je .ac_update_no_match

    mov byte [di], 0
    call .ac_clear

    mov si, [.start_input_buf_addr]
    xor bx, bx
.ac_scan_space:
    mov al, [si]
    cmp al, 0
    je .ac_scan_done
    cmp al, ' '
    jne .ac_scan_next
    lea bx, [si + 1]
.ac_scan_next:
    inc si
    jmp .ac_scan_space
.ac_scan_done:
    test bx, bx
    je .ac_try_cmd
    mov si, bx
    jmp .ac_do_file

.ac_try_cmd:
    mov si, [.start_input_buf_addr]
    call .ac_find_cmd
    jc .ac_show_match

    mov si, [.start_input_buf_addr]
    xor bx, bx

.ac_do_file:
    cmp byte [si], 0
    je .ac_update_no_match
    call .ac_find_file
    jnc .ac_update_no_match

.ac_show_match:
    mov [.ac_match_ptr], ax
    test bx, bx
    je .ac_prefix_full
    mov si, bx
    jmp .ac_calc_prefix
.ac_prefix_full:
    mov si, [.start_input_buf_addr]
.ac_calc_prefix:
    xor cx, cx
.ac_count_prefix:
    cmp byte [si], 0
    je .ac_prefix_counted
    inc si
    inc cx
    jmp .ac_count_prefix
.ac_prefix_counted:
    mov [.ac_match_off], cx

    mov si, [.ac_match_ptr]
    add si, cx
    cmp byte [si], 0
    je .ac_update_no_match

    call string_get_cursor_pos
    push dx
    mov bl, 0x07
    xor cx, cx
.ac_print_sug:
    mov al, [si]
    cmp al, 0
    je .ac_print_sug_done
    call print_char
    inc si
    inc cx
    jmp .ac_print_sug
.ac_print_sug_done:
    mov [.ac_sug_len], cx
    pop dx
    call string_move_cursor
    jmp .ac_update_ret

.ac_update_no_match:
    mov word [.ac_sug_len], 0
.ac_update_ret:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------- Autocomplete: find command match ---------------
.ac_find_cmd:
    push bx
    push cx
    push si
    push di
    mov [.ac_search_ptr], si
    mov bx, autocomplete_cmd_table
.ac_cmd_loop:
    mov di, [bx]
    test di, di
    je .ac_cmd_fail
    mov si, [.ac_search_ptr]
    call .ac_prefix_cmp
    jc .ac_cmd_ok
    add bx, 2
    jmp .ac_cmd_loop
.ac_cmd_ok:
    mov ax, di
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret
.ac_cmd_fail:
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

; --------------- Autocomplete: find file match ---------------
.ac_find_file:
    push bx
    push cx
    push si
    push di
    mov [.ac_search_ptr], si
    mov bx, dirlist
.ac_file_loop:
    cmp byte [bx], 0
    je .ac_file_fail
    push bx
    mov si, bx
    call .ac_entry_to_name
    pop bx
    mov si, [.ac_search_ptr]
    mov di, .ac_name_buf
    call .ac_prefix_cmp
    jc .ac_file_ok
    add bx, 18
    jmp .ac_file_loop
.ac_file_ok:
    mov ax, .ac_name_buf
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret
.ac_file_fail:
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret

; --------------- Autocomplete: convert dirlist entry to NAME.EXT ---------------
.ac_entry_to_name:
    push ax
    push cx
    push si
    push di
    mov di, .ac_name_buf
    mov cx, 9
.ac_e2n_name:
    mov al, [si]
    cmp al, ' '
    je .ac_e2n_skip_ns
    mov [di], al
    inc di
.ac_e2n_skip_ns:
    inc si
    dec cx
    jnz .ac_e2n_name
    cmp byte [si], ' '
    jne .ac_e2n_has_ext
    cmp byte [si+1], ' '
    jne .ac_e2n_has_ext
    cmp byte [si+2], ' '
    jne .ac_e2n_has_ext
    jmp .ac_e2n_done
.ac_e2n_has_ext:
    mov byte [di], '.'
    inc di
    mov cx, 3
.ac_e2n_ext:
    mov al, [si]
    cmp al, ' '
    je .ac_e2n_skip_es
    mov [di], al
    inc di
.ac_e2n_skip_es:
    inc si
    dec cx
    jnz .ac_e2n_ext
.ac_e2n_done:
    mov byte [di], 0
    pop di
    pop si
    pop cx
    pop ax
    ret

; --------------- Autocomplete: case-insensitive prefix compare ---------------
.ac_prefix_cmp:
    push ax
    push bx
    push si
    push di
.ac_cmp_loop:
    mov al, [si]
    cmp al, 0
    je .ac_cmp_end
    mov bl, [di]
    cmp bl, 0
    je .ac_cmp_no
    cmp al, 'a'
    jb .ac_cmp_u1
    cmp al, 'z'
    ja .ac_cmp_u1
    sub al, 32
.ac_cmp_u1:
    cmp bl, 'a'
    jb .ac_cmp_u2
    cmp bl, 'z'
    ja .ac_cmp_u2
    sub bl, 32
.ac_cmp_u2:
    cmp al, bl
    jne .ac_cmp_no
    inc si
    inc di
    jmp .ac_cmp_loop
.ac_cmp_end:
    cmp byte [di], 0
    je .ac_cmp_no
    pop di
    pop si
    pop bx
    pop ax
    stc
    ret
.ac_cmp_no:
    pop di
    pop si
    pop bx
    pop ax
    clc
    ret

.ac_sug_len      dw 0
.ac_match_ptr    dw 0
.ac_match_off    dw 0
.ac_search_ptr   dw 0
.ac_name_buf     times 14 db 0

; =======================================================================
; STRING_CLEAR_SCREEN - Clears the screen and applies theme
; IN  : Nothing
; OUT : Screen cleared and theme reloaded
; =======================================================================
string_clear_screen:
    pusha
    call set_video_mode
    popa
    call load_and_apply_theme
    ret

; =======================================================================
; STRING_GET_TIME_STRING - Gets current time as formatted string (HH:MM:SS)
; IN  : BX = pointer to buffer for time string (9 bytes minimum)
; OUT : Buffer filled with time string in format "HH:MM:SS"
; =======================================================================
string_get_time_string:
    pusha
    mov di, bx
    call timezone_get_local_datetime

    mov al, [timezone_local_hour]
    call .bin_to_bcd
    mov ch, al
    mov al, [timezone_local_minute]
    call .bin_to_bcd
    mov cl, al
    mov al, [timezone_local_second]
    call .bin_to_bcd
    mov dh, al

    mov al, ch
    shr al, 4
    and ch, 0Fh
    call .add_digit
    mov al, ch
    call .add_digit
    mov al, ':'
    stosb
    mov al, cl
    shr al, 4
    and cl, 0Fh
    call .add_digit
    mov al, cl
    call .add_digit
    mov al, ':'
    stosb
    mov al, dh
    shr al, 4
    and dh, 0Fh
    call .add_digit
    mov al, dh
    call .add_digit
    mov byte [di], 0
    popa
    ret

.bin_to_bcd:
    xor ah, ah
    mov bl, 10
    div bl
    shl al, 4
    or al, ah
    ret

.add_digit:
    add al, '0'
    stosb
    ret

; =======================================================================
; STRING_GET_DATE_STRING - Gets current date as formatted string
; IN  : BX = pointer to buffer for date string (11 bytes minimum)
; OUT : Buffer filled with date string 
; =======================================================================
string_get_date_string:
    pusha
    mov di, bx
    mov bx, [fmt_date]
    and bx, 7F03h
    call timezone_get_local_datetime

    mov al, [timezone_local_century]
    call .bin_to_bcd
    mov ch, al
    mov al, [timezone_local_year]
    call .bin_to_bcd
    mov cl, al
    mov al, [timezone_local_month]
    call .bin_to_bcd
    mov dh, al
    mov al, [timezone_local_day]
    call .bin_to_bcd
    mov dl, al

    cmp bl, 2
    jne .try_fmt1
    mov ah, ch
    call .add_2digits
    mov ah, cl
    call .add_2digits
    mov al, '/'
    stosb
    mov ah, dh
    call .add_2digits
    mov al, '/'
    stosb
    mov ah, dl
    call .add_2digits
    jmp short .done

.try_fmt1:
    cmp bl, 1
    jne .do_fmt0
    mov ah, dl
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, dh
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, ch
    cmp ah, 0
    je .fmt1_year
    call .add_1or2digits
.fmt1_year:
    mov ah, cl
    call .add_2digits
    jmp short .done

.do_fmt0:
    mov ah, dh
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, dl
    call .add_1or2digits
    mov al, '/'
    stosb
    mov ah, ch
    cmp ah, 0
    je .fmt0_year
    call .add_1or2digits
.fmt0_year:
    mov ah, cl
    call .add_2digits

.done:
    xor ax, ax
    stosw
    popa
    ret

.add_1or2digits:
    test ah, 0F0h
    jz .only_one
    call .add_2digits
    jmp short .two_done
.only_one:
    mov al, ah
    and al, 0Fh
    call .add_digit
.two_done:
    ret

.add_2digits:
    mov al, ah
    shr al, 4
    call .add_digit
    mov al, ah
    and al, 0Fh
    call .add_digit
    ret

.add_digit:
    add al, '0'
    stosb
    ret

.bin_to_bcd:
    xor ah, ah
    mov bl, 10
    div bl
    shl al, 4
    or al, ah
    ret

; =======================================================================
; STRING_BCD_TO_INT - Converts BCD (Binary Coded Decimal) to integer
; IN  : AL = BCD value
; OUT : AL = integer value
; =======================================================================
string_bcd_to_int:
    push cx
    mov cl, al
    shr al, 4
    and cl, 0Fh
    mov ah, 10
    mul ah
    add al, cl
    pop cx
    ret

; =======================================================================
; STRING_INT_TO_STRING - Converts integer to decimal string
; IN  : AX = integer value
; OUT : AX = pointer to converted string (static buffer)
; =======================================================================
string_int_to_string:
    pusha
    xor cx, cx
    mov bx, 10
    mov di, .t

.push:
    xor dx, dx
    div bx
    inc cx
    push dx
    test ax, ax
    jnz .push
.pop:
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    dec cx
    jnz .pop
    mov byte [di], 0
    popa
    mov ax, .t
    ret

.t times 7 db 0

; =======================================================================
; STRING_TO_INT - Converts decimal string to integer
; IN  : SI = pointer to decimal string
; OUT : AX = integer value (-1 if invalid)
; =======================================================================
string_to_int:
    push bx
    push cx
    push dx
    push si
    
    xor ax, ax
    xor bx, bx
    xor cx, cx
    
.convert_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    ja .invalid
    
    sub al, '0'
    mov cl, al
    mov ax, bx
    mov dx, 10
    mul dx
    add ax, cx
    mov bx, ax
    jmp .convert_loop
    
.invalid:
    mov bx, -1
    
.done:
    mov ax, bx
    pop si
    pop dx
    pop cx
    pop bx
    ret

; =======================================================================
; PARSE_PROMPT - Parses prompt string with variable substitution
; IN  : SI = pointer to source prompt string
;       DI = pointer to destination buffer
; OUT : Destination buffer filled with parsed prompt
;       Supports: $username (replaced with user variable)
;                 %XX (hex escape codes, e.g., %0A for newline)
; =======================================================================
parse_prompt:
    push ax
    push bx
    push cx
    push si
    push di
    mov cx, 63

.loop:
    lodsb               
    cmp al, 0              
    je .done
    cmp al, '$'        
    je .check_username
    cmp al, '%'             
    je .check_hex
.store:
    call .store_char
    jc .done
    jmp .loop

.check_username:
    ; Check for $username (next 8 bytes: 'u','s','e','r','n','a','m','e')
    mov ax, [si]
    cmp ax, 0x7375           ; 'u' (0x75), 's' (0x73) -> 0x7375
    jne .store_dollar
    mov ax, [si+2]
    cmp ax, 0x7265           ; 'e' (0x65), 'r' (0x72) -> 0x7265
    jne .store_dollar
    mov ax, [si+4]
    cmp ax, 0x616E           ; 'n' (0x6E), 'a' (0x61) -> 0x616E
    jne .store_dollar
    mov ax, [si+6]
    cmp ax, 0x656D           ; 'm' (0x6D), 'e' (0x65) -> 0x656D
    jne .store_dollar
    add si, 8
    push si
    mov si, user
.copy_user:
    lodsb
    cmp al, 0
    je .user_done
    call .store_char
    jc .done
    jmp .copy_user
.user_done:
    pop si
    jmp .loop

.store_dollar:
    mov al, '$'
    call .store_char
    jc .done
    jmp .loop

.check_hex:
    mov al, [si]    
    cmp al, 0                
    je .store_percent
    inc si
    mov ah, [si]     
    cmp ah, 0                
    je .store_percent
    inc si               

    call hex_char_to_nibble
    jc .store_percent        
    mov bl, al
    shl bl, 4             

    mov al, ah
    call hex_char_to_nibble
    jc .store_percent        
    or bl, al     

    mov al, bl
    call .store_char
    jc .done
    jmp .loop

.store_percent:
    mov al, '%'
    call .store_char
    jc .done
    dec si     
    cmp ah, 0       
    je .loop
    dec si
    jmp .loop

.done:
    mov byte [di], 0     
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

.store_char:
    test cx, cx
    je .store_full
    stosb
    dec cx
    clc
    ret
.store_full:
    stc
    ret

; =======================================================================
; HEX_CHAR_TO_NIBBLE - Converts hexadecimal character to 4-bit value
; IN  : AL = hex character ('0'-'9', 'A'-'F', 'a'-'f')
; OUT : AL = nibble value (0-15)
;       CF = 0 if valid, CF = 1 if invalid character
; =======================================================================
hex_char_to_nibble:
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .invalid
    cmp al, 'F'
    jbe .uppercase
    cmp al, 'a'
    jb .invalid
    cmp al, 'f'
    jbe .lowercase
.invalid:
    stc
    ret
.digit:
    sub al, '0'
    clc
    ret
.uppercase:
    sub al, 'A'
    add al, 10
    clc
    ret
.lowercase:
    sub al, 'a'
    add al, 10
    clc
    ret