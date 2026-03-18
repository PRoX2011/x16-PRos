; ==================================================================
; x16-PRos - BMP rendering for x16-PRos in VGA mode 0x13 (320x200, 256 colors)
; Copyright (C) 2025 PRoX2011
;
; Uses direct VGA memory writes at 0xA000 for fast rendering.
; Supports large BMP files via fs_load_huge_file (segment-based loading).
; ==================================================================

; Constants
BMP_MAX_WIDTH       equ 320
BMP_HEADER_SIZE     equ 54
BMP_PALETTE_SIZE    equ 1024 ; 256 colors * 4 bytes
BMP_HEADER_WIDTH    equ 18   ; Offset 0x12 in BMP header
BMP_HEADER_HEIGHT   equ 22   ; Offset 0x16 in BMP header
BMP_LOAD_SEG        equ 0x3000
VGA_SEG             equ 0xA000
VGA_WIDTH           equ 320
VGA_HEIGHT          equ 200

; Data section
_bmpSingleLine      times BMP_MAX_WIDTH db 0
_palSet             db 0  ; Palette set flag (0 = not set, 1 = set)
bmp_width           dw 0
bmp_height          dw 0
padding             dw 0
bmp_src_seg         dw 0
bmp_src_off         dw 0
bmp_pixel_seg       dw 0
bmp_pixel_off       dw 0

; ===================== BMP Viewing Command with Options =====================

view_bmp:
    call DisableMouse
    pusha

    ; Parse parameters
    mov word si, [param_list]
    call string_string_parse
    test ax, ax
    jne .filename_provided
    mov si, nofilename_msg
    call print_string_red
    call print_newline
    popa
    call print_newline
    jmp get_cmd

.filename_provided:
    ; Initialize flags
    mov word [.upscale_flag], 0
    mov word [.stretch_flag], 0

    ; Check first parameter
    test bx, bx
    je .check_third_param

    mov si, bx
    mov di, .upscale_param
    call string_string_compare
    jc .set_upscale_first

    mov si, bx
    mov di, .stretch_param
    call string_string_compare
    jc .set_stretch_first

    jmp .check_third_param

.set_upscale_first:
    mov word [.upscale_flag], 1
    jmp .check_third_param

.set_stretch_first:
    mov word [.stretch_flag], 1

.check_third_param:
    ; Check if there's a third parameter
    test cx, cx
    je .load_file

    mov si, cx
    mov di, .upscale_param
    call string_string_compare
    jc .set_upscale_second

    mov si, cx
    mov di, .stretch_param
    call string_string_compare
    jc .set_stretch_second

    jmp .load_file

.set_upscale_second:
    mov word [.upscale_flag], 1
    jmp .load_file

.set_stretch_second:
    mov word [.stretch_flag], 1

.load_file:
    ; Check if both upscale and stretch are set (conflict)
    cmp word [.upscale_flag], 1
    jne .no_conflict
    cmp word [.stretch_flag], 1
    jne .no_conflict

    ; Show warning about conflicting flags
    mov si, .conflict_msg
    call print_string_yellow
    call print_newline
    ; Stretch takes priority
    mov word [.upscale_flag], 0

.no_conflict:
    mov ax, [param_list]
    call fs_file_exists
    jc .not_found

    mov ax, [param_list]
    xor cx, cx
    mov dx, BMP_LOAD_SEG
    call fs_load_huge_file
    jc .not_found
    ; DX:AX = file size
    or ax, ax
    jnz .has_data
    or dx, dx
    jz .empty_file
.has_data:

    ; Set up BMP source
    mov word [bmp_src_seg], BMP_LOAD_SEG
    mov word [bmp_src_off], 0

    ; Switch to VGA mode 0x13 (320x200, 256 colors)
    mov ax, 0x13
    int 0x10

    ; Load and display BMP based on flags
    cmp word [.stretch_flag], 1
    je .display_stretched

    cmp word [.upscale_flag], 1
    je .display_upscaled

    call display_bmp
    jmp .display_done

.display_upscaled:
    call display_bmp_upscaled
    jmp .display_done

.display_stretched:
    call display_bmp_stretched

.display_done:
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

    ; Show mode status
    cmp word [.stretch_flag], 1
    je .show_stretch_status

    cmp word [.upscale_flag], 1
    je .show_upscale_status

    jmp .wait_key

.show_upscale_status:
    mov si, .upscale_status
    call print_string_cyan
    jmp .wait_key

.show_stretch_status:
    mov si, .stretch_status
    call print_string_green

.wait_key:
    call wait_for_key

    ; Return to original video mode 0x12 (640x480, 16 colors)
    call set_video_mode
    call string_clear_screen

    mov byte [_palSet], 0

    popa
    call EnableMouse
    call string_clear_screen
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
.stretch_flag dw 0
.upscale_param db '-UPSCALE', 0
.stretch_param db '-STRETCH', 0
.upscale_status db ' (2x upscaled)', 0
.stretch_status db ' (stretched to fit)', 0
.conflict_msg db 'Warning: Cannot use -upscale and -stretch together. Using -stretch.', 0

; ===================== BMP Row Copy Helper =====================

bmp_copy_row:
    push es
    mov si, KERNEL_DATA_SEG
    mov es, si

    mov si, [bmp_src_off]

    mov ax, si
    add ax, cx
    jc .split_copy

    push ds
    mov ax, [bmp_src_seg]
    mov ds, ax
    rep movsb
    pop ds
    mov [bmp_src_off], si
    pop es
    ret

.split_copy:
    xor ax, ax
    sub ax, si
    push cx
    mov cx, ax
    push ax
    push ds
    mov ax, [bmp_src_seg]
    mov ds, ax
    rep movsb
    pop ds
    add word [bmp_src_seg], 0x1000

    pop ax
    pop cx
    sub cx, ax
    xor si, si
    push ds
    mov ax, [bmp_src_seg]
    mov ds, ax
    rep movsb
    pop ds
    mov [bmp_src_off], si
    pop es
    ret

; ===================== Padding Calculation =====================

bmp_calc_padding:
    xor dx, dx
    mov ax, [bmp_width]
    mov bx, 4
    div bx
    mov ax, 4
    sub ax, dx
    and ax, 3
    mov [padding], ax
    ret

; ===================== BMP Display Function without upscaling =====================

display_bmp:
    pusha

    ; Read header from BMP segment
    mov ax, [bmp_src_seg]
    mov si, [bmp_src_off]
    push ds
    mov ds, ax
    mov ax, [si + BMP_HEADER_WIDTH]
    mov bx, [si + BMP_HEADER_HEIGHT]
    pop ds
    mov [bmp_width], ax
    mov [bmp_height], bx

    cmp byte [_palSet], 1
    je .skip_palette
    call set_palette
    mov byte [_palSet], 1

.skip_palette:
    call bmp_calc_padding

    mov ax, VGA_WIDTH
    sub ax, [bmp_width]
    shr ax, 1
    mov [x_offset], ax

    mov ax, VGA_HEIGHT
    sub ax, [bmp_height]
    shr ax, 1
    mov [y_offset], ax

    ; Advance past header + palette
    mov ax, [bmp_src_off]
    add ax, BMP_HEADER_SIZE + BMP_PALETTE_SIZE
    mov [bmp_src_off], ax

    mov cx, [bmp_height]
    mov dx, [bmp_height]
    dec dx
    add dx, [y_offset]

.draw_row:
    push cx
    push dx

    ; Copy BMP row to line buffer
    mov cx, [bmp_width]
    add cx, [padding]
    mov di, _bmpSingleLine
    call bmp_copy_row

    ; Write line buffer directly to VGA memory
    pop dx
    push dx

    mov ax, dx
    mov bx, VGA_WIDTH
    mul bx                   ; AX = y * 320
    add ax, [x_offset]
    mov di, ax

    mov ax, VGA_SEG
    mov es, ax
    mov si, _bmpSingleLine
    mov cx, [bmp_width]
    rep movsb                ; write row to screen

    pop dx
    pop cx
    dec dx
    loop .draw_row

    popa
    ret

; ===================== 2x Upscaled BMP Display Function =====================
; Each BMP pixel becomes a 2x2 block on screen.

display_bmp_upscaled:
    pusha

    ; Read header from BMP segment
    mov ax, [bmp_src_seg]
    mov si, [bmp_src_off]
    push ds
    mov ds, ax
    mov ax, [si + BMP_HEADER_WIDTH]
    mov bx, [si + BMP_HEADER_HEIGHT]
    pop ds
    mov [bmp_width], ax
    mov [bmp_height], bx

    cmp byte [_palSet], 1
    je .skip_palette
    call set_palette
    mov byte [_palSet], 1

.skip_palette:
    call bmp_calc_padding

    mov ax, [bmp_width]
    shl ax, 1
    mov bx, VGA_WIDTH
    sub bx, ax
    shr bx, 1
    mov [x_offset], bx

    mov ax, [bmp_height]
    shl ax, 1
    mov bx, VGA_HEIGHT
    sub bx, ax
    shr bx, 1
    mov [y_offset], bx

    ; Advance past header + palette
    mov ax, [bmp_src_off]
    add ax, BMP_HEADER_SIZE + BMP_PALETTE_SIZE
    mov [bmp_src_off], ax

    mov cx, [bmp_height]
    mov dx, [bmp_height]
    dec dx
    shl dx, 1
    add dx, [y_offset]

.draw_row:
    push cx
    push dx

    ; Copy BMP row to line buffer
    mov cx, [bmp_width]
    add cx, [padding]
    mov di, _bmpSingleLine
    call bmp_copy_row

    ; Draw two screen rows per BMP row
    pop dx
    push dx

    ; --- First screen row (y = DX) ---
    mov ax, dx
    mov bx, VGA_WIDTH
    mul bx
    add ax, [x_offset]
    mov di, ax
    mov ax, VGA_SEG
    mov es, ax
    mov si, _bmpSingleLine
    mov cx, [bmp_width]
.up_row1:
    lodsb
    stosb
    stosb                    ; 2x horizontal
    loop .up_row1

    ; --- Second screen row (y = DX - 1) ---
    pop dx
    push dx
    dec dx
    mov ax, dx
    mov bx, VGA_WIDTH
    mul bx
    add ax, [x_offset]
    mov di, ax
    mov ax, VGA_SEG
    mov es, ax
    mov si, _bmpSingleLine
    mov cx, [bmp_width]
.up_row2:
    lodsb
    stosb
    stosb
    loop .up_row2

    pop dx
    pop cx
    sub dx, 2
    loop .draw_row

    popa
    ret

; ===================== Stretched BMP Display Function =====================

display_bmp_stretched:
    pusha

    ; Read header from BMP segment
    mov ax, [bmp_src_seg]
    mov si, [bmp_src_off]
    push ds
    mov ds, ax
    mov ax, [si + BMP_HEADER_WIDTH]
    mov bx, [si + BMP_HEADER_HEIGHT]
    pop ds
    mov [bmp_width], ax
    mov [bmp_height], bx

    cmp byte [_palSet], 1
    je .skip_palette
    call set_palette
    mov byte [_palSet], 1

.skip_palette:
    call bmp_calc_padding

    mov ax, [bmp_src_off]
    add ax, BMP_HEADER_SIZE + BMP_PALETTE_SIZE
    mov [bmp_pixel_off], ax
    mov ax, [bmp_src_seg]
    mov [bmp_pixel_seg], ax

    mov ax, _bmpSingleLine
    cmp word [bmp_width], BMP_MAX_WIDTH
    jbe .buf_ok
    mov ax, program_load_addr
.buf_ok:
    mov [.row_buffer], ax

    mov word [.screen_y], 0
    mov word [.src_row], 0xFFFF

.draw_row:
    mov ax, [.screen_y]
    mul word [bmp_height]
    mov bx, VGA_HEIGHT
    div bx

    mov bx, [bmp_height]
    dec bx
    sub bx, ax
    mov ax, bx

    cmp ax, [.src_row]
    je .same_row

    mov [.src_row], ax

    mov bx, [bmp_width]
    add bx, [padding]
    mul bx

    add ax, [bmp_pixel_off]
    adc dx, 0

    mov [bmp_src_off], ax

    mov cl, 12
    shl dx, cl
    mov ax, [bmp_pixel_seg]
    add ax, dx
    mov [bmp_src_seg], ax

    mov cx, [bmp_width]
    add cx, [padding]
    mov di, [.row_buffer]
    call bmp_copy_row

.same_row:
    mov ax, VGA_SEG
    mov es, ax
    mov ax, [.screen_y]
    mov bx, VGA_WIDTH
    mul bx
    mov di, ax

    xor bx, bx
.draw_pixel:
    mov ax, bx
    mul word [bmp_width]
    mov cx, VGA_WIDTH
    div cx

    mov si, [.row_buffer]
    add si, ax
    mov al, [si]
    stosb

    inc bx
    cmp bx, VGA_WIDTH
    jl .draw_pixel

    inc word [.screen_y]
    cmp word [.screen_y], VGA_HEIGHT
    jl .draw_row

    popa
    ret

.screen_y  dw 0
.src_row   dw 0
.row_buffer dw 0

; ===================== Palette Setup =====================

set_palette:
    pusha
    mov ax, [bmp_src_seg]
    mov si, [bmp_src_off]
    add si, BMP_HEADER_SIZE
    push ds
    mov ds, ax
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
    pop ds
    popa
    ret

empty_file_msg db 'Empty file', 0
resolution_msg db 'Resolution: ', 0
resolution_x db 'x', 0