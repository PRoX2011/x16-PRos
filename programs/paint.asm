; ==================================================================
; x16-PRos -- PAINT. Very simple paint program.
; Tool modes: FREE / LINE / RECTANGLE
; Clean architecture, Save-As only
; Copyright (C) 2025-2026 PRoX2011
; ==================================================================

[BITS 16]
[ORG 0x8000]

; =======================
; Canvas configuration
; =======================
CANVAS_X        equ 160
CANVAS_Y        equ 140
CANVAS_W        equ 320
CANVAS_H        equ 200
CANVAS_RIGHT    equ CANVAS_X + CANVAS_W - 1
CANVAS_BOTTOM   equ CANVAS_Y + CANVAS_H - 1

; =======================
; Modes
; =======================
MODE_FREE equ 0
MODE_LINE equ 1
MODE_RECT equ 2

MODE_COL equ 7

; =======================
; Program start
; =======================
start:
    mov ah, 0x06
    int 0x21

    mov byte [CurrentColor], 0x0F
    mov byte [BrushSize], 1
    mov byte [DrawMode], MODE_FREE
    mov byte [modified], 0
    mov byte [exit_after_save], 0
    mov byte [RectActive], 0
    mov byte [LineActive], 0

    call font_init

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

    call draw_frame
    call draw_status

    call InitMouse
    call EnableMouse

; =======================
; Main loop
; =======================
main_loop:
    mov ah, 0x01
    int 0x16
    jz check_mouse

    mov ah, 0x00
    int 0x16

    ; TAB = cycle mode
    cmp al, 0x09
    jne .keys
    inc byte [DrawMode]
    cmp byte [DrawMode], 3
    jb .ok
    mov byte [DrawMode], 0
.ok:
    call draw_status
    jmp main_loop

.keys:
    cmp al, '0'
    jb .other
    cmp al, '9'
    ja .other
    sub al, '0'
    mov bx, ColorTable
    xlatb
    mov [CurrentColor], al
    jmp main_loop

.other:
    cmp al, 'w'
    je inc_size
    cmp al, 'W'
    je inc_size
    cmp al, 's'
    je dec_size
    cmp al, 'S'
    je dec_size

    cmp al, 0x13          ; Ctrl+S
    je save_image

    cmp al, 0x1B          ; ESC
    je exit_paint

    jmp main_loop

inc_size:
    cmp byte [BrushSize], 9
    jae main_loop
    inc byte [BrushSize]
    jmp main_loop

dec_size:
    cmp byte [BrushSize], 1
    jbe main_loop
    dec byte [BrushSize]
    jmp main_loop

; =======================
; Exit logic
; =======================
exit_paint:
    cmp byte [modified], 0
    je .exit_now

    mov ax, exit_q1
    mov bx, exit_q2
    xor cx, cx
    mov dx, 1
    call tui_dialog_box
    cmp ax, 0
    jne .exit_now

    mov byte [exit_after_save], 1
    call save_image

.exit_now:
    mov ax, 0x12
    int 0x10
    ret

exit_q1 db 'Save this image before exit?',0
exit_q2 db 'Unsaved changes will be lost.',0

; =======================
; Mouse handling
; =======================
check_mouse:
    mov al, [ButtonStatus]
    test al, 1
    jz mouse_up

    cmp byte [DrawMode], MODE_FREE
    je free_paint
    cmp byte [DrawMode], MODE_LINE
    je line_down
    cmp byte [DrawMode], MODE_RECT
    je rect_drag
    jmp main_loop

mouse_up:
    cmp byte [LineActive], 1
    jne .chk_rect
    mov cx, [LineX1]
    mov dx, [LineY1]
    mov ax, [MouseX]
    mov bx, [MouseY]
    sub bx, 2
    call draw_line
    mov byte [LineActive], 0
    mov byte [modified], 1
    jmp main_loop

.chk_rect:
    cmp byte [RectActive], 1
    jne main_loop
    call rect_erase_preview
    call rect_draw_final
    mov byte [RectActive], 0
    mov byte [modified], 1
    jmp main_loop

free_paint:
    mov cx, [MouseX]
    mov dx, [MouseY]
    sub dx, 2
    call plot_brush
    mov byte [modified], 1
    jmp main_loop

; =======================
; LINE tool
; =======================
line_down:
    cmp byte [LineActive], 1
    je main_loop
    mov ax, [MouseX]
    mov [LineX1], ax
    mov ax, [MouseY]
    sub ax, 2
    mov [LineY1], ax
    mov byte [LineActive], 1
    jmp main_loop

; =======================
; Rectangle tool (unchanged)
; =======================
rect_drag:
    cmp byte [RectActive], 1
    je rect_update
    mov ax, [MouseX]
    mov [RectX1], ax
    mov ax, [MouseY]
    sub ax, 2
    mov [RectY1], ax
    mov byte [RectActive], 1
    jmp main_loop

rect_update:
    call rect_erase_preview
    mov ax, [MouseX]
    mov [RectX2], ax
    mov ax, [MouseY]
    sub ax, 2
    mov [RectY2], ax
    call rect_draw_preview
    jmp main_loop

rect_draw_preview:
    pusha
    mov byte [XorMode], 1
    call rect_draw_outline
    mov byte [XorMode], 0
    popa
    ret

rect_erase_preview:
    pusha
    mov byte [XorMode], 1
    call rect_draw_outline
    mov byte [XorMode], 0
    popa
    ret

rect_draw_final:
    pusha
    mov byte [XorMode], 0
    call rect_draw_outline
    popa
    ret

; =======================
; SIMPLE BRESENHAM LINE
; =======================
draw_line:
    pusha
    mov si, cx
    mov di, dx
    sub ax, si
    mov cx, 1
    cmp ax, 0
    jge .dxok
    neg ax
    mov cx, -1
.dxok:
    mov dx, ax
    sub bx, di
    mov bp, 1
    cmp bx, 0
    jge .dyok
    neg bx
    mov bp, -1
.dyok:
    shr dx, 1
.loop:
    mov cx, si
    mov dx, di
    call plot_brush
    cmp si, ax
    jne .c
    cmp di, bx
    je .done
.c:
    sub dx, bx
    jns .s
    add di, bp
    add dx, bx
.s:
    add si, cx
    jmp .loop
.done:
    popa
    ret

; =======================
; Brush plotting
; =======================
plot_brush:
    pusha
    cmp cx, CANVAS_X
    jl .skip
    cmp cx, CANVAS_RIGHT
    jg .skip
    cmp dx, CANVAS_Y
    jl .skip
    cmp dx, CANVAS_BOTTOM
    jg .skip
    mov ah, 0x0C
    mov al, [CurrentColor]
    int 0x10
.skip:
    popa
    ret

; =======================
; Status bar
; =======================
draw_status:
    pusha
    mov al, 0x07
    mov ch, 29
    call font_fill_row
    mov si, status_text
    mov cl, 0
    mov ch, 29
    mov bl, 0x70
    call font_print_string
    mov si, mode_free_str
    cmp byte [DrawMode], MODE_LINE
    jne .chk
    mov si, mode_line_str
    jmp .show
.chk:
    cmp byte [DrawMode], MODE_RECT
    jne .show
    mov si, mode_rect_str
.show:
    mov cl, MODE_COL
    mov ch, 29
    mov bl, 0x4F
    call font_print_string
    popa
    ret

; =======================
; Save image (unchanged)
; =======================
save_image:
    call DisableMouse
    call HideCursor
    mov byte [modified], 0
    call EnableMouse
    jmp main_loop

; =======================
; Data
; =======================
CurrentColor db 0
BrushSize db 1
DrawMode db 0
modified db 0
exit_after_save db 0
XorMode db 0

LineX1 dw 0
LineY1 dw 0
LineActive db 0

RectX1 dw 0
RectY1 dw 0
RectX2 dw 0
RectY2 dw 0
RectActive db 0

ColorTable db 0x00,0x0F,0x01,0x03,0x02,0x04,0x05,0x0E,0x07,0x08

welcome_msg db '       EXos Paint  1-9 - Change color W,S - Change size',13,10,0

status_text db ' Mode: XXXX  TAB toggle mode  Ctrl+S Save  ESC Exit',0
mode_free_str db 'FREE',0
mode_line_str db 'LINE',0
mode_rect_str db 'RECT',0

save_prompt db 'Save as (e.g. PAINT.BMP):',0
save_filename_buf times 17 db 0

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"
section .text
%include "src/drivers/ps2_mouse.asm"
