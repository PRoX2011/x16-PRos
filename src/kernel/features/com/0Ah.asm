com_0Ah:
    pusha
    mov si, dx
    xor cx, cx
    mov cl, [si]
    cmp cl, 0
    je .done
    mov di, dx
    add di, 2
    xor bx, bx
.input_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .enter
    cmp al, 0x08
    je .backspace
    cmp bl, cl
    jae .input_loop
    mov ah, 0x0E
    push bx
    mov bl, 0x0F
    int 0x10
    pop bx
    mov [di + bx], al
    inc bx
    jmp .input_loop
.backspace:
    cmp bx, 0
    je .input_loop
    dec bx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .input_loop
.enter:
    mov byte [di + bx], 0x0D
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    mov [si + 1], bl
.done:
    popa
    iret