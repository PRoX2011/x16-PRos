; ==================================================================
; x16-PRos - BMP rendering for x16-PRos in VGA mode 0x13 (320x200, 256 colors) 
; Copyright (C) 2025 PRoX2011
;
; ==================================================================

; Constants
BMP_MAX_WIDTH       equ 320
BMP_HEADER_SIZE     equ 54
BMP_PALETTE_SIZE    equ 1024 ; 256 colors * 4 bytes
BMP_HEADER_WIDTH    equ 18   ; Offset 0x12 in BMP header
BMP_HEADER_HEIGHT   equ 22   ; Offset 0x16 in BMP header

; Data section
_bmpSingleLine      times BMP_MAX_WIDTH db 0
_palSet             db 0  ; Palette set flag (0 = not set, 1 = set)
bmp_width           dw 0
bmp_height          dw 0
padding             dw 0

; ===================== BMP Viewing Command with Upscale Option =====================

view_bmp:
    call DisableMouse
    pusha
    
    ; Parse parameters
    mov word si, [param_list]
    call string_string_parse
    cmp ax, 0
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.filename_provided:
    ; Check if upscale parameter is provided
    mov word [.upscale_flag], 0
    cmp bx, 0
    je .no_upscale_param
    
    mov si, bx
    mov di, .upscale_param
    call string_string_compare
    jc .set_upscale

.no_upscale_param:
    jmp .load_file

.set_upscale:
    mov word [.upscale_flag], 1

.load_file:
    mov ax, [param_list]
    call fs_file_exists
    jc .not_found
    
    mov ax, [param_list]
    mov cx, 32768
    call fs_load_file
    mov word [file_size], bx
    cmp bx, 0
    je .empty_file

    ; Switch to VGA mode 0x13 (320x200, 256 colors)
    mov ax, 0x13
    int 0x10

    ; Load and display BMP with or without upscaling
    push bx
    mov si, 32768    ; Point to loaded file data
    
    cmp word [.upscale_flag], 1
    je .display_upscaled
    
    call display_bmp
    jmp .display_done

.display_upscaled:
    call display_bmp_upscaled

.display_done:
    pop bx     
    
    ; Show resolution info
    mov dh, 0
    mov dl, 0
    call string_move_cursor

    mov si, resolution_msg
    call print_string

    ; Print width
    mov ax, [bmp_width]
    call print_decimal

    ; Print "x"
    mov si, resolution_x
    call print_string

    ; Print height
    mov ax, [bmp_height]
    call print_decimal

    ; Show upscale status if applicable
    cmp word [.upscale_flag], 1
    jne .wait_key
    
    mov si, .upscale_status
    call print_string_cyan

.wait_key:
    call wait_for_key

    ; Return to original video mode 0x12 (640x480, 16 colors)
    mov ax, 0x12
    int 0x10
    mov byte [_palSet], 0

    popa
    call EnableMouse
    jmp get_cmd

.not_found:
    mov si, notfound_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd

.empty_file:
    mov si, empty_file_msg
    call print_string_red
    call print_newline
    popa
    jmp get_cmd

.upscale_flag dw 0
.upscale_param db '-UPSCALE', 0
.upscale_status db ' (2x upscaled)', 0

; ===================== BMP Display Function without upscaling =====================

display_bmp:
    pusha
    mov ax, [si + BMP_HEADER_WIDTH]
    mov [bmp_width], ax
    mov ax, [si + BMP_HEADER_HEIGHT]
    mov [bmp_height], ax

    cmp byte [_palSet], 1
    je .skip_palette
    call set_palette
    mov byte [_palSet], 1

.skip_palette:
    xor dx, dx
    mov ax, [bmp_width]
    mov bx, 4
    div bx
    mov [padding], dx

    mov ax, 320
    sub ax, [bmp_width]
    shr ax, 1
    mov [x_offset], ax

    mov ax, 200
    sub ax, [bmp_height]
    shr ax, 1
    mov [y_offset], ax

    add si, BMP_HEADER_SIZE + BMP_PALETTE_SIZE
    mov cx, [bmp_height]
    mov dx, [bmp_height]
    dec dx
    add dx, [y_offset]
    mov bx, 0

.draw_row:
    push cx
    push dx
    push bx
    push si

    mov cx, [bmp_width]
    add cx, [padding]
    mov di, _bmpSingleLine
    push ds
    mov ax, 0x2000
    mov ds, ax
    rep movsb
    pop ds

    mov si, _bmpSingleLine
    mov cx, [bmp_width]
    mov bx, [x_offset]
.draw_pixel:
    lodsb
    push cx
    push dx
    push bx
    mov ah, 0x0C
    mov bh, 0
    mov cx, bx
    int 0x10
    pop bx
    pop dx
    pop cx
    inc bx
    loop .draw_pixel

    pop si
    pop bx
    pop dx
    pop cx
    add si, [bmp_width]
    add si, [padding]
    dec dx
    loop .draw_row

    popa
    ret

; ===================== 2x Upscaled BMP Display Function =====================

display_bmp_upscaled:
    pusha
    mov ax, [si + BMP_HEADER_WIDTH]
    mov [bmp_width], ax
    mov ax, [si + BMP_HEADER_HEIGHT]
    mov [bmp_height], ax

    cmp byte [_palSet], 1
    je .skip_palette
    call set_palette
    mov byte [_palSet], 1

.skip_palette:
    xor dx, dx
    mov ax, [bmp_width]
    mov bx, 4
    div bx
    mov [padding], dx

    mov ax, [bmp_width]
    shl ax, 1
    mov bx, 320
    sub bx, ax
    shr bx, 1
    mov [x_offset], bx

    mov ax, [bmp_height]
    shl ax, 1
    mov bx, 200
    sub bx, ax
    shr bx, 1
    mov [y_offset], bx

    add si, BMP_HEADER_SIZE + BMP_PALETTE_SIZE
    mov cx, [bmp_height]
    mov dx, [bmp_height]
    dec dx
    shl dx, 1
    add dx, [y_offset]
    mov bx, 0

.draw_row:
    push cx
    push dx
    push bx
    push si

    mov cx, [bmp_width]
    add cx, [padding]
    mov di, _bmpSingleLine
    push ds
    mov ax, 0x2000
    mov ds, ax
    rep movsb
    pop ds

    mov cx, 2
.row_repeat:
    push cx

    mov si, _bmpSingleLine
    mov cx, [bmp_width]
    mov bx, [x_offset]
.draw_pixel:
    lodsb
    push cx
    push dx
    push bx

    mov cx, 2
.pixel_repeat_h:
    push cx

    mov ah, 0x0C
    mov bh, 0
    mov cx, bx
    int 0x10

    inc bx
    pop cx
    loop .pixel_repeat_h

    pop bx
    add bx, 2
    pop dx
    pop cx
    loop .draw_pixel

    dec dx

    pop cx
    loop .row_repeat

    pop si
    pop bx
    pop dx
    pop cx
    add si, [bmp_width]
    add si, [padding]
    sub dx, 2
    loop .draw_row

    popa
    ret


set_palette:
    pusha
    add si, BMP_HEADER_SIZE  
    mov cx, 256
    mov dx, 3C8h
    mov al, 0
    out dx, al 
    inc dx 
.next_color:
    mov al, [si + 2] 
    shr al, 2
    out dx, al
    mov al, [si + 1] 
    shr al, 2
    out dx, al
    mov al, [si]  
    shr al, 2
    out dx, al
    add si, 4
    loop .next_color
    popa
    ret

empty_file_msg db 'Empty file', 0
resolution_msg db 'Resolution: ', 0
resolution_x db 'x', 0