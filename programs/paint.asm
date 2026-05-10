; ==================================================================
; x16-PRos -- PAINT. Very simple paint program.
; Copyright (C) 2025-2026 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

CANVAS_X        equ 160
CANVAS_Y        equ 140
CANVAS_W        equ 320
CANVAS_H        equ 200
CANVAS_RIGHT    equ CANVAS_X + CANVAS_W - 1
CANVAS_BOTTOM   equ CANVAS_Y + CANVAS_H - 1

BMP_BUF_SEG     equ 0x4000
BMP_PIXEL_OFF   equ 1078
BMP_FILE_SIZE   equ 65078

MODE_COL        equ 7

start:
    mov ah, 0x06
    int 0x21

    mov byte [CurrentColor], 0x0F
    mov byte [BrushSize], 1

    call font_init

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

    call draw_frame
    call draw_status

    call InitMouse
    mov byte [SelEnabled], 0
    call EnableMouse

programLoop:
    mov ah, 0x01
    int 0x16
    jz check_mouse

    mov ah, 0x00
    int 0x16

    cmp al, 0x09
    jne .nc_tab
    call clear_preview
    xor byte [DrawMode], 1
    call draw_status
    jmp check_mouse
.nc_tab:

    cmp al, '0'
    jb check_other_keys
    cmp al, '9'
    ja check_other_keys

    sub al, '0'
    mov bx, ColorTable
    xlatb
    mov [CurrentColor], al
    jmp check_mouse

check_other_keys:
    cmp al, 'w'
    je increase_size
    cmp al, 'W'
    je increase_size

    cmp al, 's'
    je decrease_size
    cmp al, 'S'
    je decrease_size

    cmp al, 0x13                ; Ctrl+S
    je save_image

    cmp al, 0x1B
    je exit

    jmp check_mouse

increase_size:
    cmp byte [BrushSize], 9
    jae check_mouse
    inc byte [BrushSize]
    jmp check_mouse

decrease_size:
    cmp byte [BrushSize], 1
    jbe check_mouse
    dec byte [BrushSize]
    jmp check_mouse

check_mouse:
    mov al, [ButtonStatus]
    and al, 0x01
    mov ah, [PaintPrevLMB]
    mov [PaintPrevLMB], al

    cmp al, ah
    je .same_state

    test al, al
    jz .released

    mov byte [PreviewActive], 0
    cmp byte [DrawMode], 0
    je paint

    mov ax, [MouseX]
    mov [DragX1], ax
    mov ax, [MouseY]
    sub ax, 2
    mov [DragY1], ax
    call HideCursor
    mov byte [CursorVisible], 0
    jmp programLoop

.released:
    cmp byte [DrawMode], 1
    je .end_line
    jmp programLoop

.end_line:
    call erase_preview
    mov byte [PreviewActive], 0
    mov ax, [DragX1]
    mov [draw_line.x1], ax
    mov ax, [DragY1]
    mov [draw_line.y1], ax
    mov ax, [MouseX]
    mov [draw_line.x2], ax
    mov ax, [MouseY]
    sub ax, 2
    mov [draw_line.y2], ax
    mov byte [XorMode], 0
    call draw_line
    mov byte [CursorVisible], 1
    call ShowCursor
    jmp programLoop

.same_state:
    test al, al
    jz programLoop
    cmp byte [DrawMode], 0
    jne .preview
    jmp paint

.preview:
    mov bx, [MouseX]
    mov ax, [MouseY]
    sub ax, 2

    cmp byte [PreviewActive], 0
    je .pv_redraw
    cmp bx, [PrevX2]
    jne .pv_redraw
    cmp ax, [PrevY2]
    jne .pv_redraw
    jmp programLoop

.pv_redraw:
    push ax
    push bx
    call erase_preview
    pop bx
    pop ax

    mov [PrevX2], bx
    mov [PrevY2], ax

    mov ax, [DragX1]
    mov [draw_line.x1], ax
    mov ax, [DragY1]
    mov [draw_line.y1], ax
    mov ax, [PrevX2]
    mov [draw_line.x2], ax
    mov ax, [PrevY2]
    mov [draw_line.y2], ax

    mov byte [XorMode], 1
    call draw_line
    mov byte [XorMode], 0
    mov byte [PreviewActive], 1
    jmp programLoop

paint:
    mov cx, [MouseX]
    mov dx, [MouseY]
    sub dx, 2

    mov al, [BrushSize]
    shr al, 1
    xor ah, ah
    sub cx, ax
    sub dx, ax

    mov si, [BrushSize]
    mov bh, 0

draw_row:
    mov di, [BrushSize]
    push cx

draw_column:
    cmp cx, CANVAS_X
    jl .skip_pixel
    cmp cx, CANVAS_RIGHT
    jg .skip_pixel
    cmp dx, CANVAS_Y
    jl .skip_pixel
    cmp dx, CANVAS_BOTTOM
    jg .skip_pixel

    mov ah, 0x0C
    mov al, [CurrentColor]
    int 0x10

.skip_pixel:
    inc cx
    dec di
    jnz draw_column

    pop cx
    inc dx
    dec si
    jnz draw_row

    jmp programLoop

exit:
    mov ax, 0x12
    int 0x10

    ret

; ==================================================================
; draw_frame -- Draw a white border around the canvas region
; Canvas is at (CANVAS_X, CANVAS_Y) .. (CANVAS_RIGHT, CANVAS_BOTTOM).
; Border is drawn one pixel outside that region.
; ==================================================================
draw_frame:
    pusha

    ; Top edge: y = CANVAS_Y - 1, x from CANVAS_X-1 to CANVAS_RIGHT+1
    mov dx, CANVAS_Y - 1
    mov cx, CANVAS_X - 1
.top:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc cx
    cmp cx, CANVAS_RIGHT + 2
    jl .top

    ; Bottom edge: y = CANVAS_BOTTOM + 1
    mov dx, CANVAS_BOTTOM + 1
    mov cx, CANVAS_X - 1
.bot:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc cx
    cmp cx, CANVAS_RIGHT + 2
    jl .bot

    ; Left edge: x = CANVAS_X - 1, y from CANVAS_Y to CANVAS_BOTTOM
    mov cx, CANVAS_X - 1
    mov dx, CANVAS_Y
.lft:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc dx
    cmp dx, CANVAS_BOTTOM + 1
    jle .lft

    ; Right edge: x = CANVAS_RIGHT + 1
    mov cx, CANVAS_RIGHT + 1
    mov dx, CANVAS_Y
.rgt:
    mov ah, 0x0C
    mov al, 0x0F
    int 0x10
    inc dx
    cmp dx, CANVAS_BOTTOM + 1
    jle .rgt

    popa
    ret

; ==================================================================
; save_image -- Save the canvas region to a BMP file (8bpp, 320x200)
; ==================================================================
save_image:
    call clear_preview
    call DisableMouse
    call HideCursor

    ; ---- Read 320x200 canvas pixels into BMP buffer ----
    push es
    mov ax, BMP_BUF_SEG
    mov es, ax

    mov di, BMP_PIXEL_OFF

    mov bx, CANVAS_BOTTOM
.row_read:
    mov cx, CANVAS_X
.col_read:
    push bx
    push cx
    push dx
    mov dx, bx
    mov ah, 0x0D
    mov bh, 0
    int 0x10
    pop dx
    pop cx
    pop bx

    mov [es:di], al
    inc di

    inc cx
    cmp cx, CANVAS_RIGHT + 1
    jl .col_read

    dec bx
    cmp bx, CANVAS_Y - 1
    jg .row_read

    pop es

    ; ---- Copy BMP file/info header into buffer ----
    push es
    push ds
    mov ax, BMP_BUF_SEG
    mov es, ax
    mov si, bmp_header_template
    xor di, di
    mov cx, BMP_HDR_LEN / 2
    rep movsw
    pop ds

    ; ---- Copy 16-color VGA palette, then zero-fill remaining 240 entries ----
    mov si, vga_palette
    mov di, BMP_HDR_LEN
    mov cx, 16 * 4 / 2              ; 16 entries × 4 bytes / word
    rep movsw

    xor ax, ax
    mov cx, (256 - 16) * 4 / 2
    rep stosw
    pop es

    mov byte [save_filename_buf], 0

    mov ax, save_prompt
    mov di, save_filename_buf
    mov si, 16
    call tui_input_dialog
    jc .save_done

    cmp byte [save_filename_buf], 0
    je .save_done

    mov ah, 0x0E
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov ah, 0x13
    mov si, save_filename_buf
    xor cx, cx
    mov dx, BMP_BUF_SEG
    mov bx, BMP_FILE_SIZE
    xor di, di
    int 0x22
    pushf

    mov ah, 0x0F
    int 0x22

    popf
    jc .save_fail

    mov ax, save_ok_l1
    mov bx, save_filename_buf
    xor cx, cx
    xor dx, dx
    call tui_dialog_box
    jmp .save_done

.save_fail:
    mov ax, save_err_l1
    mov bx, save_err_l2
    xor cx, cx
    xor dx, dx
    call tui_dialog_box

.save_done:
    mov ah, 0x06
    int 0x21

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

    call draw_frame
    call draw_status

    push es
    mov ax, BMP_BUF_SEG
    mov es, ax
    mov si, BMP_PIXEL_OFF

    mov bx, CANVAS_BOTTOM
.row_paint:
    mov cx, CANVAS_X
.col_paint:
    push bx
    push cx
    push dx
    mov al, [es:si]
    mov ah, 0x0C
    mov dx, bx
    mov bh, 0
    int 0x10
    pop dx
    pop cx
    pop bx
    inc si

    inc cx
    cmp cx, CANVAS_RIGHT + 1
    jl .col_paint

    dec bx
    cmp bx, CANVAS_Y - 1
    jg .row_paint
    pop es

    call EnableMouse
    jmp programLoop

; ==================================================================
; draw_line -- Draw a straight line from (.x1,.y1) to (.x2,.y2)
; ==================================================================
draw_line:
    pusha

    mov ax, [.x2]
    sub ax, [.x1]
    mov word [.sx], 1
    cmp ax, 0
    jge .dx_pos
    neg ax
    mov word [.sx], -1
.dx_pos:
    mov [.dx], ax

    mov ax, [.y2]
    sub ax, [.y1]
    mov word [.sy], 1
    cmp ax, 0
    jge .dy_pos
    neg ax
    mov word [.sy], -1
.dy_pos:
    mov [.dy], ax

    mov ax, [.dx]
    sub ax, [.dy]
    mov [.err], ax

    mov ax, [.x1]
    mov [.cx], ax
    mov ax, [.y1]
    mov [.cy], ax

.loop:
    mov cx, [.cx]
    mov dx, [.cy]
    call plot_brush

    mov ax, [.cx]
    cmp ax, [.x2]
    jne .step
    mov ax, [.cy]
    cmp ax, [.y2]
    je .done
.step:
    mov bx, [.err]
    add bx, bx

    mov ax, [.dy]
    neg ax
    cmp bx, ax
    jle .skip_x
    mov ax, [.dy]
    sub [.err], ax
    mov ax, [.sx]
    add [.cx], ax
.skip_x:
    cmp bx, [.dx]
    jge .skip_y
    mov ax, [.dx]
    add [.err], ax
    mov ax, [.sy]
    add [.cy], ax
.skip_y:
    jmp .loop

.done:
    popa
    ret

.x1  dw 0
.y1  dw 0
.x2  dw 0
.y2  dw 0
.dx  dw 0
.dy  dw 0
.sx  dw 0
.sy  dw 0
.err dw 0
.cx  dw 0
.cy  dw 0

plot_brush:
    pusha

    mov al, [BrushSize]
    xor ah, ah
    mov [.size], ax
    shr ax, 1
    sub cx, ax
    sub dx, ax

    mov al, [CurrentColor]
    test byte [XorMode], 1
    jz .pb_color_ok
    or al, 0x80
.pb_color_ok:
    mov [.color], al

    mov si, [.size]
.pb_row:
    mov di, [.size]
    push cx
.pb_col:
    cmp cx, CANVAS_X
    jl .pb_skip
    cmp cx, CANVAS_RIGHT
    jg .pb_skip
    cmp dx, CANVAS_Y
    jl .pb_skip
    cmp dx, CANVAS_BOTTOM
    jg .pb_skip
    mov ah, 0x0C
    mov al, [.color]
    mov bh, 0
    int 0x10
.pb_skip:
    inc cx
    dec di
    jnz .pb_col
    pop cx
    inc dx
    dec si
    jnz .pb_row

    popa
    ret

.size  dw 0
.color db 0

erase_preview:
    pusha
    cmp byte [PreviewActive], 0
    je .ep_done

    mov ax, [DragX1]
    mov [draw_line.x1], ax
    mov ax, [DragY1]
    mov [draw_line.y1], ax
    mov ax, [PrevX2]
    mov [draw_line.x2], ax
    mov ax, [PrevY2]
    mov [draw_line.y2], ax

    mov byte [XorMode], 1
    call draw_line
    mov byte [XorMode], 0
.ep_done:
    popa
    ret

clear_preview:
    pusha
    cmp byte [PreviewActive], 0
    je .cp_after_erase
    call erase_preview
    mov byte [PreviewActive], 0
.cp_after_erase:
    cmp byte [CursorVisible], 0
    jne .cp_done
    mov byte [CursorVisible], 1
    call ShowCursor
.cp_done:
    popa
    ret

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

CurrentColor  db 0
BrushSize     db 1
DrawMode      db 0  ; 0=free, 1=line
PaintPrevLMB  db 0
DragX1        dw 0
DragY1        dw 0
PreviewActive db 0
PrevX2        dw 0
PrevY2        dw 0
XorMode       db 0

; Table of correspondence of numbers to colors:
; 0 - black (0x00)
; 1 - white (0x0F)
; 2 - blue (0x01)
; 3 - cyan (0x03)
; 4 - green (0x02)
; 5 - red (0x04)
; 6 - purple (0x05)
; 7 - yellow (0x0E)
; 8 - light gray (0x07)
; 9 - dark gray (0x08)
ColorTable db 0x00, 0x0F, 0x01, 0x03, 0x02, 0x04, 0x05, 0x0E, 0x07, 0x08

welcome_msg    db '                             - PRos Paint v0.2 -', 13, 10,
               db '         Use 1-9 buttons to change colors and W, S to change brush size', 13, 10,
               db '              Ctrl+S to save as BMP, ESC to exit program', 0

; ==================================================================
; BMP file/info header template (54 bytes)
;   320x200, 8 bits/pixel, 256-color palette, top of pixel data at 0x436
; ==================================================================
bmp_header_template:
    ; BITMAPFILEHEADER (14 bytes)
    db 'BM'
    dd BMP_FILE_SIZE             ; total file size
    dw 0, 0                      ; reserved
    dd BMP_PIXEL_OFF             ; offset to pixel data (1078)
    ; BITMAPINFOHEADER (40 bytes)
    dd 40                        ; DIB header size
    dd CANVAS_W                  ; width
    dd CANVAS_H                  ; height
    dw 1                         ; planes
    dw 8                         ; bits per pixel
    dd 0                         ; compression (BI_RGB)
    dd CANVAS_W * CANVAS_H       ; image size
    dd 2835                      ; x pixels per meter (~72 DPI)
    dd 2835                      ; y pixels per meter
    dd 16                        ; colors used
    dd 0                         ; important colors
BMP_HDR_LEN equ $ - bmp_header_template

; 16-entry VGA palette in BMP order (B, G, R, 0)
vga_palette:
    db 0x00, 0x00, 0x00, 0x00    ; 0  black
    db 0xAA, 0x00, 0x00, 0x00    ; 1  blue
    db 0x00, 0xAA, 0x00, 0x00    ; 2  green
    db 0xAA, 0xAA, 0x00, 0x00    ; 3  cyan
    db 0x00, 0x00, 0xAA, 0x00    ; 4  red
    db 0xAA, 0x00, 0xAA, 0x00    ; 5  magenta
    db 0x00, 0x55, 0xAA, 0x00    ; 6  brown
    db 0xAA, 0xAA, 0xAA, 0x00    ; 7  light gray
    db 0x55, 0x55, 0x55, 0x00    ; 8  dark gray
    db 0xFF, 0x55, 0x55, 0x00    ; 9  light blue
    db 0x55, 0xFF, 0x55, 0x00    ; 10 light green
    db 0xFF, 0xFF, 0x55, 0x00    ; 11 light cyan
    db 0x55, 0x55, 0xFF, 0x00    ; 12 light red
    db 0xFF, 0x55, 0xFF, 0x00    ; 13 light magenta
    db 0x55, 0xFF, 0xFF, 0x00    ; 14 yellow
    db 0xFF, 0xFF, 0xFF, 0x00    ; 15 white

status_text    db ' Mode: XXXX  TAB toggle mode  Ctrl+S Save  ESC Exit', 0
mode_free_str  db 'FREE', 0
mode_line_str  db 'LINE', 0

save_prompt    db 'Save as (e.g. PAINT.BMP):', 0
save_ok_l1     db 'Image saved successfully:', 0
save_err_l1    db 'Error: failed to save the image.', 0
save_err_l2    db 'Check disk space and filename.', 0

save_filename_buf times 17 db 0

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"

section .text
%include "src/drivers/ps2_mouse.asm"