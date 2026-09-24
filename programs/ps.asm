; ==================================================================
; x16-PRos -- PS. Active process viewer
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

TASK_S_FREE   equ 0
TASK_NAME_LEN equ 16

start:
    pusha

    mov ah, 0x05
    int 0x21
    mov ah, 0x01
    mov si, header_msg
    int 0x21
    mov ah, 0x05
    int 0x21

    mov byte [iter], 0

.loop:
    mov bl, [iter]
    mov ah, 0x17
    int 0x23
    jc .skip

    mov [save_state], al
    mov [save_flags], ah
    mov [save_seg], cx

    cmp al, TASK_S_FREE
    je .skip

    mov bl, [iter]
    mov di, name_buf
    mov ah, 0x19
    int 0x23

    mov di, row_buf
    mov si, name_buf
    mov cx, TASK_NAME_LEN
.copy_name:
    lodsb
    test al, al
    jz .pad_name
    stosb
    loop .copy_name
    jmp .after_name
.pad_name:
    mov al, ' '
.pad_loop:
    stosb
    loop .pad_loop
.after_name:

    mov al, ' '
    stosb
    stosb

    ; ID column
    mov al, [iter]
    add al, '0'
    stosb

    mov al, ' '
    stosb
    stosb
    stosb
    stosb

    mov ax, [save_seg]
    call hex4_to_buf
    mov al, ':'
    stosb
    xor ax, ax
    call hex4_to_buf

    xor al, al
    stosb

    mov si, row_buf
    mov ah, 0x01
    int 0x21
    mov ah, 0x05
    int 0x21

.skip:
    inc byte [iter]
    cmp byte [iter], 4
    jb  .loop

    mov ah, 0x05
    int 0x21
    popa
    ret

hex4_to_buf:
    push ax
    push bx
    push cx
    mov cx, 4
.lp:
    rol ax, 4
    mov bl, al
    and bl, 0x0F
    cmp bl, 10
    jb  .digit
    add bl, 7
.digit:
    add bl, '0'
    mov [di], bl
    inc di
    loop .lp
    pop cx
    pop bx
    pop ax
    ret

section .data

header_msg db 'NAME              ID   ADDRESS', 0
iter       db 0
save_state db 0
save_flags db 0
save_seg   dw 0

name_buf   times TASK_NAME_LEN + 1 db 0
row_buf    times 48 db 0
