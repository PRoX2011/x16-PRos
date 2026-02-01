[BITS 16]
[ORG 0x8000]

; ----------------------------
; CONFIG
; ----------------------------
%define SCREEN_W      80
%define SCREEN_H      25

%define BAR_ATTR      0x60
%define TEXT_ATTR     0x06

%define DOT_CHAR      '*'

%define CENTER_ROW    12
%define CENTER_COL    39
%define DOT_RADIUS    9

%define CENTER_MS     2000
%define DOT_MS        1000
%define GAP_MS        800

%define TEXT_ROW_MAIN 12
%define TEXT_ROW_HINT 23

start:
    push cs
    pop ds

    call ui_enter
    call draw_wrapper


    mov ax, 500
    call sleep_ms_esc
    jc exit_program

    ; 1) Licensed
    call clear_inside
    mov si, msg_license
    mov dh, TEXT_ROW_MAIN
    call draw_centered_text_row
    call draw_hint
    call play_beep

    mov ax, CENTER_MS
    call sleep_ms_esc
    jc exit_program

main_loop:

    mov ax, 500
    call sleep_ms_esc
    jc exit_program


    ; 1) LOOK AT THE CENTER
    call clear_inside
    mov bx, center_tbl
    mov cx, center_tbl_count
    call pick_phrase
    mov dh, TEXT_ROW_MAIN
    call draw_centered_text_row
    call draw_hint
    call play_beep

    mov ax, CENTER_MS
    call sleep_ms_esc
    jc exit_program

    ; 2) DOT
    call clear_inside
    call rand_dir8
    call compute_dot_pos

    mov dh, [dot_row]
    mov dl, [dot_col]
    mov al, DOT_CHAR
    mov bl, TEXT_ATTR
    call put_char_attr

    call draw_hint
    call play_beep

    mov ax, DOT_MS
    call sleep_ms_esc
    jc exit_program

    ; 3) DOT

    call clear_inside
    call rand_dir8
    call compute_dot_pos

    mov dh, [dot_row]
    mov dl, [dot_col]
    mov al, DOT_CHAR
    mov bl, TEXT_ATTR
    call put_char_attr

    call draw_hint
    call play_beep

    mov ax, DOT_MS
    call sleep_ms_esc
    jc exit_program

    ; 4) DOT

    call clear_inside
    call rand_dir8
    call compute_dot_pos

    mov dh, [dot_row]
    mov dl, [dot_col]
    mov al, DOT_CHAR
    mov bl, TEXT_ATTR
    call put_char_attr

    call draw_hint
    call play_beep

    mov ax, DOT_MS
    call sleep_ms_esc
    jc exit_program

    ; 5) GAP / RELAX
    call clear_inside
    mov bx, relax_tbl
    mov cx, relax_tbl_count
    call pick_phrase
    mov dh, TEXT_ROW_MAIN
    call draw_centered_text_row
    call draw_hint

    mov ax, GAP_MS
    call sleep_ms_esc
    jc exit_program

    jmp main_loop

exit_program:
    call ui_exit
    ret

; ============================================================
; UI
; ============================================================

ui_enter:
    ; clean screen
    mov ax, 0600h
    mov bh, 0x0F
    xor cx, cx
    mov dx, 184Fh
    int 10h

    ; text mode 03
    mov ax, 0x0003
    int 10h

    ; hide cursor
    mov ah, 01h
    mov ch, 20h
    mov cl, 00h
    int 10h
    ret

ui_exit:
    ; return to VGA mode 0x12
    mov ax, 0x0012
    int 10h
    ret

; ============================================================
; Drawing primitives (int 10h)
; ============================================================

set_cursor:
    ; DL=col, DH=row
    mov ah, 02h
    xor bh, bh
    int 10h
    ret

put_char_attr:
    ; AL=char, BL=attr, DL=col, DH=row
    push ax
    push bx
    push cx
    call set_cursor
    mov ah, 09h
    xor bh, bh
    mov cx, 1
    int 10h
    pop cx
    pop bx
    pop ax
    ret

fill_row_attr:
    ; DH=row, BL=attr, AL=char, CX=count, DL=start_col
    push ax
    push bx
    push cx
    call set_cursor
    mov ah, 09h
    xor bh, bh
    int 10h
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; Wrapper bars
; ============================================================

draw_wrapper:
    push ax
    push bx
    push cx
    push dx

    ; Top bar row 0
    mov dh, 0
    mov dl, 0
    mov al, ' '
    mov bl, BAR_ATTR
    mov cx, SCREEN_W
    call fill_row_attr

    ; Bottom bar row 24
    mov dh, SCREEN_H-1
    mov dl, 0
    mov al, ' '
    mov bl, BAR_ATTR
    mov cx, SCREEN_W
    call fill_row_attr

    ; Side bars rows 1..23 at col 0 and col 79
    mov dh, 1
.side_loop:
    cmp dh, SCREEN_H-2
    ja  .done

    mov dl, 0
    mov al, ' '
    mov bl, BAR_ATTR
    call put_char_attr

    mov dl, SCREEN_W-1
    mov al, ' '
    mov bl, BAR_ATTR
    call put_char_attr

    inc dh
    jmp .side_loop

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

clear_inside:
    ; clear rows 1..23 cols 1..78
    mov ax, 0600h
    mov bh, 0x00        ; black
    mov cx, 0101h       ; row=1 col=1
    mov dx, 174Eh       ; row=23 col=78
    int 10h
    ret

; ============================================================
; Text rendering
; ============================================================

draw_hint:
    mov si, msg_hint
    mov dh, TEXT_ROW_HINT
    call draw_centered_text_row
    ret

draw_centered_text_row:
    ; SI -> string (0-term), DH=row
    push ax
    push bx
    push cx
    push dx
    push si

    cmp si, 0
    je .done

    cmp si, 0x8000
    jb .done

    call strlen_preserve     ; CX=len

    cmp cx, 0
    je .done
    cmp cx, 78
    jbe .len_ok
    mov cx, 78
.len_ok:

    ; start_col = 1 + (78-len)/2
    mov ax, 78
    sub ax, cx
    shr ax, 1
    inc ax
    mov dl, al               ; DL=start col

    mov bl, TEXT_ATTR
.print_loop:
    cmp cx, 0
    je .done
    lodsb
    test al, al
    jz .done

    cmp al, 32
    jb .skip_char
    cmp al, 126
    ja .skip_char

    call put_char_attr
.skip_char:
    inc dl
    dec cx
    jmp .print_loop

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

strlen_preserve:
    push ax
    push si
    xor cx, cx

    cmp si, 0
    je .out
    cmp si, 0x8000
    jb .out

.len:
    cmp cx, 200
    jge .out

    mov al, [si]
    test al, al
    jz .out

    cmp al, 32
    jb .out

    inc si
    inc cx
    jmp .len
.out:
    pop si
    pop ax
    ret

; ============================================================
; Random + dot position
; ============================================================

rand_dir8:
    push cx
    push dx
    mov ah, 00h
    int 1Ah
    mov al, dl
    and al, 7
    pop dx
    pop cx
    ret

compute_dot_pos:
    ; AL=0..7 -> dot_row/dot_col
    push ax
    push bx
    push cx
    push dx

    mov bx, CENTER_ROW
    mov cx, CENTER_COL
    xor dx, dx               ; DL=row delta, DH=col delta (signed)

    ; 0=U,1=UR,2=R,3=DR,4=D,5=DL,6=L,7=UL
    cmp al, 0
    jne .d1
    mov dl, -DOT_RADIUS
    jmp .apply
.d1:
    cmp al, 1
    jne .d2
    mov dl, -DOT_RADIUS
    mov dh, +DOT_RADIUS
    jmp .apply
.d2:
    cmp al, 2
    jne .d3
    mov dh, +DOT_RADIUS
    jmp .apply
.d3:
    cmp al, 3
    jne .d4
    mov dl, +DOT_RADIUS
    mov dh, +DOT_RADIUS
    jmp .apply
.d4:
    cmp al, 4
    jne .d5
    mov dl, +DOT_RADIUS
    jmp .apply
.d5:
    cmp al, 5
    jne .d6
    mov dl, +DOT_RADIUS
    mov dh, -DOT_RADIUS
    jmp .apply
.d6:
    cmp al, 6
    jne .d7
    mov dh, -DOT_RADIUS
    jmp .apply
.d7:
    mov dl, -DOT_RADIUS
    mov dh, -DOT_RADIUS

.apply:
    mov al, dl
    cbw
    add bx, ax

    mov al, dh
    cbw
    add cx, ax

    ; clamp row 1..23
    cmp bx, 1
    jge .rlo
    mov bx, 1
.rlo:
    cmp bx, 23
    jle .rhi
    mov bx, 23
.rhi:

    ; clamp col 1..78
    cmp cx, 1
    jge .clo
    mov cx, 1
.clo:
    cmp cx, 78
    jle .chi
    mov cx, 78
.chi:

    mov [dot_row], bl
    mov [dot_col], cl

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; ESC + sleep via BIOS ticks (int 1Ah)
; ============================================================

check_esc:
    ; CF=1 if ESC pressed, non-blocking
    push ax
    mov ah, 01h
    int 16h
    jz .no

    mov ah, 00h
    int 16h
    cmp al, 1Bh
    je .yes
    cmp ah, 01h         ; scan code ESC
    je .yes

.no:
    clc
    pop ax
    ret
.yes:
    stc
    pop ax
    ret

; sleep_ms_esc:
;   AX = milliseconds (0..65535)
;   CF=1 if ESC
sleep_ms_esc:
    push ax
    push bx
    push dx
    push si

    cmp ax, 0
    je .ok

    ; ticks = ceil(ms / 55) = (ms + 54) / 55
    mov bx, ax
    add bx, 54
    mov ax, bx
    xor dx, dx
    mov bx, 55
    div bx              ; AX = ticks
    mov si, ax          ; SI = target ticks

    cmp si, 0
    je .ok

    call sleep_ticks_esc
    jc .esc
.ok:
    clc
    jmp .done
.esc:
    stc
.done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

; sleep_ticks_esc:
;   SI = ticks to wait
;   CF=1 if ESC
sleep_ticks_esc:
    push ax
    push bx
    push cx
    push dx
    push bp

    ; start = CX:DX
    mov ah, 00h
    int 1Ah
    mov bx, dx          ; start_low
    mov bp, cx          ; start_high

.wait:
    call check_esc
    jc .esc

    mov ah, 00h
    int 1Ah             ; now = CX:DX

    ; delta = now - start (32-bit)
    mov ax, dx
    sub ax, bx          ; delta_low in AX
    mov dx, cx
    sbb dx, bp          ; delta_high in DX

    cmp dx, 0
    jne .ok

    cmp ax, si
    jb .wait

.ok:
    clc
    jmp .done

.esc:
    stc

.done:
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret


; ============================================================
; Beep
; ============================================================

play_beep:
    push ax
    push bx
    mov ah, 0Eh
    mov al, 07h
    xor bh, bh
    mov bl, 0x0F
    int 10h
    pop bx
    pop ax
    ret



; ============================================================
; Phrase Pick
; ============================================================

pick_phrase:
    push ax
    push cx
    push dx
    push di
    push bp

    mov bp, bx
    mov di, cx

    mov ah, 00h
    int 1Ah

    mov ax, dx
    xor dx, dx

    cmp di, 0
    je .use_first

    div di

    mov si, dx
    shl si, 1
    add si, bp
    mov si, [si]
    jmp .done

.use_first:
    mov si, [bp]

.done:
    pop bp
    pop di
    pop dx
    pop cx
    pop ax
    ret


; ============================================================
; DATA
; ============================================================

dot_row db CENTER_ROW
dot_col db CENTER_COL

; ---- Center phrases ----
center_tbl:
    dw msg_center_1
    dw msg_center_2
    dw msg_center_3
    dw msg_center_4
    dw msg_center_5
    dw msg_center_6
center_tbl_count equ ($ - center_tbl) / 2

; ---- Relax phrases ----
relax_tbl:
    dw msg_relax_1
    dw msg_relax_2
    dw msg_relax_3
    dw msg_relax_4
relax_tbl_count equ ($ - relax_tbl) / 2

; ---- Strings ----
msg_center_1 db "LOOK AT THE CENTER", 0
msg_center_2 db "CENTER. STILL.", 0
msg_center_3 db "EYES TO THE CENTER.", 0
msg_center_4 db "HOLD THE CENTER POINT.", 0
msg_center_5 db "FOCUS ON THE CENTER.", 0
msg_center_6 db "KEEP YOUR EYES CENTERED.", 0

msg_relax_1  db "RELAX...", 0
msg_relax_2  db "BLINK SOFTLY.", 0
msg_relax_3  db "BREATH IN... OUT...", 0
msg_relax_4  db "REST YOUR EYES.", 0

msg_license  db "Tayo Micro Software. Eyes Trainer 2026", 0

msg_hint     db "ESC - EXIT | TAYO since 2006", 0