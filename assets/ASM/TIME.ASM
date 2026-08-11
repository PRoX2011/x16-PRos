; TIME.ASM -- output current time in the terminal
; Copyright (C) 2026 PRoX2011

mov ah, 0x0A
int 0x21

mov al, ch
call two_digits
mov [hr], ax

mov al, cl
call two_digits
mov [mn], ax

mov al, dh
call two_digits
mov [sc], ax

mov si, time_str
mov ah, 0x01
int 0x21
ret

two_digits:
    mov ah, 0
    mov bl, 10
    div bl
    add ax, 0x3030
    ret

time_str:
hr: db "00:"
mn: db "00:"
sc: db "00", 10, 0