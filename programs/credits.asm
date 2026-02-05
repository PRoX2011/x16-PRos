; ==================================================================
; x16-PRos -- CREDITS. I must to say thank you to all of these guys.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x06
    mov al, 0
    mov bh, 0
    mov cx, 0
    mov dx, 0x1D4F
    int 0x10

    mov cx, 0x001E
    mov dx, 0x8480
    mov ah, 0x86
    int 0x15

    mov ah, 0x02
    mov bh, 0
    mov dh, 0x1D
    mov dl, 0
    int 0x10

    mov si, credit1
    call print_credit_line

    mov si, credit2
    call print_credit_line

    mov si, credit3
    call print_credit_line

    mov si, credit4
    call print_credit_line

    mov si, credit5
    call print_credit_line

    mov si, credit6
    call print_credit_line

    mov si, credit7
    call print_credit_line

    mov si, credit8
    call print_credit_line

    mov si, credit9
    call print_credit_line

    mov si, credit10
    call print_credit_line

    mov si, credit11
    call print_credit_line

    mov si, credit12
    call print_credit_line

    mov si, credit13
    call print_credit_line

    mov si, credit14
    call print_credit_line

    mov si, credit15
    call print_credit_line

    mov si, credit16
    call print_credit_line

    mov si, credit17
    call print_credit_line

    mov si, credit18
    call print_credit_line

    mov si, credit19
    call print_credit_line

    mov si, credit20
    call print_credit_line

    mov si, credit21
    call print_credit_line

    mov si, credit22
    call print_credit_line

    mov si, credit23
    call print_credit_line

    mov si, credit24
    call print_credit_line

    mov si, credit25
    call print_credit_line

    mov si, credit26
    call print_credit_line

    mov si, credit27
    call print_credit_line

    mov si, credit28
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov si, credit
    call print_credit_line

    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 0
    int 0x10

    mov si, press_key_msg
    mov ah, 0x01
    int 0x21

    mov ah, 0
    int 0x16

    ret

; Function to print a credit line using API (INT 0x21, AH=0x01)
; SI = pointer to string (includes 13,10,0)
print_credit_line:
    mov ah, 0x01
    int 0x21

    mov cx, 0x0007
    mov dx, 0xA120
    mov ah, 0x86
    int 0x15

    ret

; Credit lines
credit1:  db '-------------------------- x16-PRos operating system --------------------------', 13, 10, 13, 10, 0
credit2:  db '                         ======== By PRoX-dev ========', 13, 10, 13, 10, 0
credit3:  db '                             --- Special thanks ---', 13, 10, 13, 10, 0
credit4:  db '                                    Han Akbe', 13, 10, 0
credit5:  db '                                Ilnar Karazbayev', 13, 10, 0
credit6:  db '                                    Tomoko', 13, 10, 0
credit7:  db '                                    Qwez-dev', 13, 10, 0
credit8:  db '                                     Saeta', 13, 10, 0
credit9:  db '                                    Loxsete', 13, 10, 0
credit10:  db '                                   Leo-ono', 13, 10, 0
credit11: db '                                     Andrey', 13, 10, 0
credit12: db '                                    Yaroslav', 13, 10, 0
credit13: db '                                   Green_Bushy', 13, 10, 0
credit14: db '                                    tanushqn', 13, 10, 0
credit15: db '                                    G4 Sasha', 13, 10, 13, 10, 0
credit16: db '                           OSdev Wiki (wiki.osdev.org)', 13, 10, 0
credit17: db '                   OSdev Reddit Comunnity (reddit.com/r/osdev/)', 13, 10, 0
credit18: db '                              OSdev Discord Comunnity', 13, 10, 13, 10, 0
credit19: db 15 dup(' '), 0xC9, 47 dup(0xCD), 0xBB, 10, 13, 0
credit20: db 15 dup(' '), 0xBA, '  I', 0x27 ,'d like to express my deepest gratitude to  ', 0xBA, 10, 13, 0
credit21: db 15 dup(' '), 0xBA, '   everyone who supported the project in any   ', 0xBA, 10, 13, 0
credit22: db 15 dup(' '), 0xBA, '   way, promoted it, gave it stars on GitHub,  ', 0xBA, 10, 13, 0
credit23: db 15 dup(' '), 0xBA, '    and helped with the creation of various    ', 0xBA, 10, 13, 0
credit24: db 15 dup(' '), 0xBA, '     parts of the kernel code and programs.    ', 0xBA, 10, 13, 0
credit25: db 15 dup(' '), 0xBA, '                                               ', 0xBA, 10, 13, 0
credit26: db 15 dup(' '), 0xBA, '           Without you, none of this           ', 0xBA, 10, 13, 0
credit27: db 15 dup(' '), 0xBA, '           would have been possible.           ', 0xBA, 10, 13, 0
credit28: db 15 dup(' '), 0xC8, 47 dup(0xCD), 0xBC, 0
credit:   db 13, 10, 0
press_key_msg: db 'Press any key to return to shell...                              ', 13, 10, 0