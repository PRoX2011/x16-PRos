; ==================================================================
; x16-PRos -- PONG. Pong game.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

PADDLE_SIZE   equ 4
SCREEN_WIDTH  equ 80
SCREEN_HEIGHT equ 25

start:
    pusha

    mov ax, 0x03
    int 0x10

    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    push es
    mov ax, 0xB800
    mov es, ax
    pop es

.loop:
    mov ah, 0x06
    mov al, 0x00
    mov bh, 0x0F
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10

    mov dx, 0x0000
    call move_cursor

    mov ch, [LEFT_PLAYER_POS]
    mov dl, 0
    call draw_paddle
    mov ch, [RIGHT_PLAYER_POS]
    mov dl, 79
    call draw_paddle
    call draw_ball
    call draw_scores
    call draw_center_line

    call handle_input
    call update_paddles
    call update_ball
    call check_goal

    mov ah, 0x86
    mov cx, 0x0000
    mov dx, 0x9870
    int 0x15

    jmp .loop

draw_paddle:
    mov dh, ch
    dec ch
    add dh, PADDLE_SIZE
.loop:
    call move_cursor
    mov al, 0xDB
    call write_char
    dec dh
    cmp dh, ch
    jne .loop
.end:
    ret

draw_ball:
    mov dh, [BALL_Y]
    mov dl, [BALL_X]
    call move_cursor
    mov al, 0xDB
    call write_char
    ret

draw_scores:
    push es
    mov ax, 0xB800
    mov es, ax
    mov bl, [LEFT_SCORE]
    mov di, 36
    call paint_digit
    mov bl, [RIGHT_SCORE]
    mov di, 108
    call paint_digit
    pop es
    ret

draw_center_line:
    mov dh, 0
    mov dl, 40
.loop:
    call move_cursor
    mov al, 0xB3
    call write_char
    add dh, 2
    cmp dh, SCREEN_HEIGHT
    jb .loop
    ret

handle_input:
    mov byte [KEYS_PRESSED], 0
.loop:
    mov ah, 0x01
    int 0x16
    jz .end
.read_key:
    mov ah, 0x00
    int 0x16
    cmp al, 'w'
    je .set_w
    cmp al, 's'
    je .set_s
    cmp al, 27
    je exit
    jmp .loop
.set_w:
    or byte [KEYS_PRESSED], (1 << 0)
    jmp .loop
.set_s:
    or byte [KEYS_PRESSED], (1 << 1)
    jmp .loop
.end:
    ret

update_paddles:
    mov ah, [KEYS_PRESSED]
    and ah, (1 << 0)
    jnz .left_up
.after_left_up:
    mov ah, [KEYS_PRESSED]
    and ah, (1 << 1)
    jnz .left_down
.after_left_down:
    call update_right_paddle_ai
    ret
.left_up:
    cmp byte [LEFT_PLAYER_POS], 0
    je .after_left_up
    dec byte [LEFT_PLAYER_POS]
    jmp .after_left_up
.left_down:
    cmp byte [LEFT_PLAYER_POS], (SCREEN_HEIGHT - PADDLE_SIZE - 1)
    je .after_left_down
    inc byte [LEFT_PLAYER_POS]
    jmp .after_left_down

update_right_paddle_ai:
    mov al, [BALL_Y]
    mov ah, [RIGHT_PLAYER_POS]
    add ah, (PADDLE_SIZE / 2)
    cmp al, ah
    je .end
    jl .move_up
    jg .move_down
.move_up:
    cmp byte [RIGHT_PLAYER_POS], 0
    je .end
    dec byte [RIGHT_PLAYER_POS]
    jmp .end
.move_down:
    cmp byte [RIGHT_PLAYER_POS], (SCREEN_HEIGHT - PADDLE_SIZE - 1)
    je .end
    inc byte [RIGHT_PLAYER_POS]
.end:
    ret

update_ball:
    cmp byte [BALL_Y], 0
    je .flip_dy
    cmp byte [BALL_Y], (SCREEN_HEIGHT - 1)
    je .flip_dy
.after_flip_dy:
    mov ah, [BALL_DX]
    add [BALL_X], ah
    mov ah, [BALL_DY]
    add [BALL_Y], ah
    cmp byte [BALL_X], 1
    je .check_left_paddle
    cmp byte [BALL_X], (SCREEN_WIDTH - 2)
    je .check_right_paddle
.end:
    ret
.flip_dy:
    neg byte [BALL_DY]
    jmp .after_flip_dy
.check_left_paddle:
    mov ah, [LEFT_PLAYER_POS]
    cmp [BALL_Y], ah
    jl .end
    mov ah, [LEFT_PLAYER_POS]
    add ah, PADDLE_SIZE
    cmp [BALL_Y], ah
    jg .end
    neg byte [BALL_DX]
    ret
.check_right_paddle:
    mov ah, [RIGHT_PLAYER_POS]
    cmp [BALL_Y], ah
    jl .end
    mov ah, [RIGHT_PLAYER_POS]
    add ah, PADDLE_SIZE
    cmp [BALL_Y], ah
    jg .end
    neg byte [BALL_DX]
    ret

check_goal:
    cmp byte [BALL_X], 0
    je .right_scores
    cmp byte [BALL_X], (SCREEN_WIDTH - 1)
    je .left_scores
    ret
.right_scores:
    inc byte [RIGHT_SCORE]
    jmp .reset_ball
.left_scores:
    inc byte [LEFT_SCORE]
    jmp .reset_ball
.reset_ball:
    mov byte [BALL_X], (SCREEN_WIDTH / 2)
    mov byte [BALL_Y], (SCREEN_HEIGHT / 2)
    neg byte [BALL_DX]
    neg byte [BALL_DY]
    ret

paint_digit:
    pusha
    movzx dx, byte [pattern+bx]
    xor ax, ax
    bt dx, 6
    jnc .b5
    call bar_horiz
.b5:
    bt dx, 5
    jnc .b4
    call bar_vert
.b4:
    bt dx, 4
    jnc .b3
    push di
    add di, 12
    call bar_vert
    pop di
.b3:
    bt dx, 3
    jnc .b2
    mov al, 4
    call bar_horiz
.b2:
    bt dx, 2
    jnc .b1
    mov al, 4
    call bar_vert
.b1:
    bt dx, 1
    jnc .b0
    mov al, 4
    push di
    add di, 12
    call bar_vert
    pop di
.b0:
    bt dx, 0
    jnc .digdone
    mov ax, 8
    call bar_horiz
.digdone:
    popa
    ret

bar_horiz:
    pusha
    mov bx, 160
    mul bx
    add di, ax
    mov bx, 2
.barh:
    mov cx, 8
    mov ax, [fullchr]
    rep stosw
    add di, 144
    dec bx
    jnz .barh
    popa
    ret

bar_vert:
    pusha
    mov bx, 160
    mul bx
    add di, ax
    mov bx, 6
.barv:
    mov cx, 2
    mov ax, [fullchr]
    rep stosw
    add di, 156
    dec bx
    jnz .barv
    popa
    ret

exit:
    int 0x19

LEFT_PLAYER_POS:  db ((SCREEN_HEIGHT - PADDLE_SIZE) / 2)
RIGHT_PLAYER_POS: db ((SCREEN_HEIGHT - PADDLE_SIZE) / 2)
LEFT_SCORE:       db 0
RIGHT_SCORE:      db 0
BALL_X:           db 40
BALL_Y:           db 12
BALL_DY:          db 1
BALL_DX:          db -1
KEYS_PRESSED:     db 0
pattern           db 01110111b, 00010010b, 01011101b, 01011011b, 0111010b
                  db 01101011b, 01101111b, 01010010b, 01111111b, 01111011b
fullchr:
    chr           db 0xDB
    col           db 0x0F

move_cursor:
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    ret

write_char:
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    ret