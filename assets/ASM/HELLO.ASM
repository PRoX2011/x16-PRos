; HELLO.ASM -- output "Hello, PRos!" in the terminal
; Copyright (C) 2026 PRoX2011

mov ah, 0x01
mov si, msg
int 0x21
ret

msg: db "Hello, PRos!", 10, 13, 0