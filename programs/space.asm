; ==================================================================
; x16-PRos -- SPACE. Space arcade game.
;
; Made by Qwez-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

; --- Constants ---
SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25
GAME_WIDTH      equ 30
GAME_HEIGHT     equ 18
GAME_LEFT       equ 25
GAME_TOP        equ 3
PLAYER_CHAR     equ 0xDB
ASTEROID_CHAR   equ 0xB1
MAX_ASTEROIDS   equ 10
ASTEROID_SPEED  equ 2      ; Lower is faster (updates every N ticks)
VIDEO_MEM       equ 0xB800

section .data
    ; Player coordinates
    player_x        dw 50
    player_y        dw 18
    player_x_old    dw 50
    player_y_old    dw 18

    ; Asteroid data arrays
    asteroid_x      times MAX_ASTEROIDS dw 0
    asteroid_y      times MAX_ASTEROIDS dw 0
    asteroid_x_old  times MAX_ASTEROIDS dw 0
    asteroid_y_old  times MAX_ASTEROIDS dw 0
    asteroid_active times MAX_ASTEROIDS db 0

    ; Game state variables
    score           dw 0
    score_old       dw 0xFFFF ; Initialized to a value that guarantees first score draw
    game_over       db 0
    random_seed     dw 1234
    tick_counter    db 0
    first_draw      db 1
    exit_flag       db 0    ; Flag to signal exit

    ; Message strings
    title_msg       db 'SPACE ARCADE', 0
    score_msg       db 'Score: ', 0
    game_over_msg   db 'GAME OVER! Press any key to quit', 0
    author_msg      db 'By: Qwez', 0
    controls_msg    db 'ESC - quit, Arrows - move', 0

section .text
start:
    pusha

    ; Set 80x25 text mode
    mov ax, 0x0003
    int 0x10

    ; Disable cursor
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    ; Set ES to video memory segment
    mov ax, VIDEO_MEM
    mov es, ax

    ; Initialize random number generator with system time
    xor ax, ax
    int 0x1A
    mov [random_seed], dx

    ; Set player's initial position
    mov ax, GAME_LEFT
    add ax, GAME_WIDTH/2
    mov [player_x], ax
    mov [player_x_old], ax

    mov ax, GAME_TOP
    add ax, GAME_HEIGHT-2
    mov [player_y], ax
    mov [player_y_old], ax

    call init_asteroids
    call draw_static_elements
    call draw_player   ; Draw the player immediately at start

; Main game loop
game_loop:
    cmp byte [exit_flag], 1
    je .exit_game

    cmp byte [game_over], 1
    je game_over_screen

    mov cx, 2
    call delay

    call check_keyboard

    ; Update game state based on tick counter (for asteroid speed)
    inc byte [tick_counter]
    cmp byte [tick_counter], ASTEROID_SPEED
    jl .skip_asteroid_update

    mov byte [tick_counter], 0
    call update_asteroids
    call check_collisions

.skip_asteroid_update:
    call update_screen
    jmp game_loop

.exit_game:
    ; Restore video mode on exit
    mov ax, 0x12
    int 0x10
    ret

game_over_screen:
    ; Switch back to standard text mode
    mov ax, 0x0003
    int 0x10

    ; Set cursor position for "GAME OVER" message
    mov dh, 12
    mov dl, 22
    call set_cursor

    ; Print message with color
    mov si, game_over_msg
    mov bl, 0x0C    ; Red on black
    call print_string_color

    ; Set cursor for score
    mov dh, 14
    mov dl, 34
    call set_cursor

    ; Print final score
    mov si, score_msg
    call print_string
    mov ax, [score]
    call print_number

    ; Wait for any key press
    mov ah, 0x00
    int 0x16

    ; Set the exit flag to terminate the game loop
    mov byte [exit_flag], 1
    jmp game_loop

init_asteroids:
    ; Deactivate all asteroids
    mov di, asteroid_active
    mov cx, MAX_ASTEROIDS
    xor al, al
    rep stosb

    ; Zero out old coordinates
    mov cx, MAX_ASTEROIDS
    xor di, di
.init_loop:
    mov word [asteroid_x_old + di], 0
    mov word [asteroid_y_old + di], 0
    add di, 2
    loop .init_loop
    ret

check_keyboard:
    ; Check for key press without waiting
    mov ah, 0x01
    int 0x16
    jz .no_key

    ; Get the key from buffer
    mov ah, 0x00
    int 0x16

    cmp ah, 0x4B        ; Left arrow
    je .move_left
    cmp ah, 0x4D        ; Right arrow
    je .move_right
    cmp ah, 0x48        ; Up arrow
    je .move_up
    cmp ah, 0x50        ; Down arrow
    je .move_down
    cmp al, 0x1B        ; ESC
    je .escape_pressed
    jmp .done

.escape_pressed:
    mov byte [exit_flag], 1
    jmp .done

.move_left:
    mov ax, [player_x]
    cmp ax, GAME_LEFT+1
    jle .clear_buffer
    call erase_player
    mov [player_x_old], ax
    dec word [player_x]
    jmp .redraw

.move_right:
    mov ax, [player_x]
    cmp ax, GAME_LEFT+GAME_WIDTH-2
    jge .clear_buffer
    call erase_player
    mov [player_x_old], ax
    inc word [player_x]
    jmp .redraw

.move_up:
    mov ax, [player_y]
    cmp ax, GAME_TOP+1
    jle .clear_buffer
    call erase_player
    mov ax, [player_y]
    mov [player_y_old], ax
    dec word [player_y]
    jmp .redraw

.move_down:
    mov ax, [player_y]
    cmp ax, GAME_TOP+GAME_HEIGHT-2
    jge .clear_buffer
    call erase_player
    mov ax, [player_y]
    mov [player_y_old], ax
    inc word [player_y]
    jmp .redraw

.clear_buffer:
    ; Clear keyboard buffer if movement is not possible
.clear_loop:
    mov ah, 0x01
    int 0x16
    jz .done
    mov ah, 0x00
    int 0x16
    jmp .clear_loop

.redraw:
    call draw_player
    ; Clear keyboard buffer after movement
.clear_after_move:
    mov ah, 0x01
    int 0x16
    jz .done
    mov ah, 0x00
    int 0x16
    jmp .clear_after_move

.done:
.no_key:
    ret

draw_player:
    pusha

    ; Calculate video memory offset: (y * 160) + (x * 2)
    mov ax, [player_y]
    mov bx, 160
    mul bx
    mov bx, [player_x]
    shl bx, 1
    add ax, bx
    mov di, ax
    ; Write character (PLAYER_CHAR) with attribute (0x0A = Green)
    mov ax, 0x0A00 | PLAYER_CHAR
    stosw

    popa
    ret

erase_player:
    pusha

    ; Calculate video memory offset
    mov ax, [player_y]
    mov bx, 160
    mul bx
    mov bx, [player_x]
    shl bx, 1
    add ax, bx
    mov di, ax
    ; Write a space character with default attribute (0x07)
    mov ax, 0x0720
    stosw

    popa
    ret

update_asteroids:
    ; Use a random chance to spawn a new asteroid
    call random
    and ax, 0x0F
    cmp ax, 2
    jg .update_existing

    ; Find an inactive asteroid slot
    mov cx, MAX_ASTEROIDS
    mov di, 0
.find_inactive:
    cmp byte [asteroid_active + di], 0
    je .spawn_asteroid
    inc di
    loop .find_inactive
    jmp .update_existing

.spawn_asteroid:
    ; Activate the asteroid
    mov byte [asteroid_active + di], 1

    ; Generate a random X position within the game borders
    call random
    xor dx, dx
    mov cx, GAME_WIDTH-2
    div cx
    add dx, GAME_LEFT+1

    mov si, di
    shl si, 1
    mov [asteroid_x + si], dx
    mov [asteroid_x_old + si], dx

    ; Set initial Y position at the top of the game area
    mov word [asteroid_y + si], GAME_TOP+1
    mov word [asteroid_y_old + si], GAME_TOP+1

.update_existing:
    ; Move all active asteroids down by one
    mov cx, MAX_ASTEROIDS
    mov di, 0
.move_loop:
    cmp byte [asteroid_active + di], 0
    je .next_asteroid

    mov si, di
    shl si, 1

    ; Save current Y as old Y and increment current Y
    mov ax, [asteroid_y + si]
    mov [asteroid_y_old + si], ax
    inc word [asteroid_y + si]

    ; Check if asteroid is off the bottom of the screen
    mov ax, [asteroid_y + si]
    cmp ax, GAME_TOP+GAME_HEIGHT-1
    jl .next_asteroid

    ; Erase the asteroid from its last visible position before deactivating it
    push ax
    push bx
    push di

    mov ax, [asteroid_y_old + si]
    mov bx, 160
    mul bx
    mov bx, [asteroid_x + si]
    shl bx, 1
    add ax, bx
    mov di, ax
    mov ax, 0x0720
    stosw

    pop di
    pop bx
    pop ax

    ; Deactivate the asteroid and increment score
    mov byte [asteroid_active + di], 0
    inc word [score]

.next_asteroid:
    inc di
    cmp di, MAX_ASTEROIDS
    jl .move_loop
    ret

check_collisions:
    mov cx, MAX_ASTEROIDS
    mov di, 0
.check_loop:
    ; Skip inactive asteroids
    cmp byte [asteroid_active + di], 0
    je .next_collision_check

    mov si, di
    shl si, 1
    mov ax, [asteroid_x + si]
    mov dx, [asteroid_y + si]

    ; If X and Y coordinates match the player's, it's a collision
    cmp ax, [player_x]
    jne .next_collision_check
    cmp dx, [player_y]
    jne .next_collision_check

    ; Game over
    mov byte [game_over], 1
    ret

.next_collision_check:
    inc di
    cmp di, MAX_ASTEROIDS
    jl .check_loop
    ret

draw_static_elements:
    ; Clear the screen
    xor di, di
    mov cx, 2000
    mov ax, 0x0720 ; Space character, gray on black
    rep stosw

    ; Draw the title (with top margin, centered)
    mov di, 1*160 + 34*2    ; Row 1, Col 34
    mov si, title_msg
    mov ah, 0x0E ; Yellow on black
    call draw_string_video

    ; Draw the score label
    mov di, 2*160 + 36*2    ; Row 2, Col 36
    mov si, score_msg
    mov ah, 0x0A ; Green on black
    call draw_string_video

    ; Draw author string with a left margin
    mov di, 23*160 + 5*2    ; Row 23, Col 5
    mov si, author_msg
    mov ah, 0x0B ; Cyan on black
    call draw_string_video

    ; Draw controls string with a right margin
    mov di, 23*160 + 48*2   ; Row 23, Col 48
    mov si, controls_msg
    mov ah, 0x0F ; White on black
    call draw_string_video

    ; Draw the game borders
    call draw_game_border

    mov byte [first_draw], 0
    ret

update_screen:
    ; Update score display if it has changed
    mov ax, [score]
    cmp ax, [score_old]
    je .skip_score

    mov [score_old], ax
    mov di, 2*160 + 43*2 ; Position for the score number
    call draw_number_video

.skip_score:
    ; Update asteroids on screen
    mov cx, MAX_ASTEROIDS
    xor si, si
.asteroid_loop:
    cmp byte [asteroid_active + si], 0
    je .next_asteroid_update

    mov bx, si
    shl bx, 1

    ; Erase old asteroid position
    mov ax, [asteroid_y_old + bx]
    push bx
    mov bx, 160
    mul bx
    pop bx
    push bx
    mov bx, [asteroid_x_old + bx]
    shl bx, 1
    add ax, bx
    mov di, ax
    mov ax, 0x0720 ; Space character
    stosw
    pop bx

    ; Draw asteroid in new position
    mov ax, [asteroid_y + bx]
    push bx
    mov bx, 160
    mul bx
    pop bx
    push bx
    mov bx, [asteroid_x + bx]
    shl bx, 1
    add ax, bx
    mov di, ax
    mov ax, 0x0C00 | ASTEROID_CHAR ; Red on black
    stosw
    pop bx

    ; Update old coords for the next frame's erase operation
    mov ax, [asteroid_x + bx]
    mov [asteroid_x_old + bx], ax
    mov ax, [asteroid_y + bx]
    mov [asteroid_y_old + bx], ax

.next_asteroid_update:
    inc si
    loop .asteroid_loop

    ; Update player's old coordinates for the next frame
    mov ax, [player_x]
    mov [player_x_old], ax
    mov ax, [player_y]
    mov [player_y_old], ax

    ret

draw_game_border:
    ; Top border
    mov di, GAME_TOP*160 + GAME_LEFT*2
    mov cx, GAME_WIDTH
    mov ax, 0x0B3D ; Character with cyan attribute
.top_loop:
    stosw
    loop .top_loop

    ; Bottom border
    mov di, (GAME_TOP+GAME_HEIGHT)*160 + GAME_LEFT*2
    mov cx, GAME_WIDTH
    mov ax, 0x0B3D
.bottom_loop:
    stosw
    loop .bottom_loop

    ; Side borders
    mov cx, GAME_HEIGHT-1
    mov di, (GAME_TOP+1)*160 + GAME_LEFT*2
.side_loop:
    mov ax, 0x0BBA
    stosw
    add di, (GAME_WIDTH-2)*2
    mov ax, 0x0BBA
    stosw
    add di, 160 - GAME_WIDTH*2
    loop .side_loop

    ret

; --- Utility Functions ---

; Draws a null-terminated string directly to video memory
; Input: SI = string address, DI = video memory offset, AH = attribute
draw_string_video:
.loop:
    lodsb
    or al, al
    jz .done
    stosw
    jmp .loop
.done:
    ret

; Converts a number in AX to a string and draws it to video memory
; Input: AX = number, DI = video memory offset
draw_number_video:
    pusha

    mov bx, 10
    mov cx, 0

    test ax, ax
    jnz .divide_loop
    mov al, '0'
    mov ah, 0x0A ; Green attribute
    stosw
    jmp .done_draw_num

.divide_loop:
    test ax, ax
    jz .print_digits

    xor dx, dx
    div bx

    push dx
    inc cx
    jmp .divide_loop

.print_digits:
    test cx, cx
    jz .done_draw_num

    pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0A ; Green attribute
    stosw

    dec cx
    jmp .print_digits

.done_draw_num:
    popa
    ret

; Sets the cursor position using BIOS
; Input: DH = row, DL = column
set_cursor:
    mov bh, 0 ; Page 0
    mov ah, 0x02
    int 0x10
    ret

; Prints a null-terminated string using BIOS with color
; Input: SI = string, BL = attribute
print_string_color:
    mov ah, 0x09 ; Write character and attribute
    mov bh, 0    ; Page 0
    mov cx, 1    ; Number of characters to write
.loop_psc:
    lodsb
    cmp al, 0
    je .done_psc

    int 0x10

    inc dl
    call set_cursor

    mov ah, 0x09
    jmp .loop_psc
.done_psc:
    ret

; Prints a null-terminated string using BIOS teletype
; Input: SI = string
print_string:
    mov ah, 0x0E ; Teletype output
    mov bh, 0    ; Page 0
.loop_ps:
    lodsb
    cmp al, 0
    je .done_ps
    int 0x10
    jmp .loop_ps
.done_ps:
    ret

; Prints a number in AX to the screen using BIOS teletype
; Input: AX = number
print_number:
    pusha

    mov bx, 10
    mov cx, 0

    test ax, ax
    jnz .divide_loop_pn
    mov al, '0'
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .done_pn

.divide_loop_pn:
    test ax, ax
    jz .print_digits_pn

    xor dx, dx
    div bx

    push dx
    inc cx
    jmp .divide_loop_pn

.print_digits_pn:
    test cx, cx
    jz .done_pn

    pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    dec cx
    jmp .print_digits_pn

.done_pn:
    popa
    ret

; Simple Linear Congruential Generator for pseudo-random numbers
; Output: AX = random number
random:
    push dx
    mov ax, [random_seed]
    mov dx, 8405h
    mul dx
    add ax, 1
    mov [random_seed], ax
    pop dx
    ret

; Simple delay loop using the system timer
; Input: CX = number of timer ticks to wait
delay:
    push ax
    push cx
    push dx
.delay_loop:
    push cx
    mov ah, 0x00
    int 0x1A
    mov bx, dx
.wait_loop:
    mov ah, 0x00
    int 0x1A
    cmp dx, bx
    je .wait_loop
    pop cx
    loop .delay_loop
    pop dx
    pop cx
    pop ax
    ret
