; DATE.ASM -- output current date in the terminal
; Copyright (C) 2026 PRoX2011

mov ah, 0x0B
int 0x21

mov al, dl
call two_digits
mov [dy], ax

mov al, dh
call two_digits
mov [mo], ax

mov al, ch
call two_digits
mov [ce], ax

mov al, cl
call two_digits
mov [yr], ax

mov si, date_str
mov ah, 0x01
int 0x21
ret

two_digits:
    mov ah, 0
    mov bl, 10
    div bl
    add ax, 0x3030
    ret

date_str:
dy: db "00."
mo: db "00."
ce: db "00"
yr: db "00", 10, 0
