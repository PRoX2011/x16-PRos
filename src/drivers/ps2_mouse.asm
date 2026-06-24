; ==================================================================
; x16-PRos - Universal PS/2 & COM (Serial) Mouse Driver
; Copyright (C) 2025 PRoX2011
;
; Driver version: 0.3 (Auto-detection PS/2 -> COM1 -> COM2)
;
; Compatible with video modes:
;   - 0x12  (VGA, 640x480, 16 colors, planar)
; ==================================================================

; --- Compatibility Aliases ---
InitMouse           equ init_mouse
EnableMouse         equ enable_mouse
DisableMouse        equ disable_mouse
HideCursor          equ hide_cursor
ShowCursor          equ show_cursor
GetSelection        equ get_selection

MouseX              equ mouse_x
MouseY              equ mouse_y
MouseCol            equ mouse_col
MouseRow            equ mouse_row
ButtonStatus        equ button_status
CursorVisible       equ cursor_visible
SelEnabled          equ sel_enabled
; -----------------------------

CURSOR_W            equ 8
CURSOR_H            equ 11

CHAR_W              equ 8
CHAR_H              equ 16
COLS                equ 80
ROWS                equ 30

BYTES_PER_LINE      equ 80

MOUSE_TYPE_NONE     equ 0
MOUSE_TYPE_PS2      equ 1
MOUSE_TYPE_COM1     equ 2
MOUSE_TYPE_COM2     equ 3

section .text

init_mouse:
    ; Attempt PS/2 initialization via BIOS interrupt
    int 0x11
    test ax, 0x04
    jz .try_com1
    mov ax, 0xC205
    mov bh, 0x03
    int 0x15
    jc .try_com1
    mov ax, 0xC203
    mov bh, 0x03
    int 0x15
    jc .try_com1

    mov byte [mouse_type], MOUSE_TYPE_PS2
    ret

.try_com1:
    ; Attempt COM1 initialization (base 0x3F8, IRQ 4)
    mov dx, 0x3F8
    call detect_com_mouse
    jc .try_com2
    mov byte [mouse_type], MOUSE_TYPE_COM1
    mov word [com_port], 0x3F8
    ret

.try_com2:
    ; Attempt COM2 initialization (base 0x2F8, IRQ 3)
    mov dx, 0x2F8
    call detect_com_mouse
    jc .no_mouse
    mov byte [mouse_type], MOUSE_TYPE_COM2
    mov word [com_port], 0x2F8
    ret

.no_mouse:
    mov byte [mouse_type], MOUSE_TYPE_NONE
    ret

; ========================================================================
; DETECT_COM_MOUSE - Autodetects a Microsoft Serial Protocol mouse
; IN:  DX = Base COM port address (e.g., 0x3F8)
; OUT: CF = Clear on success, set if no mouse found
;
; NOTE: Initializes the serial port to 1200 baud, 7N1 format, then checks 
;       for the 'M' identification byte transmitted by Microsoft mice.
; ========================================================================
detect_com_mouse:
    pusha
    mov bx, dx              ; Save base port

    ; Setup UART to 1200 baud, 7N1 (standard for MS serial mice)
    mov dx, bx
    add dx, 3               ; LCR (Line Control Register)
    mov al, 0x80            ; Enable DLAB to access divisor latch
    out dx, al

    mov dx, bx              ; DLL (Divisor Latch Low)
    mov al, 0x60            ; 115200 / 1200 = 96 = 0x0060
    out dx, al

    mov dx, bx
    inc dx                  ; DLH (Divisor Latch High)
    mov al, 0x00
    out dx, al

    mov dx, bx
    add dx, 3               ; LCR
    mov al, 0x02            ; 7 data bits, 1 stop bit, no parity, DLAB = 0
    out dx, al

    ; Disable UART interrupts temporarily
    mov dx, bx
    inc dx                  ; IER (Interrupt Enable Register)
    mov al, 0x00
    out dx, al

    ; Reset mouse by toggling DTR and RTS low
    mov dx, bx
    add dx, 4               ; MCR (Modem Control Register)
    mov al, 0x00
    out dx, al

    ; Wait 50 ms for hardware reset logic
    mov dx, 50              
    call delay_ms

    ; Power on the mouse (assert DTR, RTS) and enable OUT2 for interrupts
    mov dx, bx
    add dx, 4               
    mov al, 0x0B            
    out dx, al

    ; Wait up to 500 ms for the 'M' (0x4D) identification byte
    mov cx, 500             
.wait_for_m:
    mov dx, bx
    add dx, 5               ; LSR (Line Status Register)
    in al, dx
    test al, 0x01           ; Check Data Ready bit
    jnz .read_char

    mov dx, 1
    call delay_ms
    loop .wait_for_m
    jmp .not_found

.read_char:
    mov dx, bx              ; RBR (Receiver Buffer Register)
    in al, dx
    cmp al, 'M'             
    je .found

    ; If we got garbage, continue waiting for 'M'
    loop .wait_for_m        

.not_found:
    popa
    stc
    ret

.found:
    ; Clear remaining bytes in the FIFO buffer
    mov dx, bx
    add dx, 5
.drain:
    in al, dx
    test al, 0x01
    jz .done_drain
    mov dx, bx
    in al, dx               
    mov dx, bx
    add dx, 5
    jmp .drain
.done_drain:
    popa
    clc
    ret

enable_mouse:
    cmp byte [mouse_type], MOUSE_TYPE_PS2
    je .en_ps2
    cmp byte [mouse_type], MOUSE_TYPE_COM1
    je .en_com1
    cmp byte [mouse_type], MOUSE_TYPE_COM2
    je .en_com2
    ret

.en_ps2:
    call disable_mouse
    mov ax, 0xC207
    mov bx, ps2_mouse_callback
    int 0x15
    mov ax, 0xC200
    mov bh, 0x01
    int 0x15
    ret

.en_com1:
    call disable_mouse
    cli
    mov ax, 0
    mov es, ax
    mov word [es:0x0C * 4], com_interrupt_handler  ; Set IRQ 4 vector
    mov word [es:0x0C * 4 + 2], cs
    
    in al, 0x21
    and al, 0xEF                                   ; Unmask IRQ 4 in PIC1
    out 0x21, al
    sti

    mov dx, 0x3F8 + 1                              ; Enable data available interrupt
    mov al, 0x01
    out dx, al
    ret

.en_com2:
    call disable_mouse
    cli
    mov ax, 0
    mov es, ax
    mov word [es:0x0B * 4], com_interrupt_handler  ; Set IRQ 3 vector
    mov word [es:0x0B * 4 + 2], cs
    
    in al, 0x21
    and al, 0xF7                                   ; Unmask IRQ 3 in PIC1
    out 0x21, al
    sti

    mov dx, 0x2F8 + 1                              
    mov al, 0x01
    out dx, al
    ret

disable_mouse:
    cmp byte [mouse_type], MOUSE_TYPE_PS2
    je .dis_ps2
    cmp byte [mouse_type], MOUSE_TYPE_COM1
    je .dis_com1
    cmp byte [mouse_type], MOUSE_TYPE_COM2
    je .dis_com2
    ret

.dis_ps2:
    mov ax, 0xC200
    mov bh, 0x00
    int 0x15
    mov ax, 0xC207
    int 0x15
    ret

.dis_com1:
    mov dx, 0x3F8 + 1
    mov al, 0x00
    out dx, al
    in al, 0x21
    or al, 0x10                                    ; Mask IRQ 4 in PIC1
    out 0x21, al
    ret

.dis_com2:
    mov dx, 0x2F8 + 1
    mov al, 0x00
    out dx, al
    in al, 0x21
    or al, 0x08                                    ; Mask IRQ 3 in PIC1
    out 0x21, al
    ret

; ========================================================================
; PS2_MOUSE_CALLBACK - Called by BIOS INT 15h handler
; IN:  Stack parameters matching BIOS PS/2 callback specification
; OUT: None
; ========================================================================
ps2_mouse_callback:
    push bp
    mov bp, sp
    pusha
    push es
    push ds
    push cs
    pop ds

    ; Decode 3-byte PS/2 packet format
    mov al, [bp + 12]
    mov bl, al
    mov cl, 3
    shl al, cl
    sbb dh, dh
    cbw
    mov dl, [bp + 8]        ; Y data 
    mov al, [bp + 10]       ; X data
    
    ; PS/2 returns +Y for UP, but our screen coords use +Y for DOWN
    neg dx                  

    call update_mouse_position

    pop ds
    pop es
    popa
    pop bp
    retf

; ========================================================================
; COM_INTERRUPT_HANDLER - IRQ handler for serial mouse
; IN:  None (Hardware IRQ)
; OUT: None
; ========================================================================
com_interrupt_handler:
    pusha
    push ds
    push es

    mov ax, cs
    mov ds, ax
    mov es, ax

    mov dx, [com_port]
    in al, dx               
    mov bl, al

    ; Bit 6 indicates start of a 3-byte packet in MS Serial Protocol
    test bl, 0x40
    jz .not_first

    ; Process byte 1
    mov [com_byte_1], bl
    mov byte [com_state], 1
    jmp .send_eoi

.not_first:
    cmp byte [com_state], 1
    jne .check_third

    ; Process byte 2
    mov [com_byte_2], bl
    mov byte [com_state], 2
    jmp .send_eoi

.check_third:
    cmp byte [com_state], 2
    jne .send_eoi

    ; Process byte 3 and decode entire packet
    mov [com_byte_3], bl
    mov byte [com_state], 0

    ; Decode X delta: (byte1[1:0] << 6) | byte2[5:0]
    mov al, [com_byte_1]
    and al, 0x03
    shl al, 6
    mov cl, [com_byte_2]
    and cl, 0x3F
    or al, cl
    cbw
    mov cx, ax              

    ; Decode Y delta: (byte1[3:2] << 4) | byte3[5:0]
    mov al, [com_byte_1]
    and al, 0x0C
    shl al, 4
    mov dl, [com_byte_3]
    and dl, 0x3F
    or al, dl
    cbw
    mov dx, ax              

    ; Decode buttons (Bit 5 in byte 1 determines left mouse button)
    mov al, [com_byte_1]
    mov bl, al
    shr bl, 5
    and bl, 1               

    mov ax, cx              
    call update_mouse_position

.send_eoi:
    mov al, 0x20            ; End Of Interrupt signal to PIC1
    out 0x20, al

    pop es
    pop ds
    popa
    iret

; ========================================================================
; UPDATE_MOUSE_POSITION - Unified cursor logic for all mouse types
; IN:  AX = Delta X
;      DX = Delta Y (positive is downwards)
;      BL = Button status (Bit 0 = Left mouse button)
; OUT: None
;
; NOTE: Updates cursor coordinates, handles screen bounds, and processes
;       selection drag logic.
; ========================================================================
update_mouse_position:
    cmp byte [cursor_visible], 0
    je .skip_hide
    call hide_cursor
.skip_hide:

    mov cx, [mouse_y]
    add dx, cx
    mov cx, [mouse_x]
    add ax, cx

    ; Constrain X coordinate
    cmp ax, 0
    jge .check_x_max
    xor ax, ax
.check_x_max:
    cmp ax, 639 - CURSOR_W
    jle .check_y_min
    mov ax, 639 - CURSOR_W

.check_y_min:
    ; Constrain Y coordinate
    cmp dx, 0
    jge .check_y_max
    xor dx, dx
.check_y_max:
    cmp dx, 479 - CURSOR_H
    jle .update_pos
    mov dx, 479 - CURSOR_H

.update_pos:
    mov [button_status], bl  
    mov [mouse_x], ax
    mov [mouse_y], dx

    ; Calculate text column
    mov ax, [mouse_x]
    shr ax, 3
    mov [mouse_col], ax

    ; Calculate text row
    mov ax, [mouse_y]
    xor dx, dx
    mov cx, CHAR_H
    div cx                  
    mov [mouse_row], ax

    mov al, [button_status]
    and al, 0x01

    ; Exit early if graphical text selection is disabled
    cmp byte [sel_enabled], 0
    je .draw_cursor_and_exit        

    mov ah, [prev_lmb]
    mov [prev_lmb], al

    cmp al, ah
    je .button_held

    test al, al
    jnz .button_pressed
    jmp .button_released

.button_pressed:
    call erase_selection
    mov ax, [mouse_col]
    mov [sel_start_col], ax
    mov [sel_end_col], ax
    mov ax, [mouse_row]
    mov [sel_start_row], ax
    mov [sel_end_row], ax
    mov byte [sel_drawn], 0
    mov byte [sel_active], 1
    jmp .draw_cursor_and_exit

.button_released:
    mov byte [sel_active], 0
    jmp .draw_cursor_and_exit

.button_held:
    test al, al
    jz .draw_cursor_and_exit

    mov ax, [mouse_col]
    mov bx, [mouse_row]
    cmp ax, [sel_end_col]
    jne .sel_changed
    cmp bx, [sel_end_row]
    je .draw_cursor_and_exit

.sel_changed:
    call erase_selection
    mov ax, [mouse_col]
    mov [sel_end_col], ax
    mov ax, [mouse_row]
    mov [sel_end_row], ax
    call draw_selection

.draw_cursor_and_exit:
    cmp byte [cursor_visible], 0
    je .silent_exit
    call save_background
    mov si, mouse_bmp
    mov al, 0x0F
    call draw_cursor
.silent_exit:
    ret

erase_selection:
    cmp byte [sel_drawn], 1
    jne .nothing_to_erase
    call draw_selection
    mov byte [sel_drawn], 0
.nothing_to_erase:
    ret

draw_selection:
    pusha

    mov ax, [sel_start_row]
    mov bx, [sel_end_row]
    mov cx, [sel_start_col]
    mov dx, [sel_end_col]

    ; Normalize rows string
    cmp ax, bx
    jle .rows_ok
    xchg ax, bx
.rows_ok:
    mov [.norm_r1], ax
    mov [.norm_r2], bx

    ; Normalize columns string
    cmp cx, dx
    jle .cols_ok
    xchg cx, dx
.cols_ok:
    mov [.norm_c1], cx
    mov [.norm_c2], dx

    ; Setup VGA registers for XOR operation
    mov dx, 0x3CE
    mov al, 3
    out dx, al
    inc dx
    mov al, 0x18            
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

    ; Middle rows span entire width
    xor si, si              
    mov di, COLS - 1        
    jmp .invert_range

.first_row_multi:
    mov si, [sel_start_col]
    mov di, COLS - 1
    jmp .invert_range

.last_row_multi:
    xor si, si
    mov di, [sel_end_col]
    jmp .invert_range

.single_row:
    mov si, [.norm_c1]
    mov di, [.norm_c2]

.invert_range:
    push si
    push di

    ; Calculate memory offset
    mov bx, ax
    mov ax, CHAR_H
    mul bx                  
    mov bx, BYTES_PER_LINE  
    mul bx                  

    pop di
    pop si

    add ax, si
    mov [.base_off], ax
    
    mov bx, di
    sub bx, si
    inc bx
    mov [.width], bx

    mov ax, 0xA000
    mov es, ax              

    xor cx, cx              
.pixel_row_loop:
    cmp cx, CHAR_H
    jge .pixel_row_done

    push cx
    mov ax, cx
    mov bx, BYTES_PER_LINE
    mul bx                  
    add ax, [.base_off]
    mov di, ax              

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
    ; Restore standard VGA drawing mode
    mov dx, 0x3CE
    mov al, 3
    out dx, al
    inc dx
    xor al, al
    out dx, al

    mov byte [sel_drawn], 1

    popa
    ret

.norm_r1  dw 0
.norm_r2  dw 0
.norm_c1  dw 0
.norm_c2  dw 0
.base_off dw 0
.width    dw 0

save_background:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [mouse_y]
    mov bx, 80
    mul bx
    mov bx, [mouse_x]
    shr bx, 3
    add ax, bx
    mov si, ax
    mov dx, 0x3CE
    mov al, 4
    out dx, al
    inc dx
    mov di, background_buffer
    mov bx, 0
.save_plane:
    mov al, bl
    out dx, al
    push si
    mov cx, CURSOR_H
.save_row:
    mov al, [es:si]
    mov [di], al
    inc di
    add si, 80
    loop .save_row
    pop si
    inc bx
    cmp bx, 4
    jl .save_plane
    popa
    ret

restore_background:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [mouse_y]
    mov bx, 80
    mul bx
    mov bx, [mouse_x]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov si, background_buffer
    mov bx, 0
.restore_plane:
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    push di
    mov cx, CURSOR_H
.restore_row:
    mov al, [si]
    mov [es:di], al
    inc si
    add di, 80
    loop .restore_row
    pop di
    inc bx
    cmp bx, 4
    jl .restore_plane
    popa
    ret

draw_cursor:
    pusha
    mov ax, 0xA000
    mov es, ax
    mov ax, [mouse_y]
    mov bx, 80
    mul bx
    mov bx, [mouse_x]
    shr bx, 3
    add ax, bx
    mov di, ax
    mov dx, 0x3C4
    mov al, 2
    out dx, al
    inc dx
    mov si, mouse_bmp
    mov bx, 0
.draw_plane:
    mov al, 1
    mov cl, bl
    shl al, cl
    out dx, al
    push di
    push si
    mov cx, CURSOR_H
.draw_row:
    mov ah, [es:di]
    mov al, [si]
    or ah, al
    mov [es:di], ah
    inc si
    add di, 80
    loop .draw_row
    pop si
    pop di
    inc bx
    cmp bx, 4
    jl .draw_plane
    popa
    ret

hide_cursor:
    call restore_background
    ret

show_cursor:
    pusha
    call save_background
    mov si, mouse_bmp
    mov al, 0x0F
    call draw_cursor
    popa
    ret

get_selection:
    cmp byte [sel_drawn], 0
    je .no_selection

    mov ax, [sel_start_row]
    mov bx, [sel_end_row]
    mov cx, [sel_start_col]
    mov dx, [sel_end_col]

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

mouse_type:    db 0    
com_port:      dw 0
com_state:     db 0
com_byte_1:    db 0
com_byte_2:    db 0
com_byte_3:    db 0

button_status: dw 0
mouse_x:       dw 0
mouse_y:       dw 0

mouse_col:     dw 0
mouse_row:     dw 0

prev_lmb:      db 0
cursor_visible:db 1

sel_start_row: dw 0
sel_start_col: dw 0
sel_end_row:   dw 0
sel_end_col:   dw 0

sel_active:    db 0
sel_drawn:     db 0
sel_enabled:   db 1            

mouse_bmp:
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

section .bss
background_buffer: resb 44
