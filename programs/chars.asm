; ==================================================================
; x16-PRos -- CHARS. A program that prints all ASCII characters
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    pusha

    mov ah, 0x05
    int 0x21

    mov cx, 0

.print_loop:
    mov ah, 0x0E
    mov al, cl
    mov bl, 0x0F
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x01
    mov si, .sep
    int 0x21

    inc cx
    cmp cx, 256
    je .done

    mov ah, 0x0E
    mov al, cl
    int 0x10

    mov ah, 0x05
    int 0x21

    inc cx
    cmp cx, 256
    jb .print_loop

.done:
    mov ah, 0x05
    int 0x21

    mov ah, 0x05
    int 0x21

    popa

    ret

.sep db '  ', 0