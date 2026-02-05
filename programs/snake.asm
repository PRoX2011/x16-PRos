; ==================================================================
; x16-PRos -- SNAKE. Simple snake game.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
init:
    mov di, clockticks
    stosd
    stosd
    mov ax, (160*25)/2
    stosw
    add al, 4
    stosw
    add al, 4
    stosw
    mov al, 0xFF
    out 0x60, al
    in al, 0x61
    and al, 0xFC
    out 0x61, al

screen:
    mov ax, 0xB800
    mov es, ax
    mov ax, 3
    int 0x10
    inc ah
    mov cx, 0x2000
    int 0x10
    xor di, di
    mov cx, (160*25)/2
    mov ax, 0x0E20
    pusha
    rep stosw

.messages:
    mov di, (160*3)+42
    mov si, msg_name
    call print
    mov si, msg_score
    mov di, (160*3)+94
    call print
    mov si, msg_controls
    mov di, (160*21)+40
    call print

.rect:
    mov ax, 0x02FE
    mov cx, 38
    mov di, (160*4)+40
    rep stosw
    mov cx, 16
.rect_loop:
    stosw
    pusha
    mov cx, 41
    xor ah, ah
    rep stosw
    mov ah, 2
    stosw
    popa
    add di, 158
    loop .rect_loop
    mov cx, 38
    mov di, (160*20)+42
    rep stosw

game:
.setup:
    popa
    mov di, cx
    mov si, init_snake
    call print
    mov bp, 6
    call place_food

.delay:
    xor eax, eax
    int 0x1A
    mov ax, cx
    shl eax, 16
    mov ax, dx
    mov ebx, eax
    sub eax, [clockticks]
    cmp eax, 3
    jl .delay
    mov [clockticks], ebx
    in al, 0x60

.direction:
    cmp al, 177     ; 'N' - новая игра
    je start
    cmp al, 0x01    ; ESC - выход
    je esc_exit
    and al, 0x7F
    cmp al, 17      ; W
    je .up
    cmp al, 30      ; A
    je .left
    cmp al, 31      ; S
    je .down
    cmp al, 32      ; D
    jne .delay

.right:
    mov al, '>'
    add di, 4
    jmp .move

.up:
    mov al, '^'
    sub di, 160
    jmp .move

.down:
    mov al, 'v'
    add di, 160
    jmp .move

.left:
    mov al, '<'
    sub di, 4

.move:
    cmp byte [es:di], 'o'
    sete ah
    je .nofail
    cmp byte [es:di], ' '
    jne .fail

.nofail:
    stosb
    dec di
    pusha
    push es
    push ds
    pop es
    mov cx, bp
    inc cx
    mov si, snake
    add si, bp
    mov di, si
    inc di
    inc di
    std
    rep movsb
    cld
    pop es
    popa
    push di
    mov [snake], di
    mov di, [snake+2]
    mov al, '*'
    stosb
    cmp ah, 1
    je .food
    mov di, [snake+bp]
    mov al, ' '
    stosb
    jmp .done

.food:
    inc bp
    inc bp
    mov di, (160*3)+114
    add word [score], 4
    mov ax, [score]
    mov bl, 10
.printscore_loop:
    div bl
    xchg al, ah
    add al, '0'
    stosb
    dec di
    dec di
    dec di
    mov al, ah
    xor ah, ah
    or al, al
    jnz .printscore_loop
    call place_food
.done:
    pop di
    jmp .delay

.fail:
    mov di, (160*19)+92
    mov si, msg_fail
    call print
.fail_wait:
    in al, 0x60
    cmp al, 177     ; 'N' - новая игра
    jne .check_esc_fail
    jmp start
.check_esc_fail:
    cmp al, 0x01    ; ESC - выход
    jne .fail_wait
    jmp esc_exit

place_food:
    pusha
.seed:
    xor eax, eax
    xor bl, bl
    int 0x1A
.random:
    cmp bl, 5
    jg .seed
    mov ax, dx
    mov cx, 75
    mul cx
    movzx edx, dx
    mov ecx, 65537
    div ecx
    mov ax, dx
    shr edx, 16
    mov ecx, (160*20)
    div cx
    and dl, 0xFC
    inc bl
    cmp dx, (160*5)
    jl .random
    mov di, dx
    cmp byte [es:di], 0x20
    jne .random
    mov al, 'o'
    stosb
    popa
    ret

print:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    stosb
    inc di
    jmp .loop
.done:
    popa
    ret

esc_exit:
    int 0x19

msg_name: db 'Snake game',0
msg_controls: db 'WASD - direction N - new Game ESC - quit',0
msg_fail: db 'You lost =(',0
msg_score: db 'Score:',0
init_snake: db '< * *',0

section .bss
clockticks: resd 1
score: resd 1
snake: resw 100