; ==================================================================
; x16-PRos -- CLOCK. Clock.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    pusha

    mov ax, 0x03
    int 0x10

    push es

    mov ax, 0xB800
    mov es, ax

update:
    mov ah, BYTE [col]
	xor al, al
	mov cx, 2000
	xor di, di
	rep stosw

    mov ah, 0x02
    int 0x1A

    test byte [h24], 1
    jne hour24
    cmp ch, 00010010b
    jle hour24
    sub ch, 00010010b
    xchg ch, al
    das
    xchg ch, al

hour24:
    mov bl, ch
    shr bl, 4
    xor di, di
    call paint_digit

    mov bl, ch
    and bl, 1111b
    mov di, 34
    call paint_digit

    mov bl, cl
    shr bl, 4
    mov di, 92
    call paint_digit

    mov bl, cl
    and bl, 1111b
    mov di, 126
    call paint_digit

    xor ax, ax
    bt dx, 8
    jnc dot
    mov ax, [fullchr]
dot:
    mov di, 876
    mov cx, 3
    rep stosw
    mov cx, 3
    mov di, 1036
    rep stosw
    mov cx, 3
    mov di, 1996
    rep stosw
    mov cx, 3
    mov di, 2156
    rep stosw

    mov ah, 2
	mov dx, 0x1524
	int 0x10

.print_date:
	mov ah, 0x04
	int 0x1a

	mov ah, 0x0e

	mov al, dl
	shr al, 4
	add al, "0"
	int 0x10
	mov al, dl
	and al, 01111b
	add al, "0"
	int 0x10

	mov al, "."
	int 0x10

	mov al, dh
	shr al, 4
	add al, "0"
	int 0x10
	mov al, dh
	and al, 01111b
	add al, "0"
	int 0x10

	mov al, "."
	int 0x10

	mov al, cl
	shr al, 4
	add al, "0"
	int 0x10
	mov al, cl
	and al, 01111b
	add al, "0"
	int 0x10

    mov si, help
    mov di, 3520
    mov ah, [col]
.print_help:
    lodsb
    test al, al
    jz .help_done
    stosw
    jmp .print_help
.help_done:

    mov ah, 0x02
    mov dx, 0x1900
    mov bh, 0
    int 0x10

    mov ah, 0x01
    int 0x16
    jz .no_key
    xor ah, ah
    int 0x16

    cmp al, 27
    je .exit
    cmp al, 'f'
    jne .next_key
    mov al, [col]
    mov ah, al
    inc al
    and ax, 0xF00F
    or al, ah
    mov [col], al
    jmp .no_key
.next_key:
    cmp al, 'b'
    jne .next_key1
    mov al, [col]
    mov ah, al
    and al, 0xF
    shr ah, 4
    inc ah
    and ah, 0xF
    shl ah, 4
    or al, ah
    mov [col], al
    jmp .no_key
.next_key1:
    cmp al, 'h'
    jne .no_key
    xor byte [h24], 1

.no_key:
    mov dx, 500
    call delay_ms

    jmp update

.exit:
    mov ah, 0x01
    int 0x16
    jz .buffer_cleared
    xor ah, ah
    int 0x16
    jmp .exit
.buffer_cleared:
    pop es

    mov ax, 0x12
    int 0x10

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
    add di, 24
    call bar_vert
    pop di
.b3:
    bt dx, 3
    jnc .b2
    mov al, 8
    call bar_horiz
.b2:
    bt dx, 2
    jnc .b1
    mov al, 8
    call bar_vert
.b1:
    bt dx, 1
    jnc .b0
    mov al, 8
    push di
    add di, 24
    call bar_vert
    pop di
.b0:
    bt dx, 0
    jnc .digdone
    mov ax, 16
    call bar_horiz
.digdone:
    popa
    ret


bar_horiz:
    pusha
    mov bx, 160
    mul bx
    add di, ax
    mov bx, 3
.barh:
    mov cx, 16
    mov ax, [fullchr]
    rep stosw
    add di, 128
    dec bx
    jnz .barh
    popa
    ret

bar_vert:
    pusha
    mov bx, 160
    mul bx
    add di, ax
    mov bx, 11
.barv:
    mov cx, 4
    mov ax, [fullchr]
    rep stosw
    add di, 152
    dec bx
    jnz .barv
    popa
    ret

pattern db 01110111b, 00010010b, 01011101b, 01011011b, 0111010b
        db 01101011b, 01101111b, 01010010b, 01111111b, 01111011b
fullchr:
    chr db 0xDB
    col db 0x07
h24 db 1
help db 'Hours format: 24h     Use f/b to change clock color     Press ESC to exit', 0

; -----------------------------
; One second delay
; IN  : Nothing
delay_ms:
    pusha
    mov ax, dx
    mov cx, 1000
    mul cx
    mov cx, dx
    mov dx, ax
    mov ah, 0x86
    int 0x15
    popa
    ret