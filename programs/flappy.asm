; ==================================================================
; x16-PRos -- FLAPPY BIRD
; Flappy Bird clone for 16-bit retro system
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

%define SCREEN_WIDTH  80
%define SCREEN_HEIGHT 25
%define GRAVITY       1
%define FLAP_POWER    3
%define PIPE_WIDTH    2
%define PIPE_GAP      7
%define PIPE_SPEED    1
%define MAX_PIPES     3

start:
    pusha
    
    ; Initialize video mode
    mov ax, 0x03
    int 0x10
    
    ; Hide cursor
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10
    
    ; Initialize game state
    mov byte [bird_y], (SCREEN_HEIGHT / 2)
    mov byte [bird_vel], 0
    mov byte [score], 0
    mov byte [game_over], 0
    mov byte [pipe_count], 0
    
    ; Initialize pipes
    mov cx, MAX_PIPES
    mov di, pipes_data
.init_pipes:
    mov ax, SCREEN_WIDTH
    sub ax, 10
    mov bx, cx
    imul bx, 25
    add ax, bx
    mov [di], al
    inc di
    mov al, (SCREEN_HEIGHT / 2)
    sub al, (PIPE_GAP / 2)
    mov [di], al
    inc di
    loop .init_pipes
    
.game_loop:
    ; Clear screen
    mov ah, 0x06
    mov al, 0x00
    mov bh, 0x0F
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    ; Draw UI
    call draw_score
    call draw_bird
    call draw_all_pipes
    call draw_ground
    
    ; Handle input
    call handle_input
    
    ; Update game state
    call update_physics
    call update_pipes
    call check_collisions
    
    ; Check game over
    cmp byte [game_over], 1
    je .game_over_screen
    
    ; Delay for frame rate
    mov ah, 0x86
    mov cx, 0x0000
    mov dx, 0x186A  ; ~60 FPS
    int 0x15
    
    jmp .game_loop
    
.game_over_screen:
    ; Draw game over text
    mov dx, 0x0C28  ; Row 12, Col 40
    call move_cursor
    mov si, msg_game_over
    call print_string
    
    mov dx, 0x0E28
    call move_cursor
    mov si, msg_score_text
    call print_string
    
    mov dx, 0x1028
    call move_cursor
    mov si, msg_restart
    call print_string
    
.wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, 'n'
    je start
    cmp al, 'N'
    je start
    cmp al, 27
    je exit
    jmp .wait_key

; ==================================================================
; SUBROUTINES
; ==================================================================

draw_bird:
    mov dh, [bird_y]
    mov dl, 10
    call move_cursor
    mov al, 0x02  ; Smiley face
    call write_char
    ret

draw_all_pipes:
    mov cx, MAX_PIPES
    mov si, pipes_data
.draw_loop:
    push cx
    mov dl, [si]
    mov dh, 0
    call move_cursor
    mov dh, [si+1]
    call draw_single_pipe
    add si, 2
    pop cx
    loop .draw_loop
    ret

draw_single_pipe:
    push dx
    push cx
    
    ; Draw top pipe
    mov ch, 0
.top_loop:
    cmp ch, dh
    jae .draw_gap_pipe
    mov al, 0xDB
    call write_char
    inc ch
    jmp .top_loop
    
.draw_gap_pipe:
    ; Draw gap
    mov cx, PIPE_GAP
.gap_loop_pipe:
    mov al, ' '
    call write_char
    loop .gap_loop_pipe
    
    ; Draw bottom pipe
    mov ch, dh
    add ch, PIPE_GAP
.bottom_loop:
    cmp ch, SCREEN_HEIGHT - 1
    ja .done_pipe
    mov al, 0xDB
    call write_cursor_next
    inc ch
    jmp .bottom_loop
    
.done_pipe:
    pop cx
    pop dx
    ret

draw_ground:
    mov dh, SCREEN_HEIGHT - 1
    mov dl, 0
    call move_cursor
    mov cx, SCREEN_WIDTH
.ground_loop:
    mov al, 0xDC  ; Ground character
    call write_char
    loop .ground_loop
    ret

draw_score:
    mov dx, 0x0000
    call move_cursor
    mov si, msg_score_prefix
    call print_string
    
    mov al, [score]
    add al, '0'
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    ret

handle_input:
    mov ah, 0x01
    int 0x16
    jz .no_key
    
    mov ah, 0x00
    int 0x16
    
    cmp al, ' '
    je .flap
    cmp al, 27
    je exit
    
.no_key:
    ret
    
.flap:
    mov byte [bird_vel], -FLAP_POWER
    ret

update_physics:
    ; Apply gravity
    mov al, [bird_vel]
    add al, GRAVITY
    mov [bird_vel], al
    
    ; Update bird position
    mov al, [bird_y]
    add al, [bird_vel]
    mov [bird_y], al
    
    ret

update_pipes:
    mov cx, MAX_PIPES
    mov si, pipes_data
.update_loop:
    mov al, [si]
    sub al, PIPE_SPEED
    mov [si], al
    
    ; Check if pipe passed bird
    cmp byte [si], 8
    jne .no_score
    inc byte [score]
    
.no_score:
    ; Respawn pipe if off screen
    cmp byte [si], 0
    jg .next_pipe
    mov byte [si], SCREEN_WIDTH - 1
    
    ; Randomize gap position
    xor ax, ax
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, (SCREEN_HEIGHT - PIPE_GAP - 4)
    div bx
    add dl, 2
    mov [si+1], dl
    
.next_pipe:
    add si, 2
    loop .update_loop
    ret

check_collisions:
    ; Check ground collision
    mov al, [bird_y]
    cmp al, SCREEN_HEIGHT - 2
    jae .collision
    
    ; Check ceiling
    cmp al, 0
    jle .collision
    
    ; Check pipe collision
    mov cx, MAX_PIPES
    mov si, pipes_data
.check_loop:
    mov al, [bird_x]
    mov ah, [si]
    cmp al, ah
    jne .next_check
    
    ; Bird is at pipe X, check Y
    mov al, [bird_y]
    mov ah, [si+1]
    cmp al, ah
    jb .collision
    add ah, PIPE_GAP
    cmp al, ah
    ja .collision
    
.next_check:
    add si, 2
    loop .check_loop
    
.no_collision:
    ret
    
.collision:
    mov byte [game_over], 1
    ret

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

write_cursor_next:
    push dx
    inc dl
    call move_cursor
    pop dx
    jmp write_char

print_string:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    jmp .loop
.done:
    popa
    ret

exit:
    popa
    ret

; ==================================================================
; DATA
; ==================================================================

bird_y:          db (SCREEN_HEIGHT / 2)
bird_vel:        db 0
bird_x:          db 10
pipe_count:      db 0
pipes_data:      times MAX_PIPES * 2 db 0
score:           db 0
game_over:       db 0

msg_score_prefix: db "Score: ", 0
msg_game_over:    db "GAME OVER", 0
msg_score_text:   db "Score: ", 0
msg_restart:      db "Press N for new game, ESC to quit", 0