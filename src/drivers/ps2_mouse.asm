; ==================================================================
; x16-PRos - PS/2 mouse driver
; Copyright (C) 2025 PRoX2011
;
; Driver version: 0.4.1
;
; Compatible with video modes:
;   - 0x12  (VGA, 640x480, 16 colors, planar)
; ==================================================================

%define WCURSOR      8
%define HCURSOR      11

%define CHAR_W       8
%define CHAR_H       16
%define COLS         80
%define ROWS         30

%define BYTES_PER_LINE 80

section .text

InitMouse:
    int 0x11
    test ax, 0x04
    jz noMouse
    mov ax, 0xC205
    mov bh, 0x03
    int 0x15
    jc noMouse
    mov ax, 0xC203
    mov bh, 0x03
    int 0x15
    jc noMouse
    ret

EnableMouse:
    call DisableMouse
    mov ax, 0xC207
    mov bx, MouseCallback
    int 0x15
    mov ax, 0xC200
    mov bh, 0x01
    int 0x15
    ret

DisableMouse:
    mov ax, 0xC200
    mov bh, 0x00
    int 0x15
    mov ax, 0xC207
    int 0x15
    ret


MouseCallback:
    push bp
    mov bp, sp
    pusha
    push es
    push ds
    push cs
    pop ds

    cmp byte [CursorVisible], 0
    je .skip_hide_at_entry
    call HideCursor
.skip_hide_at_entry:

    mov al, [bp + 12]
    mov bl, al
    mov cl, 3
    shl al, cl
    sbb dh, dh
    cbw
    mov dl, [bp + 8]        ; dl = delta X
    mov al, [bp + 10]       ; al = delta Y
    neg dx

    mov cx, [MouseY]
    add dx, cx
    mov cx, [MouseX]
    add ax, cx

    cmp ax, 0
    jge .check_x_max
    xor ax, ax
.check_x_max:
    cmp ax, 639 - WCURSOR
    jle .check_y_min
    mov ax, 639 - WCURSOR
.check_y_min:
    cmp dx, 0
    jge .check_y_max
    xor dx, dx
.check_y_max:
    cmp dx, 479 - HCURSOR
    jle .update_pos
    mov dx, 479 - HCURSOR

.update_pos:
    mov bh, [ButtonStatus]
    mov [ButtonStatus], bl

    push ax
    push dx
    sub ax, [MouseX]
    sub dx, [MouseY]
    mov [m33_dx], ax
    mov [m33_dy], dx
    add [m33_mickx], ax
    add [m33_micky], dx
    pop dx
    pop ax

    mov [MouseX], ax
    mov [MouseY], dx
    call m33_edges


    mov ax, [MouseX]
    shr ax, 3
    mov [MouseCol], ax

    mov ax, [MouseY]
    xor dx, dx
    mov bx, CHAR_H
    div bx                  ; ax = MouseY / 16
    mov [MouseRow], ax


    mov al, [ButtonStatus]
    and al, 0x01

    cmp byte [SelEnabled], 0
    je .draw_cursor_and_exit        ; selection disabled — skip all selection logic

    mov ah, [PrevLMB]
    mov [PrevLMB], al

    cmp al, ah
    je .button_held

    test al, al
    jnz .button_pressed
    jmp .button_released

.button_pressed:
    call EraseSelection
    mov ax, [MouseCol]
    mov [SelStartCol], ax
    mov [SelEndCol], ax
    mov ax, [MouseRow]
    mov [SelStartRow], ax
    mov [SelEndRow], ax
    mov byte [SelDrawn], 0
    mov byte [SelActive], 1
    jmp .draw_cursor_and_exit

.button_released:
    mov byte [SelActive], 0
    jmp .draw_cursor_and_exit

.button_held:
    test al, al
    jz .draw_cursor_and_exit

    mov ax, [MouseCol]
    mov bx, [MouseRow]
    cmp ax, [SelEndCol]
    jne .sel_changed
    cmp bx, [SelEndRow]
    je .draw_cursor_and_exit

.sel_changed:
    call EraseSelection
    mov ax, [MouseCol]
    mov [SelEndCol], ax
    mov ax, [MouseRow]
    mov [SelEndRow], ax
    call DrawSelection

.draw_cursor_and_exit:
    cmp byte [CursorVisible], 0
    je .silent_exit
    call SaveBackground
    call PickCursorColor
    mov si, mousebmp
    mov al, 0x0F
    call DrawCursor
.silent_exit:

    pop ds
    pop es
    popa
    pop bp
    retf

EraseSelection:
    cmp byte [SelDrawn], 1
    jne .nothing_to_erase
    call DrawSelection
    mov byte [SelDrawn], 0
.nothing_to_erase:
    ret


DrawSelection:
    pusha

    mov ax, [SelStartRow]
    mov bx, [SelEndRow]
    mov cx, [SelStartCol]
    mov dx, [SelEndCol]
						    ; normalize string
    cmp ax, bx
    jle .rows_ok
    xchg ax, bx
.rows_ok:
    mov [.norm_r1], ax
    mov [.norm_r2], bx

    cmp cx, dx
    jle .cols_ok
    xchg cx, dx
.cols_ok:
    mov [.norm_c1], cx
    mov [.norm_c2], dx

    mov dx, 0x3CE
    mov al, 3
    out dx, al
    inc dx
    mov al, 0x18            ; XOR on
    out dx, al

    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    mov ax, [.norm_r1]
.row_loop:
    cmp ax, [.norm_r2]
    jg .done

    push ax

    mov bx, [.norm_r1]
    mov cx, [.norm_r2]
    cmp bx, cx
    je .single_row

    cmp ax, bx
    je .first_row_multi
    cmp ax, cx
    je .last_row_multi

    xor si, si              ; col_start = 0
    mov di, COLS - 1        ; col_end = 79
    jmp .invert_range

.first_row_multi:
    mov si, [SelStartCol]
    mov di, COLS - 1
    jmp .invert_range

.last_row_multi:
    xor si, si
    mov di, [SelEndCol]
    jmp .invert_range

.single_row:
    mov si, [.norm_c1]
    mov di, [.norm_c2]

.invert_range:
    push si
    push di

    mov bx, ax
    mov ax, CHAR_H
    mul bx                  ; ax = row * 16
    mov bx, BYTES_PER_LINE  
    mul bx                  ; ax = row * 16 * 80 = base offsets string

    pop di
    pop si


    add ax, si
    mov [.base_off], ax
    
    mov bx, di
    sub bx, si
    inc bx
    mov [.width], bx

    mov ax, 0xA000
    mov es, ax              ; es = segment video memory

    xor cx, cx              ; cx = count string pixels
.pixel_row_loop:
    cmp cx, CHAR_H
    jge .pixel_row_done

    push cx
    mov ax, cx
    mov bx, BYTES_PER_LINE
    mul bx                  ; ax = cx * 80
    add ax, [.base_off]
    mov di, ax              ; di = adress in es (video memory)

    mov bx, [.width]
.invert_byte_loop:
    test bx, bx
    jz .invert_byte_done
    mov al, [es:di]
    mov al, 0xFF
    mov [es:di], al
    inc di
    dec bx
    jmp .invert_byte_loop

.invert_byte_done:
    pop cx
    inc cx
    jmp .pixel_row_loop

.pixel_row_done:
    pop ax
    inc ax
    jmp .row_loop

.done:
    mov dx, 0x3CE
    mov al, 3
    out dx, al
    inc dx
    xor al, al
    out dx, al

    mov byte [SelDrawn], 1

    popa
    ret

.norm_r1  dw 0
.norm_r2  dw 0
.norm_c1  dw 0
.norm_c2  dw 0
.base_off dw 0
.width    dw 0

cursor_arm_vga:
    push ax
    push dx
    mov dx, 0x3CE
    mov al, 0x01
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x05
    out dx, al
    inc dx
    xor al, al
    out dx, al
    dec dx
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    pop dx
    pop ax
    ret

PickCursorColor:
    pusha
    mov si, BackgroundBuffer
    xor di, di
    xor bx, bx
.plane:
    xor bp, bp
    mov cx, HCURSOR * 2
.byte:
    mov al, [si]
    inc si
    mov dl, 8
.bit:
    shl al, 1
    adc bp, 0
    dec dl
    jnz .bit
    dec cx
    jnz .byte

    mov ax, bx
    and ax, 1
    jz .weigh
    add di, bp
.weigh:
    add di, bp
    inc bx
    cmp bx, 4
    jl .plane

    cmp di, HCURSOR * 16 * 3
    jb .dark
    mov byte [CursorColor], 0
    popa
    ret
.dark:
    mov byte [CursorColor], 15
    popa
    ret

SaveBackground:
    pusha
    call cursor_arm_vga
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov si, ax
    mov dx, 0x3CE
    mov al, 4
    out dx, al
    inc dx
    mov di, BackgroundBuffer
    xor bx, bx
.save_plane:
    mov al, bl
    out dx, al
    push si
    mov cx, HCURSOR
.save_row:
    mov al, [es:si]
    mov [di], al
    mov al, [es:si+1]
    mov [di+1], al
    add di, 2
    add si, 80
    loop .save_row
    pop si
    inc bx
    cmp bx, 4
    jl .save_plane
    popa
    ret

RestoreBackground:
    pusha
    call cursor_arm_vga
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov si, BackgroundBuffer
    xor bx, bx
.restore_plane:
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    push di
    mov cx, HCURSOR
.restore_row:
    mov al, [si]
    mov [es:di], al
    mov al, [si+1]
    mov [es:di+1], al
    add si, 2
    add di, 80
    loop .restore_row
    pop di
    inc bx
    cmp bx, 4
    jl .restore_plane
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    popa
    ret

DrawCursor:
    pusha
    call cursor_arm_vga
    mov ax, 0xA000
    mov es, ax
    mov ax, [MouseY]
    mov bx, 80
    mul bx
    mov bx, [MouseX]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov ax, [MouseX]
    and ax, 7
    mov cx, 8
    sub cx, ax
    mov [.shcnt], cl
    xor bx, bx
.draw_plane:
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    mov dx, 0x3CE
    mov al, 4
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    mov al, [CursorColor]
    mov cl, bl
    shr al, cl
    and al, 1
    mov [.planebit], al
    mov si, [CursorPtr]
    push di
    mov cx, HCURSOR
.draw_row:
    push cx
    mov al, [si]
    xor ah, ah
    mov cl, [.shcnt]
    shl ax, cl
    cmp byte [.planebit], 0
    je .clear_row
    mov dl, [es:di]
    or dl, ah
    mov [es:di], dl
    mov dl, [es:di+1]
    or dl, al
    mov [es:di+1], dl
    jmp .row_done
.clear_row:
    not ax
    mov dl, [es:di]
    and dl, ah
    mov [es:di], dl
    mov dl, [es:di+1]
    and dl, al
    mov [es:di+1], dl
.row_done:
    inc si
    add di, 80
    pop cx
    loop .draw_row
    pop di
    inc bx
    cmp bx, 4
    jl .draw_plane
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    popa
    ret
.shcnt   db 0
.planebit db 0

HideCursor:
    call RestoreBackground
    ret

; ==================================================================
; MOUSE_DOS_BEGIN - hand the mouse to a DOS program.
; ==================================================================
mouse_dos_begin:
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    cmp byte [CursorVisible], 0
    je .already_hidden
    call HideCursor
    mov byte [CursorVisible], 0
.already_hidden:
    mov byte [SelEnabled], 0
    call m33_reset_state
    call DisableMouse
    pop es
    pop ds
    ret

; ==================================================================
; MOUSE_DOS_END - take the mouse back once the program has exited
; ==================================================================
mouse_dos_end:
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov byte [SelEnabled], 1
    mov byte [CursorVisible], 1
    call m33_reset_state
    call EnableMouse
    pop es
    pop ds
    ret

ShowCursor:
    pusha
    call SaveBackground
    call PickCursorColor
    mov si, mousebmp
    mov al, 0x0F
    call DrawCursor
    popa
    ret

noMouse:
    ret


GetSelection:
    cmp byte [SelDrawn], 0
    je .no_selection

    mov ax, [SelStartRow]
    mov bx, [SelEndRow]
    mov cx, [SelStartCol]
    mov dx, [SelEndCol]

    cmp ax, bx
    jle .rows_norm
    xchg ax, bx
.rows_norm:
    cmp cx, dx
    jle .cols_norm
    xchg cx, dx
.cols_norm:
    clc
    ret

.no_selection:
    stc
    ret

section .data

MOUSEFAIL   db "An unexpected error happened!", 0
MOUSEINITOK db "Mouse initialized!", 0x0F, 0

ButtonStatus dw 0
MouseX       dw 0
MouseY       dw 0

MouseCol     dw 0
MouseRow     dw 0

PrevLMB       db 0
CursorVisible db 1
CursorPtr     dw mousebmp
CursorColor   db 15

SelStartRow  dw 0
SelStartCol  dw 0
SelEndRow    dw 0
SelEndCol    dw 0


SelActive    db 0
SelDrawn     db 0
SelEnabled   db 1            ; 1 = drag-select rectangle enabled, 0 = disabled

mousebmp:
    db 0b10000000
    db 0b11000000
    db 0b11100000
    db 0b11110000
    db 0b11111000
    db 0b11111100
    db 0b11111110
    db 0b11111000
    db 0b11011100
    db 0b10001110
    db 0b00000110

resizebmp:
    db 0b00000011
    db 0b00000011
    db 0b00000011
    db 0b00000011
    db 0b00000011
    db 0b00000011
    db 0b00000011
    db 0b11111111
    db 0b11111111
    db 0b00000000
    db 0b00000000

section .bss
BackgroundBuffer resb 88
