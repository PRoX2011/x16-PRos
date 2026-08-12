%define CAL_CW        22
%define CAL_CH        16
%define CAL_W         (7 * CAL_CW + 8)
%define CAL_X         (640 - CAL_W - 2)
%define CAL_Y         MENUBAR_H
%define CAL_HDR_H     18
%define CAL_WD_Y      (CAL_Y + CAL_HDR_H)
%define CAL_DAY_Y     (CAL_WD_Y + CAL_CH)
%define CAL_H         (CAL_HDR_H + CAL_CH * 7 + 4)
%define CAL_GX        (CAL_X + 4)
%define CAL_BTN_W     14
%define CAL_BTN_H     14
%define CAL_BTN_Y     (CAL_Y + 2)
%define CAL_PREV_X    (CAL_X + 4)
%define CAL_NEXT_X    (CAL_X + CAL_W - 4 - CAL_BTN_W)

; ========================================================================
; CAL_READ_TODAY - Reads the RTC into the "today" fields
; IN : nothing
; OUT : cal_today_d, cal_today_m, cal_today_y filled
; ========================================================================
cal_read_today:
    pusha
    mov ah, 0x0B
    int 0x21
    mov [cal_today_m], dh
    mov [cal_today_d], dl
    xor ah, ah
    mov al, ch
    mov bl, 100
    mul bl
    xor bh, bh
    mov bl, cl
    add ax, bx
    mov [cal_today_y], ax
    popa
    ret

; ========================================================================
; CAL_IS_LEAP - Tests the shown year for a leap year
; IN : cal_year
; OUT : CF = 1 if the year is a leap year
; ========================================================================
cal_is_leap:
    push ax
    push bx
    push dx
    mov ax, [cal_year]
    test al, 3
    jnz .no
    xor dx, dx
    mov bx, 100
    div bx
    test dx, dx
    jnz .yes
    test al, 3
    jnz .no
.yes:
    pop dx
    pop bx
    pop ax
    stc
    ret
.no:
    pop dx
    pop bx
    pop ax
    clc
    ret

; ========================================================================
; CAL_DAYS_IN_MONTH - Length of the shown month
; IN : cal_month, cal_year
; OUT : AL = number of days
; ========================================================================
cal_days_in_month:
    push bx
    xor ah, ah
    mov al, [cal_month]
    cmp al, 2
    jne .table
    call cal_is_leap
    jnc .table
    mov al, 29
    pop bx
    ret
.table:
    dec al
    xor ah, ah
    mov bx, ax
    mov al, [cal_days_table + bx]
    pop bx
    ret

; ========================================================================
; CAL_ZELLER - Weekday of the first day of the shown month
; IN : cal_month, cal_year
; OUT : AL = grid column, 0 = Monday
; ========================================================================
cal_zeller:
    push bx
    push cx
    push dx

    xor ah, ah
    mov al, [cal_month]
    mov bx, [cal_year]
    cmp al, 3
    jge .no_adj
    add al, 12
    dec bx
.no_adj:
    mov [.m], al
    mov [.y], bx

    mov ax, bx
    xor dx, dx
    mov cx, 100
    div cx
    mov [.j], ax
    mov [.k], dx

    xor ah, ah
    mov al, [.m]
    inc al
    mov bl, 13
    mul bl
    mov bl, 5
    div bl
    xor ah, ah
    mov [.t], ax

    mov ax, [.k]
    shr ax, 2
    add ax, [.t]
    add ax, [.k]
    mov bx, [.j]
    shr bx, 2
    add ax, bx
    mov bx, [.j]
    shl bx, 2
    add bx, [.j]
    add ax, bx
    add ax, 6

    xor dx, dx
    mov cx, 7
    div cx
    mov al, dl

    pop dx
    pop cx
    pop bx
    ret
.m dw 0
.y dw 0
.j dw 0
.k dw 0
.t dw 0

; ========================================================================
; CAL_PREV_MONTH - Steps the shown month one back
; IN : cal_month, cal_year
; OUT : cal_month, cal_year updated
; ========================================================================
cal_prev_month:
    dec byte [cal_month]
    cmp byte [cal_month], 0
    jne .done
    mov byte [cal_month], 12
    dec word [cal_year]
.done:
    ret

; ========================================================================
; CAL_NEXT_MONTH - Steps the shown month one forward
; IN : cal_month, cal_year
; OUT : cal_month, cal_year updated
; ========================================================================
cal_next_month:
    inc byte [cal_month]
    cmp byte [cal_month], 13
    jne .done
    mov byte [cal_month], 1
    inc word [cal_year]
.done:
    ret

; ========================================================================
; CAL_BUILD_HEADER - Renders "Month YYYY" into cal_hdr_buf
; IN : cal_month, cal_year
; OUT : cal_hdr_buf filled, null terminated
; ========================================================================
cal_build_header:
    pusha
    mov di, cal_hdr_buf
    xor ah, ah
    mov al, [cal_month]
    dec al
    shl al, 1
    mov bx, ax
    mov si, [cal_month_ptrs + bx]
.name:
    mov al, [si]
    test al, al
    jz .space
    mov [di], al
    inc si
    inc di
    jmp .name
.space:
    mov byte [di], ' '
    inc di
    mov ax, [cal_year]
    mov bx, 1000
    call .digit
    mov bx, 100
    call .digit
    mov bx, 10
    call .digit
    add al, '0'
    mov [di], al
    inc di
    mov byte [di], 0
    popa
    ret
.digit:
    xor dx, dx
    div bx
    add al, '0'
    mov [di], al
    inc di
    mov ax, dx
    ret

; ========================================================================
; CAL_DRAW - Paints the whole calendar panel
; IN : cal_month, cal_year
; OUT : nothing
; ========================================================================
cal_draw:
    pusha
    mov ah, 0x22
    int 0x23

    mov cx, CAL_X
    mov dx, CAL_Y
    mov si, CAL_W
    mov di, CAL_H
    mov al, WG_FACE
    call wg_panel

    mov cx, CAL_X + 1
    mov dx, CAL_Y + 1
    mov si, CAL_W - 2
    mov di, CAL_HDR_H
    mov al, WG_HEAD
    call gfx_fill_rect

    mov cx, CAL_PREV_X
    mov dx, CAL_BTN_Y
    mov si, CAL_BTN_W
    mov di, CAL_BTN_H
    mov al, '<'
    call wg_button
    mov cx, CAL_NEXT_X
    mov dx, CAL_BTN_Y
    mov si, CAL_BTN_W
    mov di, CAL_BTN_H
    mov al, '>'
    call wg_button

    call cal_build_header
    mov si, cal_hdr_buf
    mov cx, CAL_X
    mov dx, CAL_Y + 1
    mov di, CAL_W
    mov al, WG_TEXT
    call wg_text_center

    mov si, cal_wd_names
    mov word [.i], 0
.weekday:
    cmp word [.i], 7
    jae .grid
    mov ax, [.i]
    mov bx, CAL_CW
    mul bx
    add ax, CAL_GX + 3
    mov cx, ax
    mov dx, CAL_WD_Y
    mov al, WG_DIM
    call wg_text_at
    add si, 3
    inc word [.i]
    jmp .weekday

.grid:
    call cal_zeller
    mov [.col], al
    call cal_days_in_month
    mov [.total], al
    mov byte [.day], 1
    mov byte [.row], 0

.day_loop:
    mov al, [.day]
    cmp al, [.total]
    ja .frame

    cmp byte [.col], 7
    jne .place
    mov byte [.col], 0
    inc byte [.row]

.place:
    mov al, [.col]
    xor ah, ah
    mov bx, CAL_CW
    mul bx
    add ax, CAL_GX
    mov [.cx], ax

    mov al, [.row]
    xor ah, ah
    mov bx, CAL_CH
    mul bx
    add ax, CAL_DAY_Y
    mov [.cy], ax

    mov byte [.tc], 0
    mov al, [cal_month]
    cmp al, [cal_today_m]
    jne .no_today
    mov ax, [cal_year]
    cmp ax, [cal_today_y]
    jne .no_today
    mov al, [.day]
    cmp al, [cal_today_d]
    jne .no_today
    mov cx, [.cx]
    mov dx, [.cy]
    mov si, CAL_CW
    mov di, CAL_CH
    mov al, 1
    call gfx_fill_rect
    mov byte [.tc], 15

.no_today:
    mov al, [.day]
    xor ah, ah
    mov bl, 10
    div bl
    mov [.ones], ah
    mov di, cal_day_buf
    test al, al
    jnz .tens
    mov byte [di], ' '
    jmp .ones_out
.tens:
    add al, '0'
    mov [di], al
.ones_out:
    mov al, [.ones]
    add al, '0'
    mov [di+1], al
    mov byte [di+2], 0

    mov si, cal_day_buf
    mov cx, [.cx]
    add cx, 3
    mov dx, [.cy]
    mov al, [.tc]
    call wg_text_at

    inc byte [.col]
    inc byte [.day]
    jmp .day_loop

.frame:
    mov ah, 0x23
    int 0x23
    popa
    ret
.i     dw 0
.cx    dw 0
.cy    dw 0
.col   db 0
.row   db 0
.day   db 0
.total db 0
.ones  db 0
.tc    db 0

; ========================================================================
; CAL_HIT - Tells which part of the panel the pointer is over
; IN : mx, my
; OUT : AL = 0 outside, 1 prev button, 2 next button, 3 panel body
; ========================================================================
cal_hit:
    mov cx, CAL_PREV_X
    mov dx, CAL_BTN_Y
    mov si, CAL_BTN_W
    mov di, CAL_BTN_H
    call wg_hit_rect
    jc .prev

    mov cx, CAL_NEXT_X
    mov dx, CAL_BTN_Y
    mov si, CAL_BTN_W
    mov di, CAL_BTN_H
    call wg_hit_rect
    jc .next

    mov cx, CAL_X
    mov dx, CAL_Y
    mov si, CAL_W
    mov di, CAL_H
    call wg_hit_rect
    jc .body

    xor al, al
    ret
.prev:
    mov al, 1
    ret
.next:
    mov al, 2
    ret
.body:
    mov al, 3
    ret

; ========================================================================
; CAL_HANDLE_PRESS - Mouse press handler for the calendar panel
; IN : mx, my, cal_open
; OUT : CF = 1 if the press was consumed
; ========================================================================
cal_handle_press:
    cmp byte [cal_open], 0
    je .closed

    call cal_hit
    cmp al, 1
    je .prev
    cmp al, 2
    je .next
    cmp al, 3
    je .swallow
    call hit_date
    jc .dismiss
    call cal_close
    stc
    ret
.prev:
    call cal_prev_month
    call cal_draw
    stc
    ret
.next:
    call cal_next_month
    call cal_draw
    stc
    ret
.swallow:
    stc
    ret
.dismiss:
    call cal_close
    stc
    ret

.closed:
    call hit_date
    jnc .pass
    cmp byte [menu_open], 0
    jne .pass
    call cal_read_today
    mov al, [cal_today_m]
    mov [cal_month], al
    mov ax, [cal_today_y]
    mov [cal_year], ax
    mov byte [cal_open], 1
    call cal_draw
    stc
    ret
.pass:
    clc
    ret

; ========================================================================
; CAL_CLOSE - Hides the panel and repaints what it covered
; IN : nothing
; OUT : cal_open = 0
; ========================================================================
cal_close:
    mov byte [cal_open], 0
    call full_repaint
    ret

cal_open        db 0
cal_month       db 1
cal_year        dw 2000
cal_today_d     db 0
cal_today_m     db 0
cal_today_y     dw 0
cal_hdr_buf     times 20 db 0
cal_day_buf     times 4  db 0
cal_days_table  db 31,28,31,30,31,30,31,31,30,31,30,31

cal_wd_names:
    db 'Mo',0
    db 'Tu',0
    db 'We',0
    db 'Th',0
    db 'Fr',0
    db 'Sa',0
    db 'Su',0

cal_month_ptrs:
    dw .jan,.feb,.mar,.apr,.may,.jun
    dw .jul,.aug,.sep,.oct,.nov,.dec

.jan db 'January',0
.feb db 'February',0
.mar db 'March',0
.apr db 'April',0
.may db 'May',0
.jun db 'June',0
.jul db 'July',0
.aug db 'August',0
.sep db 'September',0
.oct db 'October',0
.nov db 'November',0
.dec db 'December',0
