; ==================================================================
; x16-PRos -- PAINT. Very simple paint program.
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
; BMP configuration
; =======================
BMP_BUF_SEG     equ 0x4000
BMP_PIXEL_OFF   equ 1078
BMP_FILE_SIZE   equ 65078

MODE_COL        equ 7

; =======================
; Program start
; =======================
start:
    mov ah, 0x06
    int 0x21

    mov byte [CurrentColor], 0x0F
    mov byte [BrushSize], 1
    mov byte [DrawMode], 0
    mov byte [modified], 0

    call font_init

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

    call draw_frame
    call draw_status

    call InitMouse
    call EnableMouse

main_loop:
    mov ah, 0x01
    int 0x16
    jz check_mouse

    mov ah, 0x00
    int 0x16

    cmp al, 0x09              ; TAB
    jne .ck_color
    call clear_preview
    xor byte [DrawMode], 1
    call draw_status
    jmp main_loop

.ck_color:
    cmp al, '0'
    jb .ck_keys
    cmp al, '9'
    ja .ck_keys
    sub al, '0'
    mov bx, ColorTable
    xlatb
    mov [CurrentColor], al
    jmp main_loop

.ck_keys:
    cmp al, 'w'
    je inc_size
    cmp al, 'W'
    je inc_size
    cmp al, 's'
    je dec_size
    cmp al, 'S'
    je dec_size

    cmp al, 0x13              ; Ctrl+S
    je save_image

    cmp al, 0x1B              ; ESC
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
; Exit logic (FINAL)
; =======================
exit_paint:
    cmp byte [modified], 0
    je .do_exit

    mov ax, exit_q1
    mov bx, exit_q2
    xor cx, cx
    mov dx, 1
    call tui_dialog_box

    cmp ax, 0
    jne .do_exit

    call save_image

.do_exit:
    mov ax, 0x12
    int 0x10
    ret

exit_q1 db 'Save this image before exit?', 0
exit_q2 db 'Unsaved changes will be lost.', 0

; =======================
; Painting logic
; =======================
check_mouse:
    mov al, [ButtonStatus]
    test al, 1
    jz main_loop

    mov cx, [MouseX]
    mov dx, [MouseY]
    sub dx, 2

    call plot_brush
    mov byte [modified], 1
    jmp main_loop

; =======================
; Draw frame
; =======================
draw_frame:
    pusha
    mov dx, CANVAS_Y - 1
    mov cx, CANVAS_X - 1
.top:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc cx
    cmp cx, CANVAS_RIGHT + 2
    jl .top
    mov dx, CANVAS_BOTTOM + 1
    mov cx, CANVAS_X - 1
.bot:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc cx
    cmp cx, CANVAS_RIGHT + 2
    jl .bot
    popa
    ret

; =======================
; Save image (Save As)
; =======================
save_image:
    call DisableMouse
    call HideCursor

    mov byte [save_filename_buf], 0
    mov ax, save_prompt
    mov di, save_filename_buf
    mov si, 16
    call tui_input_dialog
    jc .done

    cmp byte [save_filename_buf], 0
    je .done

    ; (BMP creation code unchanged)
    ; ---- YOUR EXISTING BMP SAVE CODE HERE ----

    mov byte [modified], 0

.done:
    call EnableMouse
    jmp main_loop

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
    cmp byte [DrawMode], 1
    jne .show
    mov si, mode_line_str
.show:
    mov cl, MODE_COL
    mov ch, 29
    mov bl, 0x4F
    call font_print_string

    popa
    ret

; =======================
; Data
; =======================
CurrentColor  db 0
BrushSize     db 1
DrawMode      db 0
modified      db 0

ColorTable db 0x00,0x0F,0x01,0x03,0x02,0x04,0x05,0x0E,0x07,0x08

welcome_msg db '        - PRos Paint -  1-9 buttons - Change color  W,S - Change size of brush',13,10,0

status_text    db ' Mode: XXXX  TAB toggle mode  Ctrl+S Save  ESC Exit', 0
mode_free_str  db 'FREE', 0
mode_line_str  db 'LINE', 0

save_prompt db 'Save as (e.g. PAINT.BMP):', 0

save_filename_buf times 17 db 0

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"
section .text
%include "src/drivers/ps2_mouse.asm"
