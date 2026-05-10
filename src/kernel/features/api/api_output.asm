; ==================================================================
; x16-PRos - Kernel Output API (Interrupt-Driven)
; Copyright (C) 2025 PRoX2011
;
; Provides output functions via INT 0x21
; Function codes in AH:
;   0x00: Re-Initialize output system (sets video mode)
;   0x01: Print string (white, SI = string pointer)
;   0x02: Print string (green, SI = string pointer)
;   0x03: Print string (cyan, SI = string pointer)
;   0x04: Print string (red, SI = string pointer)
;   0x05: Print newline
;   0x06: Clear screen
;   0x07: Set color (BL = color code)
;   0x08: Print string with current color (SI = string pointer)
;   0x09: CP866 control (AL=0x00 disable, AL=0x01 default font, AL=0x02 by name SI)
;   0x0A: Get system time (OUT: CH=hour, CL=min, DH=sec)
;   0x0B: Get system date (OUT: CH=century, CL=year, DH=month, DL=day)
;   0x0С: Clear screen and aply theme from CONF.DIR/THEME.CFG
; Preserves all registers unless specified
; ==================================================================

section .data
current_color db 0x0F    ; Default color: White

section .text

api_output_init:
    pusha
    push es
    push ds
    xor ax, ax
    mov es, ax
    mov word [es:0x21*4], int21_handler
    mov word [es:0x21*4+2], cs
    pop ds
    pop es
    popa
    ret

int21_handler:
    pusha
    push ds
    push es

    mov [cs:caller_ds_save_21], ds

    mov bp, cs
    mov ds, bp
    mov es, bp
    cld

    cmp ah, 0x00
    je .init
    cmp ah, 0x01
    je .print_white
    cmp ah, 0x02
    je .print_green
    cmp ah, 0x03
    je .print_cyan
    cmp ah, 0x04
    je .print_red
    cmp ah, 0x05
    je .newline
    cmp ah, 0x06
    je .clear_screen
    cmp ah, 0x07
    je .set_color
    cmp ah, 0x08
    je .print_current_color
    cmp ah, 0x09
    je .cp866_control
    cmp ah, 0x0A
    je .get_time
    cmp ah, 0x0B
    je .get_date
    cmp ah, 0x0C
    je .clear_screen_themed
    jmp .done

.init:
    call set_video_mode
    jmp .done

.print_white:
    mov bp, [caller_ds_save_21]
    mov ds, bp
    call print_string
    jmp .done

.print_green:
    mov bp, [caller_ds_save_21]
    mov ds, bp
    call print_string_green
    jmp .done

.print_cyan:
    mov bp, [caller_ds_save_21]
    mov ds, bp
    call print_string_cyan
    jmp .done

.print_red:
    mov bp, [caller_ds_save_21]
    mov ds, bp
    call print_string_red
    jmp .done

.newline:
    call print_newline
    jmp .done

.clear_screen:
    call set_video_mode
    jmp .done

.clear_screen_themed:
    call string_clear_screen
    jmp .done

.set_color:
    mov [current_color], bl
    jmp .done

.print_current_color:
    mov bl, [current_color]
    mov bp, [caller_ds_save_21]
    mov ds, bp
    call print_string_color
    jmp .done

.cp866_control:
    cmp al, 0x00
    je .font_disable
    cmp al, 0x01
    je .font_load_def
    cmp al, 0x02
    je .font_load_name
    jmp .done
.font_disable:
    call font_restore
    jmp .done
.font_load_def:
    call font_load_default
    jmp .done
.font_load_name:
    call copy_caller_string_si_21
    call font_load_file
    jmp .done

.get_time:
    call timezone_get_local_datetime
    mov bp, sp
    mov ch, [timezone_local_hour]
    mov cl, [timezone_local_minute]
    mov [bp+16], cx
    mov dh, [timezone_local_second]
    xor dl, dl
    mov [bp+14], dx
    jmp .done

.get_date:
    call timezone_get_local_datetime
    mov bp, sp
    mov ch, [timezone_local_century]
    mov cl, [timezone_local_year]
    mov [bp+16], cx
    mov dh, [timezone_local_month]
    mov dl, [timezone_local_day]
    mov [bp+14], dx
    jmp .done

.done:
    pop es
    pop ds
    popa
    iret

; ========================================================================
; copy_caller_string_si_21 -- copy NUL-terminated string from
;     [caller_ds_save_21:SI] to kernel scratch and update SI.
; OUT: SI = offset of scratch (in kernel DS).
; Preserves: AX, BX, CX, DX, DI.
; ========================================================================
copy_caller_string_si_21:
    push ax
    push di
    push es
    push ds

    push cs
    pop es
    mov di, .scratch

    mov ax, [cs:caller_ds_save_21]
    mov ds, ax
.cl:
    lodsb
    stosb
    test al, al
    jnz .cl

    pop ds
    pop es
    pop di
    pop ax
    mov si, .scratch
    ret

.scratch times 64 db 0

caller_ds_save_21 dw 0