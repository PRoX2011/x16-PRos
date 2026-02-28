; ==================================================================
; x16-PRos -- Font rendering library for VGA mode 0x12
; Copyright (C) 2025 PRoX2011
;
; Provides pixel-level character rendering with foreground and
; background colors via direct VGA planar memory access using
; the BIOS 8x16 ROM font.
; ==================================================================

%ifndef FONT_INC
%define FONT_INC

; ========================================================================
; VGA and screen constants
; ========================================================================
FONT_VGA_SEG    equ 0xA000
FONT_COLS       equ 80
FONT_ROWS       equ 30
FONT_CHAR_H     equ 16
FONT_BPL        equ 80
FONT_SEQ_IDX    equ 0x3C4
FONT_SEQ_DAT    equ 0x3C5
FONT_GFX_IDX    equ 0x3CE
FONT_GFX_DAT    equ 0x3CF
FONT_MAP_MASK   equ 0x02

; ========================================================================
; font_init -- Initialize the font rendering system
; Retrieves the BIOS 8x16 ROM font pointer and sets up VGA
; registers for direct planar writes.
; IN:  Nothing
; OUT: Nothing (registers preserved)
; ========================================================================
font_init:
    pusha
    push es

    mov ax, 0x1130
    mov bh, 0x06
    int 0x10
    mov word [font_data_seg], es
    mov word [font_data_off], bp

    mov dx, FONT_GFX_IDX
    mov al, 0x05
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al

    dec dx
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al

    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    out dx, al

    mov dx, FONT_SEQ_IDX
    mov al, FONT_MAP_MASK
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    pop es
    popa
    cld
    ret

; ========================================================================
; font_put_char -- Draw a character with foreground and background color
; IN:  AL = ASCII character code
;      CL = column (0-79)
;      CH = row (0-29)
;      BL = color attribute (high nibble = bg, low nibble = fg)
; OUT: Nothing
; ========================================================================
font_put_char:
    pusha
    push ds
    push es

    mov [.char], al
    mov [.col], cl
    mov [.row], ch
    mov [.attr], bl

    xor ah, ah
    mov al, [.char]
    shl ax, 4
    add ax, word [font_data_off]
    mov dx, word [font_data_seg]

    mov ds, dx
    mov si, ax
    push cs
    pop es
    mov di, .glyph
    mov cx, 16
    cld
    rep movsb

    push cs
    pop ds

    xor ah, ah
    mov al, [.row]
    mov bx, FONT_CHAR_H * FONT_BPL
    mul bx
    xor bh, bh
    mov bl, [.col]
    add ax, bx
    mov di, ax

    mov ax, FONT_VGA_SEG
    mov es, ax

    mov al, [.attr]
    and al, 0x0F
    mov [.fg], al
    mov al, [.attr]
    shr al, 4
    mov [.bg], al

    mov dx, FONT_SEQ_IDX
    mov al, FONT_MAP_MASK
    out dx, al

    mov si, .glyph
    mov cx, 16

.scanline:
    push cx
    lodsb
    mov [.gbyte], al

    mov byte [.pmask], 0x01
    mov byte [.pbit], 0x01

.plane:
    mov dx, FONT_SEQ_DAT
    mov al, [.pmask]
    out dx, al

    xor al, al
    mov bl, [.pbit]

    test byte [.fg], bl
    jz .no_fg
    or al, [.gbyte]
.no_fg:
    test byte [.bg], bl
    jz .no_bg
    mov ah, [.gbyte]
    not ah
    or al, ah
.no_bg:
    mov [es:di], al

    shl byte [.pmask], 1
    shl byte [.pbit], 1
    cmp byte [.pmask], 0x10
    jb .plane

    add di, FONT_BPL
    pop cx
    loop .scanline

    mov dx, FONT_SEQ_DAT
    mov al, 0x0F
    out dx, al

    pop es
    pop ds
    popa
    ret

.char   db 0
.col    db 0
.row    db 0
.attr   db 0
.fg     db 0
.bg     db 0
.gbyte  db 0
.pmask  db 0
.pbit   db 0
.glyph  times 16 db 0

; ========================================================================
; font_print_string -- Print a null-terminated string at (col, row)
; IN:  SI = pointer to null-terminated string
;      CL = starting column (0-79)
;      CH = row (0-29)
;      BL = color attribute
; OUT: Nothing
; ========================================================================
font_print_string:
    pusha
    mov [.col], cl
    mov [.row], ch
    mov [.attr], bl

.next:
    lodsb
    cmp al, 0
    je .done

    push si
    mov cl, [.col]
    mov ch, [.row]
    mov bl, [.attr]
    call font_put_char
    pop si

    inc byte [.col]
    cmp byte [.col], FONT_COLS
    jb .next

    mov byte [.col], 0
    inc byte [.row]
    cmp byte [.row], FONT_ROWS
    jb .next

.done:
    popa
    ret

.col  db 0
.row  db 0
.attr db 0

; ========================================================================
; font_fill_row -- Fill an entire character row with a solid 4-bit color
; Uses fast direct VGA plane fills.
; IN:  AL = fill color (0-15)
;      CH = row (0-29)
; OUT: Nothing
; ========================================================================
font_fill_row:
    pusha
    push es

    mov [.color], al

    xor ah, ah
    mov al, ch
    mov bx, FONT_CHAR_H * FONT_BPL
    mul bx
    mov [.start], ax

    mov ax, FONT_VGA_SEG
    mov es, ax

    mov dx, FONT_SEQ_IDX
    mov al, FONT_MAP_MASK
    out dx, al

    mov byte [.pmask], 0x01
    mov byte [.pbit], 0x01

.plane:
    mov dx, FONT_SEQ_DAT
    mov al, [.pmask]
    out dx, al

    mov di, [.start]
    mov al, [.color]
    test al, [.pbit]
    jz .zero
    mov ax, 0xFFFF
    jmp .fill
.zero:
    xor ax, ax
.fill:
    mov cx, 640
    cld
    rep stosw

    shl byte [.pmask], 1
    shl byte [.pbit], 1
    cmp byte [.pmask], 0x10
    jb .plane

    mov dx, FONT_SEQ_DAT
    mov al, 0x0F
    out dx, al

    pop es
    popa
    ret

.color db 0
.start dw 0
.pmask db 0
.pbit  db 0

; ========================================================================
; font_fill_rect -- Fill a rectangular area with a solid 4-bit color
; IN:  AL = fill color (0-15)
;      CL = start column (0-79)
;      CH = start row (0-29)
;      DL = width in characters
;      DH = height in characters
; OUT: Nothing
; ========================================================================
font_fill_rect:
    pusha
    push es

    mov [.color], al
    mov [.col], cl
    mov [.row], ch
    mov [.width], dl
    mov [.height], dh

    xor ah, ah
    mov al, [.height]
    shl ax, 4
    mov [.pix_h], ax

    xor ah, ah
    mov al, [.row]
    mov bx, FONT_CHAR_H * FONT_BPL
    mul bx
    xor bh, bh
    mov bl, [.col]
    add ax, bx
    mov [.start], ax

    mov ax, FONT_VGA_SEG
    mov es, ax

    mov dx, FONT_SEQ_IDX
    mov al, FONT_MAP_MASK
    out dx, al

    mov byte [.pmask], 0x01
    mov byte [.pbit], 0x01

.plane:
    mov dx, FONT_SEQ_DAT
    mov al, [.pmask]
    out dx, al

    mov al, [.color]
    test al, [.pbit]
    jz .z
    mov byte [.fbyte], 0xFF
    jmp .rows
.z:
    mov byte [.fbyte], 0x00

.rows:
    mov di, [.start]
    mov bx, [.pix_h]

.row_loop:
    push di
    xor ch, ch
    mov cl, [.width]
    mov al, [.fbyte]
    cld
    rep stosb
    pop di
    add di, FONT_BPL
    dec bx
    jnz .row_loop

    shl byte [.pmask], 1
    shl byte [.pbit], 1
    cmp byte [.pmask], 0x10
    jb .plane

    mov dx, FONT_SEQ_DAT
    mov al, 0x0F
    out dx, al

    pop es
    popa
    ret

.color  db 0
.col    db 0
.row    db 0
.width  db 0
.height db 0
.fbyte  db 0
.pmask  db 0
.pbit   db 0
.pix_h  dw 0
.start  dw 0

; ========================================================================
; font_clear_screen -- Clear the entire screen with a solid 4-bit color
; IN:  AL = fill color (0-15)
; OUT: Nothing
; ========================================================================
font_clear_screen:
    pusha
    push es

    mov [.color], al

    mov ax, FONT_VGA_SEG
    mov es, ax

    mov dx, FONT_SEQ_IDX
    mov al, FONT_MAP_MASK
    out dx, al

    mov byte [.pmask], 0x01
    mov byte [.pbit], 0x01

.plane:
    mov dx, FONT_SEQ_DAT
    mov al, [.pmask]
    out dx, al

    xor di, di
    mov cx, 19200

    mov al, [.color]
    test al, [.pbit]
    jz .zero
    mov ax, 0xFFFF
    jmp .fill
.zero:
    xor ax, ax
.fill:
    cld
    rep stosw

    shl byte [.pmask], 1
    shl byte [.pbit], 1
    cmp byte [.pmask], 0x10
    jb .plane

    mov dx, FONT_SEQ_DAT
    mov al, 0x0F
    out dx, al

    pop es
    popa
    ret

.color db 0
.pmask db 0
.pbit  db 0

font_data_seg dw 0
font_data_off dw 0

%endif