; ==================================================================
; x16-PRos -- CREDITS. Contributors and sponsors list.
; Copyright (C) 2026 PRoX2011
; ==================================================================

[BITS 16]
[ORG 0x8000]

ENTRY_SIZE   equ 4
LEFT_COL     equ 2
RIGHT_COL    equ 42
ROLE_OFFSET  equ 22
START_ROW    equ 5

start:
    mov ah, 0x0C
    int 0x21

    mov dh, 0
    mov dl, 0
    mov si, title_line1
    call print_at

    mov dh, 1
    mov dl, 0
    mov si, title_line2
    call print_at

    mov dh, 3
    mov dl, LEFT_COL
    mov si, table_header
    call print_at

    xor bx, bx
    mov dh, START_ROW

.row_loop:
    cmp bx, entries_count
    jae .done_table

    mov dl, LEFT_COL
    call print_entry
    inc bx

    cmp bx, entries_count
    jae .next_row

    mov dl, RIGHT_COL
    call print_entry
    inc bx

.next_row:
    inc dh
    jmp .row_loop

.done_table:
    mov dh, 27
    mov dl, 0
    mov si, press_key_msg
    call print_at

    xor ah, ah
    int 0x16

    mov ah, 0x05
    int 0x21
    
    ret

print_entry:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, bx
    shl ax, 2
    mov di, entries
    add di, ax

    mov si, [di]
    call print_at

    mov si, [di+2]
    mov al, dl
    add al, ROLE_OFFSET
    mov dl, al
    call print_at

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_at:
    push ax
    push bx
    push dx

    mov ah, 0x02
    xor bh, bh
    int 0x10

    mov ah, 0x01
    int 0x21

    pop dx
    pop bx
    pop ax
    ret

section .data

title_line1  db 'x16-PRos credits', 0
title_line2  db 'Contributors and Sponsors', 0
table_header db 'Name                  Role                    Name                  Role', 0

role_contributor db '[contributor]', 0
role_sponsor     db '[sponsor]', 0

name_hanakbe       db 'Han Akbe', 0
name_ilnar         db 'Ilnar Karazbayev', 0
name_tomoko        db 'Tomoko', 0
name_qwez          db 'Qwez-dev', 0
name_saeta         db 'Saeta', 0
name_loxsete       db 'Loxsete', 0
name_leoono        db 'Leo-ono', 0
name_andrey        db 'Andrey', 0
name_desvor58      db 'desvor58', 0
name_tayowrld      db 'tayowrld', 0
name_dexoron       db 'dexoron', 0
name_sibunut       db 'sibunut', 0
name_chiefexb      db 'chiefexb', 0
name_dsign1k       db 'Dsign1k', 0
name_yaroslav      db 'Yaroslav', 0
name_greenbushy    db 'Green_Bushy', 0
name_tanushqn      db 'tanushqn', 0
name_g4sasha       db 'G4 Sasha', 0
name_klasterk      db 'KlasterK', 0
name_petruchiorus  db 'PetruCHIOrus', 0 
name_sdkam         db 'sdkam', 0
name_kraniov       db 'kraniov', 0
name_anarh1st47    db 'anarh1st47', 0
name_eduard        db 'Eduard', 0
name_relya         db 'relya', 0
name_vokichhh      db 'Vokichhh', 0
name_ayano4ka1338  db 'ayano4ka1338', 0
name_nortyashka    db 'Nortyashka', 0
name_qqq           db 'QQQ', 0

entries:
    dw name_hanakbe,      role_contributor
    dw name_ilnar,        role_contributor
    dw name_tomoko,       role_contributor
    dw name_qwez,         role_contributor
    dw name_saeta,        role_contributor
    dw name_loxsete,      role_contributor
    dw name_leoono,       role_contributor
    dw name_andrey,       role_contributor
    dw name_desvor58,     role_contributor
    dw name_tayowrld,     role_contributor
    dw name_dexoron,      role_contributor
    dw name_sibunut,      role_contributor
    dw name_chiefexb,     role_contributor
    dw name_dsign1k,      role_contributor
    dw name_anarh1st47,   role_sponsor
    dw name_yaroslav,     role_sponsor
    dw name_greenbushy,   role_sponsor
    dw name_tanushqn,     role_sponsor
    dw name_g4sasha,      role_sponsor
    dw name_sdkam,        role_sponsor
    dw name_petruchiorus, role_sponsor
    dw name_kraniov,      role_sponsor
    dw name_klasterk,     role_sponsor
    dw name_eduard,       role_sponsor
    dw name_relya,        role_sponsor
    dw name_vokichhh,     role_sponsor
    dw name_ayano4ka1338, role_sponsor
    dw name_nortyashka,   role_sponsor
    dw name_qqq,          role_sponsor
entries_end:

entries_count equ (entries_end - entries) / ENTRY_SIZE

press_key_msg db 'Press any key to return to shell...', 0