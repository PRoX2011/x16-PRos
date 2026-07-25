; ==================================================================
; x16-PRos - GUESS. Guess the number game.
; Demonstrates the INT 0x21 AH = 0x80 random generation API.
; Copyright (C) 2026 Antigravity
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    ; Print Game Welcome Title
    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

.start_game:
    ; 1. Generate a random target number between 1 and 100
    mov ax, cs
    mov es, ax
    mov di, rand_byte_buf
    mov cx, 1
    mov ah, 0x80        ; Call random API
    int 0x21

    ; Target = (random_byte % 100) + 1
    xor ax, ax
    mov al, [rand_byte_buf]
    mov bl, 100
    div bl              ; AH = AL % 100
    xor bx, bx
    mov bl, ah
    inc bl              ; BL = target number (1 to 100)
    mov [target_num], bl

    ; Reset attempt counter
    mov dword [attempts], 0

    ; Print target generation confirmation
    mov ah, 0x01
    mov si, gen_msg
    int 0x21

.game_loop:
    inc dword [attempts]

    ; Print guess prompt
    mov ah, 0x01
    mov si, prompt_msg
    int 0x21

    ; Read user guess input string
    mov di, input_buf
    call read_string

    ; Check if ESC was pressed to exit
    cmp byte [exit_flag], 1
    je .exit

    ; Print newline after input
    mov ah, 0x05
    int 0x21

    ; Convert input string to number in AX
    mov si, input_buf
    call atoi

    ; Compare AX (guess) with target_num
    xor cx, cx
    mov cl, [target_num]
    cmp ax, cx
    je .guessed_correct
    jb .guessed_lower
    ja .guessed_higher

.guessed_lower:
    mov ah, 0x01
    mov si, higher_msg
    int 0x21
    jmp .game_loop

.guessed_higher:
    mov ah, 0x01
    mov si, lower_msg
    int 0x21
    jmp .game_loop

.guessed_correct:
    mov ah, 0x01
    mov si, correct_msg
    int 0x21

    ; Print attempt count
    mov eax, [attempts]
    call print_number

    mov ah, 0x01
    mov si, attempts_suffix_msg
    int 0x21

    ; Ask to play again
    mov ah, 0x01
    mov si, play_again_msg
    int 0x21

.read_play_again:
    mov ah, 0
    int 0x16            ; Read char in AL
    cmp al, 'y'
    je .restart
    cmp al, 'Y'
    je .restart
    cmp al, 'n'
    je .exit
    cmp al, 'N'
    je .exit
    jmp .read_play_again

.restart:
    mov ah, 0x05        ; print newline
    int 0x21
    jmp .start_game

.exit:
    mov ah, 0x05        ; print newline
    int 0x21
    ret

; ========================================================================
; read_string - Reads a numeric string from keyboard with backspace support
; IN:  ES:DI = buffer to store the string
; OUT: String at ES:DI is null-terminated
;      exit_flag = 1 if user pressed ESC, 0 otherwise
; ========================================================================
read_string:
    pusha
    mov byte [exit_flag], 0
    xor cx, cx
.read_char:
    mov ah, 0
    int 0x16            ; AL = ASCII, AH = Scancode

    cmp al, 0x1B        ; ESC pressed?
    je .esc_pressed

    cmp al, 0x0D        ; Enter?
    je .done

    cmp al, 0x08        ; Backspace?
    je .backspace

    cmp al, '0'
    jb .read_char
    cmp al, '9'
    ja .read_char

    ; Echo character
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    int 0x10

    stosb
    inc cx
    cmp cx, 5           ; Limit input to 5 digits
    jae .done
    jmp .read_char

.backspace:
    test cx, cx
    jz .read_char
    dec di
    dec cx
    ; Erase on screen
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_char

.esc_pressed:
    mov byte [exit_flag], 1

.done:
    mov byte [di], 0    ; Null-terminate string
    popa
    ret

; ========================================================================
; atoi - Converts a null-terminated digit string at DS:SI to a word in AX
; IN:  DS:SI = pointer to string
; OUT: AX = parsed integer
; ========================================================================
atoi:
    push bx
    push cx
    xor dx, dx          ; DX = accumulator (result = 0)
    xor cx, cx          ; temp digit
.loop:
    lodsb               ; AL = character (overwrites AL/AX)
    test al, al
    jz .done
    cmp al, '0'
    jb .done            ; Stop at non-digit
    cmp al, '9'
    ja .done            ; Stop at non-digit
    sub al, '0'
    mov cl, al          ; CL = digit
    mov ax, dx          ; Move accumulated result to AX for mul
    mov bx, 10
    mul bx              ; DX:AX = AX * 10
    add ax, cx          ; AX = AX * 10 + digit
    mov dx, ax          ; Save result back to DX
    jmp .loop
.done:
    mov ax, dx          ; Return final result in AX
    pop cx
    pop bx
    ret

; ========================================================================
; print_number - Prints a 32-bit integer in EAX in base 10
; IN:  EAX = integer value
; OUT: Nothing (Prints characters to the console)
; ========================================================================
print_number:
    pusha
    test eax, eax
    jnz .not_zero

    mov si, zero_str
    mov ah, 0x01
    int 0x21
    jmp .done

.not_zero:
    mov edi, number_buffer + 10
    mov byte [edi], 0
    dec edi
    mov ebx, 10

.convert_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec edi
    test eax, eax
    jnz .convert_loop

    inc edi
    mov si, di
    mov ah, 0x01
    int 0x21

.done:
    popa
    ret

welcome_msg         db '=== Guess the Number (1-100) ===', 10, 13, 'Press ESC to exit.', 10, 13, 0
gen_msg             db 'I have generated a secret number.', 10, 13, 0
prompt_msg          db 'Enter your guess: ', 0
higher_msg          db 'Higher! Try again.', 10, 13, 0
lower_msg           db 'Lower! Try again.', 10, 13, 0
correct_msg         db 'Correct! You guessed the number in ', 0
attempts_suffix_msg db ' attempts!', 10, 13, 0
play_again_msg      db 'Play again? (y/n): ', 0
zero_str            db '0', 0

exit_flag           db 0
target_num          db 0
attempts            dd 0
rand_byte_buf       db 0
input_buf           times 8 db 0
number_buffer       times 12 db 0
