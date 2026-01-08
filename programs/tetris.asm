; ==================================================================
; x16-PRos -- TETRIS
; Original design by Alexey Pajitnov
;
; Made by Dexoron and PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

%define BOARD_WIDTH  10
%define BOARD_HEIGHT 20
%define ATTR_GREEN   0x0A ; Light green on black

start:
    call init_video
    call clear_board
    mov word [score], 0
    mov word [lines_cleared], 0
    mov word [level], 1
    call get_random_type
    mov [next_type], al

game_loop:
    ; Clear keyboard buffer to prevent "input lag" from previous piece
.flush_kbd:
    mov ah, 0x01
    int 0x16
    jz .spawn
    mov ah, 0x00
    int 0x16
    jmp .flush_kbd

.spawn:
    call spawn_piece
    
.piece_loop:
    call draw_ui
    call draw_board
    call draw_piece
    
    ; Delay (Adjusted by Level)
    mov cx, 0x0004
    mov dx, 0x93E0
    mov ax, [level]
    dec ax
    jz .do_delay
    mov bx, 0x1000
    mul bx
    sub dx, ax
.do_delay:
    mov ah, 0x86
    int 0x15

    call handle_input
    
    call move_down
    jc .lock_piece      ; If bottom or obstacle hit
    jmp .piece_loop

.lock_piece:
    call lock_to_board
    ; Add score for placing a piece (1 point per block = 4)
    add word [score], 4
    call clear_lines
    call check_game_over
    jc game_over
    jmp game_loop

; --- SUBROUTINES ---

init_video:
    mov ax, 0x0003      ; Text mode 80x25
    int 0x10
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10
    ret

clear_board:
    mov di, board_data
    mov cx, BOARD_WIDTH * BOARD_HEIGHT
    xor al, al
    rep stosb
    ret

get_random_type:
    xor ax, ax
    int 0x1A            ; CX:DX = clock ticks
    mov ax, dx
    xor dx, dx
    mov cx, 7           
    div cx              ; DL = piece type (0-6)
    mov al, dl
    ret

spawn_piece:
    mov al, [next_type]
    mov [current_type], al
    call get_random_type
    mov [next_type], al
    
    mov byte [current_x], 4
    mov byte [current_y], 0
    mov byte [current_rotation], 0
    ret

draw_ui:
    ; Draw glass boundaries (Centered)
    mov dh, 2           
.frame_loop:
    mov dl, 30          
    call set_cursor
    mov si, frame_left
    call print_string   
    
    add dl, 22          
    call set_cursor
    mov si, frame_right
    call print_string   
    
    inc dh
    cmp dh, 23          
    jne .frame_loop
    
    ; Bottom line
    mov dh, 22
    mov dl, 32
    mov cx, BOARD_WIDTH
.bottom_loop:
    call set_cursor
    push cx
    mov si, block_bottom
    call print_string
    pop cx
    add dl, 2
    loop .bottom_loop

    ; Stats Panel - MOVED TO LEFT SIDE (Col 5)
    mov dh, 2
    mov dl, 5
    call set_cursor
    mov si, msg_lines
    call print_string
    mov ax, [lines_cleared]
    call print_number

    mov dh, 3
    mov dl, 5
    call set_cursor
    mov si, msg_level
    call print_string
    mov ax, [level]
    call print_number

    mov dh, 4
    mov dl, 5
    call set_cursor
    mov si, msg_score
    call print_string
    mov ax, [score]
    call print_number

    ; Next Piece - Just draw the preview
    call draw_next_piece_ui
    ret

draw_next_piece_ui:
    ; Clear next piece area (Larger area to handle I-piece)
    mov dh, 9
.clr_y:
    mov dl, 20
    call set_cursor
    mov si, clr_next
    call print_string
    inc dh
    cmp dh, 14          ; Increased height for clearing
    jne .clr_y

    ; Draw next piece blocks
    movzx ax, byte [next_type]
    imul ax, 32         
    mov si, pieces_data
    add si, ax          
    
    mov cx, 4
.next_loop:
    lodsb               ; rel X
    mov dl, al
    shl dl, 1           ; Double width for []
    add dl, 22          ; Positioned right next to board wall (wall is at 30)
    lodsb               ; rel Y
    mov dh, al
    add dh, 10          ; Vertically centered relative to board
    push si
    push cx
    call set_cursor
    mov si, block_char
    call print_string
    pop cx
    pop si
    loop .next_loop
    ret

handle_input:
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    
    cmp al, 'a'
    je .move_left
    cmp al, 'A'
    je .move_left
    cmp al, 'd'
    je .move_right
    cmp al, 'D'
    je .move_right
    cmp al, 'e'
    je .rot_cw
    cmp al, 'E'
    je .rot_cw
    cmp al, 'q'
    je .rot_ccw
    cmp al, 'Q'
    je .rot_ccw
    cmp al, 's'
    je .move_down_fast
    cmp al, 'S'
    je .move_down_fast
    cmp al, 0x1B
    je .exit
    ret

.exit:
    int 0x20

.move_down_fast:
    call move_down
    ret

.move_left:
    dec byte [current_x]
    call check_total_collision
    jz .ok_l
    inc byte [current_x]
.ok_l: ret

.move_right:
    inc byte [current_x]
    call check_total_collision
    jz .ok_r
    dec byte [current_x]
.ok_r: ret

.rot_cw:
    mov al, [current_rotation]
    push ax
    inc al
    and al, 3
    mov [current_rotation], al
    call check_total_collision
    jz .rot_done
    pop ax
    mov [current_rotation], al
    ret
.rot_ccw:
    mov al, [current_rotation]
    push ax
    dec al
    and al, 3
    mov [current_rotation], al
    call check_total_collision
    jz .rot_done
    pop ax
    mov [current_rotation], al
    ret
.rot_done:
    pop ax
    ret
.no_key:
    ret

check_total_collision:
    mov cx, 4
    movzx ax, byte [current_type]
    imul ax, 32
    movzx bx, byte [current_rotation]
    shl bx, 3           
    add ax, bx
    mov si, pieces_data
    add si, ax
.c_loop:
    lodsb
    add al, [current_x]
    mov bl, al          
    lodsb
    add al, [current_y]
    mov bh, al          
    
    cmp bl, 0
    jl .fail
    cmp bl, BOARD_WIDTH - 1
    jg .fail
    cmp bh, BOARD_HEIGHT - 1
    jg .fail
    
    push dx
    movzx ax, bh
    mov dl, BOARD_WIDTH
    mul dl
    movzx dx, bl
    add ax, dx
    mov di, ax
    add di, board_data
    mov al, [di]
    pop dx
    or al, al
    jnz .fail
    loop .c_loop
    xor ax, ax          ; Z=1 (No collision)
    ret
.fail:
    or ax, 1            ; Z=0 (Collision)
    ret

draw_board:
    mov dh, 2
    xor ch, ch          
.y_loop:
    mov dl, 32
    xor cl, cl          
.x_loop:
    call set_cursor
    push dx
    push cx
    movzx ax, ch
    mov bl, BOARD_WIDTH
    mul bl
    movzx bx, cl
    add ax, bx
    mov si, ax
    add si, board_data
    mov al, [si]
    or al, al
    jnz .draw_solid
    mov si, empty_char  
    jmp .do_print
.draw_solid:
    mov si, block_char  
.do_print:
    call print_string
    pop cx
    pop dx
    inc cl
    add dl, 2
    cmp cl, BOARD_WIDTH
    jne .x_loop
    inc ch
    inc dh
    cmp ch, BOARD_HEIGHT
    jne .y_loop
    ret

draw_piece:
    movzx ax, byte [current_type]
    imul ax, 32
    movzx bx, byte [current_rotation]
    shl bx, 3
    add ax, bx
    mov si, pieces_data
    add si, ax
    mov cx, 4
.draw_loop:
    lodsb
    add al, [current_x]
    mov dl, al
    shl dl, 1
    add dl, 32
    lodsb
    add al, [current_y]
    mov dh, al
    add dh, 2
    push si
    push cx
    call set_cursor
    mov si, block_char
    call print_string
    pop cx
    pop si
    loop .draw_loop
    ret

move_down:
    inc byte [current_y]
    call check_total_collision
    jz .ok
    dec byte [current_y]
    stc
    ret
.ok:
    clc
    ret

lock_to_board:
    mov cx, 4
    movzx ax, byte [current_type]
    imul ax, 32
    movzx bx, byte [current_rotation]
    shl bx, 3
    add ax, bx
    mov si, pieces_data
    add si, ax
.lock_loop:
    lodsb
    add al, [current_x]
    mov bl, al
    lodsb
    add al, [current_y]
    mov bh, al
    movzx ax, bh
    mov dl, BOARD_WIDTH
    mul dl
    movzx dx, bl
    add ax, dx
    mov di, ax
    add di, board_data
    mov byte [di], 1
    loop .lock_loop
    ret

clear_lines:
    mov ch, BOARD_HEIGHT - 1 
.row_loop:
    mov cl, 0
.col_loop:
    movzx ax, ch
    mov bl, BOARD_WIDTH
    mul bl
    movzx bx, cl
    add ax, bx
    mov si, ax
    add si, board_data
    cmp byte [si], 0
    je .next_row 
    inc cl
    cmp cl, BOARD_WIDTH
    jne .col_loop
    call remove_line
    
    ; Update stats
    add word [lines_cleared], 1
    add word [score], 100
    
    ; Check Level Up (Every 10 lines)
    mov ax, [lines_cleared]
    xor dx, dx
    mov bx, 10
    div bx
    or dx, dx
    jnz .no_level_up
    inc word [level]
.no_level_up:
    jmp .row_loop 
.next_row:
    dec ch
    cmp ch, 0xFF
    jne .row_loop
    ret

remove_line:
    pusha
.shift_down:
    cmp ch, 0
    je .top_row
    mov cl, 0
.shift_cols:
    movzx ax, ch
    dec al          
    mov bl, BOARD_WIDTH
    mul bl
    movzx bx, cl
    add ax, bx
    mov si, ax
    add si, board_data
    mov al, [si]    
    movzx dx, ch
    mov bl, BOARD_WIDTH
    imul dx, bx
    movzx bx, cl
    add dx, bx
    mov di, dx
    add di, board_data
    mov [di], al    
    inc cl
    cmp cl, BOARD_WIDTH
    jne .shift_cols
    dec ch
    jmp .shift_down
.top_row:
    mov di, board_data
    mov cx, BOARD_WIDTH
    xor al, al
    rep stosb
    popa
    ret

check_game_over:
    mov di, board_data
    mov cx, BOARD_WIDTH
.check_loop:
    cmp byte [di], 0
    jne .over
    inc di
    loop .check_loop
    clc
    ret
.over:
    stc
    ret

set_cursor:
    mov ah, 0x0F
    int 0x23
    ret

print_string:
    mov ah, 0x01
    mov bl, ATTR_GREEN
    int 0x21
    ret

print_number:
    pusha
    mov bx, 10
    xor cx, cx
.push_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .push_digits
.pop_digits:
    pop dx
    add dl, '0'
    mov [char_buf], dl
    mov si, char_buf
    call print_string
    loop .pop_digits
    popa
    ret

game_over:
    mov dh, 12
    mov dl, 35
    call set_cursor
    mov si, msg_game_over
    call print_string
    jmp $

; --- DATA ---

board_data:   times BOARD_WIDTH * BOARD_HEIGHT db 0
current_x:    db 0
current_y:    db 0
current_type: db 0
current_rotation: db 0
next_type:    db 0
score:        dw 0
lines_cleared: dw 0
level:        dw 1
char_buf:     db 0, 0

pieces_data:
    ; I-piece (Type 0)
    db 0,1, 1,1, 2,1, 3,1,  1,0, 1,1, 1,2, 1,3,  0,1, 1,1, 2,1, 3,1,  1,0, 1,1, 1,2, 1,3
    ; J-piece (Type 1)
    db 0,0, 0,1, 1,1, 2,1,  1,0, 2,0, 1,1, 1,2,  0,1, 1,1, 2,1, 2,2,  1,0, 1,1, 0,2, 1,2
    ; L-piece (Type 2)
    db 2,0, 0,1, 1,1, 2,1,  1,0, 1,1, 1,2, 2,2,  0,1, 1,1, 2,1, 0,2,  0,0, 1,0, 1,1, 1,2
    ; O-piece (Type 3)
    db 0,0, 1,0, 0,1, 1,1,  0,0, 1,0, 0,1, 1,1,  0,0, 1,0, 0,1, 1,1,  0,0, 1,0, 0,1, 1,1
    ; S-piece (Type 4)
    db 1,0, 2,0, 0,1, 1,1,  1,0, 1,1, 2,1, 2,2,  1,0, 2,0, 0,1, 1,1,  1,0, 1,1, 2,1, 2,2
    ; T-piece (Type 5)
    db 1,0, 0,1, 1,1, 2,1,  1,0, 1,1, 2,1, 1,2,  0,1, 1,1, 2,1, 1,2,  1,0, 0,1, 1,1, 1,2
    ; Z-piece (Type 6)
    db 0,0, 1,0, 1,1, 2,1,  2,0, 1,1, 2,1, 1,2,  0,0, 1,0, 1,1, 2,1,  2,0, 1,1, 2,1, 1,2

msg_lines:     db "LINES: ", 0
msg_level:     db "LEVEL: ", 0
msg_score:     db "SCORE: ", 0
msg_next:      db "NEXT:", 0
clr_next:      db "          ", 0 ;
msg_game_over: db "GAME OVER", 0
frame_left:    db "<|", 0
frame_right:   db "|>", 0
footer_start:  db "  ", 0
frame_footer_char: db "\/", 0
block_char:    db "[]", 0
empty_char:    db " .", 0
block_bottom:  db "==", 0