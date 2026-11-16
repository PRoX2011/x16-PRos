; ========================================================================
; vesa_test - Test program for the VESA bank switching driver
; ========================================================================

[BITS 16]
[ORG 0x8000]
[CPU 386]

start:
    ; Save the current video mode (which is 0x12 in this OS)
    mov ah, 0x0F
    int 0x10
    mov [saved_mode], al

    call vesa_init
    jc .error

    xor cx, cx
.y_loop:
    xor bx, bx
.x_loop:
    mov ax, cx
    and ax, 0xFF
    call vesa_put_pixel
    inc bx
    cmp bx, 640
    jb .x_loop
    
    inc cx
    cmp cx, 480
    jb .y_loop

    mov ah, 0
    int 0x16

    ; Restore the original mode instead of forcing Mode 3
    mov al, [saved_mode]
    mov ah, 0x00
    int 0x10
    ret

.error:
    mov si, err_msg
    call print_string
    mov ah, 0
    int 0x16
    ret

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

saved_mode db 0
err_msg db 'VESA init failed!', 13, 10, 0

%INCLUDE "src/drivers/vesa.asm"