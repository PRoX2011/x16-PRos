; ==================================================================
; x16-PRos - timezone support for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; =======================================================================
; LOAD_TIMEZONE_CFG - Loads and parses CONF.DIR/TIMEZONE.CFG
; OUT : timezone_offset = signed offset in hours
;       Falls back to 0 on any load/parse error
; =======================================================================
load_timezone_cfg:
    pusha

    mov word [timezone_offset], 0

    call save_current_dir
    mov al, 'A'
    call fs_change_drive_letter
    mov byte [current_directory], 0
    mov word [current_dir_cluster], 0

    mov ax, conf_dir_name
    call fs_change_directory
    jc .restore_done

    mov ax, timezone_cfg_file
    mov cx, program_load_addr
    call fs_load_file
    jc .restore_dir

    mov si, program_load_addr
    add si, bx
    mov byte [si], 0

    mov si, program_load_addr
    call timezone_parse_offset
    jc .restore_dir

    mov [timezone_offset], ax

.restore_dir:
    call fs_parent_directory

.restore_done:
    call restore_current_dir

.done:
    popa
    ret

; =======================================================================
; TIMEZONE_PARSE_OFFSET - Parses signed decimal timezone offset
; IN  : SI = pointer to null-terminated string
; OUT : AX = signed offset in hours, CF = 0 if success
;       CF = 1 on invalid format
; Notes:
;   - Accepts optional sign (+/-)
;   - Ignores leading/trailing spaces and CR/LF/TAB
;   - Requires at least one digit
; =======================================================================
timezone_parse_offset:
    push bx
    push cx
    push dx
    push di
    push si

    xor bx, bx
    mov di, 1
    xor cx, cx

.skip_leading:
    lodsb
    cmp al, ' '
    je .skip_leading
    cmp al, 9
    je .skip_leading
    cmp al, 13
    je .skip_leading
    cmp al, 10
    je .skip_leading
    cmp al, 0
    je .parse_fail

    cmp al, '-'
    jne .check_plus
    mov di, -1
    jmp .read_first

.check_plus:
    cmp al, '+'
    jne .maybe_digit
    jmp .read_first

.read_first:
    lodsb

.maybe_digit:
    cmp al, '0'
    jb .parse_fail
    cmp al, '9'
    ja .parse_fail

.digit_loop:
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
    inc cx

    lodsb
    cmp al, '0'
    jb .after_digits
    cmp al, '9'
    jbe .digit_loop

.after_digits:
    test cx, cx
    je .parse_fail

.skip_trailing:
    cmp al, ' '
    je .read_next_trailing
    cmp al, 9
    je .read_next_trailing
    cmp al, 13
    je .read_next_trailing
    cmp al, 10
    je .read_next_trailing
    cmp al, 0
    jne .parse_fail
    jmp .build_result

.read_next_trailing:
    lodsb
    jmp .skip_trailing

.build_result:
    mov ax, bx
    cmp di, 1
    je .parse_ok
    neg ax

.parse_ok:
    clc
    jmp .return

.parse_fail:
    stc

.return:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    ret

; =======================================================================
; TIMEZONE_GET_LOCAL_DATETIME - Reads RTC and applies timezone_offset
; OUT : timezone_local_{hour,min,sec,day,month,year,century}
; =======================================================================
timezone_get_local_datetime:
    pusha

    ; Read RTC time (BCD)
    clc
    mov ah, 2
    int 1Ah
    jnc .time_ok
    clc
    mov ah, 2
    int 1Ah

.time_ok:
    mov al, ch
    call string_bcd_to_int
    mov [timezone_local_hour], al

    mov al, cl
    call string_bcd_to_int
    mov [timezone_local_minute], al

    mov al, dh
    call string_bcd_to_int
    mov [timezone_local_second], al

    ; Read RTC date (BCD)
    clc
    mov ah, 4
    int 1Ah
    jnc .date_ok
    clc
    mov ah, 4
    int 1Ah

.date_ok:
    mov al, ch
    call string_bcd_to_int
    mov [timezone_local_century], al

    mov al, cl
    call string_bcd_to_int
    mov [timezone_local_year], al

    mov al, dh
    call string_bcd_to_int
    mov [timezone_local_month], al

    mov al, dl
    call string_bcd_to_int
    mov [timezone_local_day], al

    ; Apply timezone offset to hour and collect day delta.
    mov byte [timezone_day_delta], 0
    mov al, [timezone_local_hour]
    cbw
    add ax, [timezone_offset]

.normalize_low:
    cmp ax, 0
    jge .normalize_high
    add ax, 24
    dec byte [timezone_day_delta]
    jmp .normalize_low

.normalize_high:
    cmp ax, 24
    jl .hour_ready
    sub ax, 24
    inc byte [timezone_day_delta]
    jmp .normalize_high

.hour_ready:
    mov [timezone_local_hour], al

    ; Adjust date when crossing day boundary.
    cmp byte [timezone_day_delta], 0
    je .done
    call timezone_apply_day_delta

.done:
    popa
    ret

; =======================================================================
; TIMEZONE_APPLY_DAY_DELTA - Applies timezone_day_delta to local date
; =======================================================================
timezone_apply_day_delta:
    push ax
    push bx
    push cx
    push dx

.delta_loop:
    mov al, [timezone_day_delta]
    cmp al, 0
    je .finish
    js .step_back

    call .step_forward_date
    dec byte [timezone_day_delta]
    jmp .delta_loop

.step_back:
    call .step_backward_date
    inc byte [timezone_day_delta]
    jmp .delta_loop

.finish:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.step_forward_date:
    inc byte [timezone_local_day]

    mov bl, [timezone_local_month]
    call .get_full_year_ax
    call .days_in_month

    mov dl, [timezone_local_day]
    cmp dl, al
    jbe .step_forward_done

    mov byte [timezone_local_day], 1
    inc byte [timezone_local_month]
    cmp byte [timezone_local_month], 13
    jb .step_forward_done

    mov byte [timezone_local_month], 1
    inc byte [timezone_local_year]
    cmp byte [timezone_local_year], 100
    jb .step_forward_done
    mov byte [timezone_local_year], 0
    inc byte [timezone_local_century]

.step_forward_done:
    ret

.step_backward_date:
    cmp byte [timezone_local_day], 1
    jbe .borrow_previous_month
    dec byte [timezone_local_day]
    ret

.borrow_previous_month:
    dec byte [timezone_local_month]
    cmp byte [timezone_local_month], 0
    jne .month_ready

    mov byte [timezone_local_month], 12
    cmp byte [timezone_local_year], 0
    jne .dec_year_only
    mov byte [timezone_local_year], 99
    dec byte [timezone_local_century]
    jmp .month_ready

.dec_year_only:
    dec byte [timezone_local_year]

.month_ready:
    mov bl, [timezone_local_month]
    call .get_full_year_ax
    call .days_in_month
    mov [timezone_local_day], al
    ret

.get_full_year_ax:
    ; AX = century * 100 + year
    mov al, [timezone_local_century]
    xor ah, ah
    mov cx, 100
    mul cx
    xor cx, cx
    mov cl, [timezone_local_year]
    add ax, cx
    ret

.days_in_month:
    ; IN : BL = month (1..12), AX = full year
    ; OUT: AL = days in month
    cmp bl, 2
    je .february
    cmp bl, 4
    je .thirty
    cmp bl, 6
    je .thirty
    cmp bl, 9
    je .thirty
    cmp bl, 11
    je .thirty
    mov al, 31
    ret

.thirty:
    mov al, 30
    ret

.february:
    call .is_leap_year
    jc .feb_leap
    mov al, 28
    ret

.feb_leap:
    mov al, 29
    ret

.is_leap_year:
    ; IN : AX = full year
    ; OUT: CF = 1 leap year, CF = 0 otherwise
    push bx
    push dx

    mov [timezone_tmp_year], ax

    xor dx, dx
    mov bx, 4
    div bx
    test dx, dx
    jne .not_leap

    mov ax, [timezone_tmp_year]
    xor dx, dx
    mov bx, 100
    div bx
    test dx, dx
    jne .leap

    mov ax, [timezone_tmp_year]
    xor dx, dx
    mov bx, 400
    div bx
    test dx, dx
    jne .not_leap

.leap:
    pop dx
    pop bx
    stc
    ret

.not_leap:
    pop dx
    pop bx
    clc
    ret

timezone_local_hour    db 0
timezone_local_minute  db 0
timezone_local_second  db 0
timezone_local_day     db 1
timezone_local_month   db 1
timezone_local_year    db 0
timezone_local_century db 20
timezone_day_delta     db 0
timezone_tmp_year      dw 0