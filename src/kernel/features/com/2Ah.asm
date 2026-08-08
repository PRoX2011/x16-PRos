<<<<<<< HEAD
com_2Ah:
    push bx
    push ax
    mov ah, 0x04
    int 0x1A
    mov al, cl
    call bcd_to_bin
    mov cl, al
    mov al, ch
    call bcd_to_bin
    mov ch, al
    mov al, dh
    call bcd_to_bin
    mov dh, al
    mov al, dl
    call bcd_to_bin
    mov dl, al
    mov al, 0
    pop ax
    pop bx
    iret
=======
; ==================================================================
; AH=2Ah - Get system date (DOS-compatible).
; OUT: CX = year (e.g., 2026), DH = month, DL = day, AL = day of week
;      (0 = Sunday .. 6 = Saturday)
; ==================================================================
com_2Ah:
    push bx
    push cx
    push dx

    mov ah, 0x04
    int 0x1A            ; CH=century(BCD), CL=year(BCD), DH=month, DL=day

    mov al, cl
    call bcd_to_bin
    mov cl, al          ; CL = year (0-99)
    mov al, ch
    call bcd_to_bin
    mov ch, al          ; CH = century (e.g., 20)
    mov al, dh
    call bcd_to_bin
    mov dh, al          ; DH = month
    mov al, dl
    call bcd_to_bin
    mov dl, al          ; DL = day

    ; Full year = century*100 + year -> CX
    mov al, ch
    mov bl, 100
    mul bl              ; AX = century*100
    mov [.year_hi], ax
    mov al, cl
    xor ah, ah          ; AX = year
    add ax, [.year_hi]  ; AX = full year
    mov cx, ax

    ; Day of week (Zeller/Sakamoto), DOS: 0 = Sunday.
    ; AL = (h + 1) mod 7, h = (day + 13(m+1)/5 + K + K/4 + J/4 + 5J) mod 7
    push ax
    push cx
    push dx
    mov bx, ax          ; BX = full year
    xor dx, dx
    mov cx, 100
    mov ax, bx
    div cx              ; AX = J, DX = K
    mov [.j], ax
    mov [.k], dx
    pop dx
    pop cx
    pop ax

    cmp dh, 3
    jge .no_adj
    add dh, 12
    dec ax
.no_adj:

    ; sum = q(day) + 13(m+1)/5 + K/4 + K + J/4 + 5J
    mov bx, ax          ; BX = adjusted year
    mov ax, bx
    xor dx, dx
    mov cx, 100
    div cx              ; AX = J2, DX = K2
    mov [.j2], ax
    mov [.k2], dx

    mov [.sum], dx      ; start with K2
    mov ax, [.j2]
    shr ax, 1
    shr ax, 1
    add [.sum], ax      ; + J2/4
    mov ax, [.j2]
    mov cx, 5
    mul cx
    add [.sum], ax      ; + 5*J2

    mov al, dh          ; m (adjusted month)
    inc al
    mov bl, 13
    mul bl
    mov bl, 5
    div bl              ; AL = 13(m+1)/5
    xor ah, ah
    add [.sum], ax

    mov ax, [.k2]
    shr ax, 2
    add [.sum], ax      ; + K2/4
    mov ax, [.k2]
    add [.sum], ax      ; + K2
    xor bx, bx
    mov bl, dl          ; q = day
    add [.sum], bx

    mov ax, [.sum]
    xor dx, dx
    mov cx, 7
    div cx              ; DX = h (0 = Saturday)
    inc dx              ; h+1
    mov ax, dx
    xor dx, dx
    mov cx, 7
    div cx
    mov al, dl          ; AL = day of week (0 = Sunday)

    mov [.dow], al

    pop dx
    pop cx
    pop bx
    mov al, [.dow]
    iret

.j dw 0
.k dw 0
.j2 dw 0
.k2 dw 0
.sum dw 0
.dow db 0
.year_hi dw 0
>>>>>>> 88a7da6 (Первый коммит)
