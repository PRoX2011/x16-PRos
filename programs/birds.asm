; x16-PRos -- BIRDS, a compact Flappy Birds game
; Watermark: AttackUwu - https://github.com/attackuwu/

[BITS 16]
[ORG 0x8000]

SCREEN_W equ 80
SCREEN_H equ 25
GROUND   equ 23
GAP      equ 7

start:
    mov ax, 0003h
    int 10h
    mov ah, 01h
    mov cx, 2607h
    int 10h

restart:
    mov byte [quit], 0
    mov byte [restart_flag], 0
    mov byte [bird_y], 11
    mov byte [velocity], 0
    mov byte [pipe_x], 70
    mov byte [gap_y], 9
    mov word [score], 0

loop:
    call clear_screen
    call draw_scene
    call input
    cmp byte [quit], 1
    je exit
    cmp byte [restart_flag], 1
    je restart
    call update
    cmp byte [quit], 1
    je exit
    cmp byte [restart_flag], 1
    je restart
    mov cx, 1
    mov dx, 5000h
    mov ah, 86h
    int 15h
    jmp loop

game_over:
    mov si, over_msg
    mov dh, 11
    mov dl, 28
    call print_at
.wait:
    mov ah, 00h
    int 16h
    cmp al, 27
    je .quit
    cmp al, 'r'
    je .restart
    jmp .wait
.quit:
    mov byte [quit], 1
    ret
.restart:
    mov byte [restart_flag], 1
    ret

exit:
    mov ax, 0003h
    int 10h
    ret

input:
    mov ah, 01h
    int 16h
    jz .done
    xor ah, ah
    int 16h
    cmp al, 27
    je .quit
.flap:
    cmp al, ' '
    jne .restart
    mov byte [velocity], -3
    ret
.restart:
    cmp al, 'r'
    jne .done
    mov byte [restart_flag], 1
.done:
    ret
.quit:
    mov byte [quit], 1
    ret

update:
    inc byte [velocity]
    mov al, [bird_y]
    add al, [velocity]
    mov [bird_y], al
    dec byte [pipe_x]
    cmp byte [pipe_x], 7
    ja .check
    mov byte [pipe_x], 70
    inc word [score]
.check:
    cmp byte [bird_y], 1
    jb game_over
    cmp byte [bird_y], GROUND
    jae game_over
    mov al, [pipe_x]
    cmp al, 8
    jne .done
    mov al, [bird_y]
    cmp al, [gap_y]
    jb game_over
    mov bl, [gap_y]
    add bl, GAP
    cmp al, bl
    jae game_over
.done:
    ret

clear_screen:
    mov ax, 0600h
    mov bh, 07h
    xor cx, cx
    mov dx, 184fh
    int 10h
    ret

draw_scene:
    mov si, title_msg
    mov dh, 0
    mov dl, 34
    call print_at
    mov si, score_msg
    mov dh, 0
    mov dl, 45
    call print_at
    mov ax, [score]
    call print_number
    mov si, help_msg
    mov dh, 24
    mov dl, 20
    call print_at
    mov si, bird
    mov dh, [bird_y]
    mov dl, 8
    call print_at
    mov dh, 1
    mov dl, [pipe_x]
.pipe:
    cmp dh, GROUND
    jae .ground
    mov al, [gap_y]
    cmp dh, al
    jb .wall
    add al, GAP
    cmp dh, al
    jb .next
.wall:
    mov si, pipe
    call print_at
.next:
    inc dh
    jmp .pipe
.ground:
    mov dh, GROUND
    xor dl, dl
.ground_loop:
    mov si, ground
    call print_at
    inc dl
    cmp dl, SCREEN_W
    jb .ground_loop
    ret

print_at:
    push ax
    push bx
    push dx
    mov ah, 02h
    xor bh, bh
    int 10h
.next:
    lodsb
    test al, al
    jz .done
    mov ah, 0eh
    int 10h
    jmp .next
.done:
    pop dx
    pop bx
    pop ax
    ret

print_number:
    push ax
    push bx
    push cx
    push dx
    xor cx, cx
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.print:
    pop ax
    add al, '0'
    mov ah, 0eh
    int 10h
    loop .print
    pop dx
    pop cx
    pop bx
    pop ax
    ret

title_msg db 'BIRDS', 0
score_msg db 'SCORE:', 0
help_msg  db 'SPACE flap   R restart   ESC quit', 0
bird      db '@', 0
pipe      db '#', 0
ground    db '_', 0
over_msg  db 'GAME OVER - R restart, ESC quit', 0
bird_y    db 11
velocity  db 0
pipe_x    db 70
gap_y     db 9
quit      db 0
restart_flag db 0
score     dw 0
