; ==================================================================
; x16-PRos - UPTIME.BIN. Shows the time elapsed since midnight
; (from the BIOS tick counter) as HH:MM:SS.
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x00
    int 0x1A            ; CX:DX = ticks since midnight (~18.2065 ticks/sec)

    ; ticks -> seconds = ticks / 18
    mov ax, dx
    mov dx, cx          ; DX:AX = ticks
    mov bx, 18
    call div32_16       ; DX:AX = seconds, CX = remainder
    mov [data_seconds], ax
    mov [data_seconds+2], dx

    ; hours = seconds / 3600
    mov dx, [data_seconds+2]
    mov ax, [data_seconds]
    mov bx, 3600
    call div32_16       ; DX:AX = hours, CX = remainder (seconds within the hour)
    mov [data_hours], ax
    mov [data_remainder], cx

    ; minutes = remainder / 60
    mov ax, [data_remainder]
    xor dx, dx
    mov bx, 60
    div bx              ; AX = minutes, DX = seconds
    mov [data_minutes], ax
    mov [data_secs], dx

    ; print HH:MM:SS
    mov ax, [data_hours]
    call print2
    mov al, ':'
    call print_char
    mov ax, [data_minutes]
    call print2
    mov al, ':'
    call print_char
    mov ax, [data_secs]
    call print2
    mov ah, 0x0E
    mov al, 0x0D
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ------------------------------------------------------------------
; DIV32_16 - 32-bit / 16-bit divide.
; IN : DX:AX = dividend, BX = divisor (1..0xFFFF)
; OUT: DX:AX = quotient, CX = remainder
; ------------------------------------------------------------------
div32_16:
    push si
    mov si, ax          ; SI = low word
    mov ax, dx          ; AX = high word
    xor dx, dx
    div bx              ; AX = high/BX, DX = high%BX
    mov cx, ax          ; CX = high quotient
    mov ax, si          ; AX = low word
    div bx              ; AX = low quotient, DX = remainder
    mov si, cx
    mov cx, dx
    mov dx, si
    pop si
    ret

; ------------------------------------------------------------------
; PRINT2 - print AX (0-99) as two digits with a leading zero.
; ------------------------------------------------------------------
print2:
    push ax
    push dx
    xor dx, dx
    mov bx, 10
    div bx              ; AL = tens, DL = ones
    add al, '0'
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    mov al, dl
    add al, '0'
    int 0x10
    pop dx
    pop ax
    ret

; ------------------------------------------------------------------
; PRINT_CHAR - print AL as a character.
; ------------------------------------------------------------------
print_char:
    push ax
    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x0F
    int 0x10
    pop ax
    ret

data_seconds   dd 0
data_hours     dw 0
data_remainder dw 0
data_minutes   dw 0
data_secs      dw 0
