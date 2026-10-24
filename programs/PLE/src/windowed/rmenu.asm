%include "ple.inc"

PLE_HEADER start, "Default launcher", "ZypherCode"
PLE_LOGO          "logo/hello.raw"

start:
    push cs
    pop ds
    push cs
    pop es

    call surf_sync
    cmp byte [surf_windowed], 1
    jne .fullscreen

    call get_list

.wloop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .quit
    cmp byte [surf_dirty], 0
    call redraw
    jmp .sleep
.sleep:
    mov ah, 0x14
    mov cx, 5
    int 0x23
    jmp .wloop
.quit:
    mov ah, 0x12
    int 0x23
    jmp .quit
.fullscreen:
    call paint
.wait:
    xor ah, ah
    int 0x16
    cmp al, 27
    jne .wait
    mov ah, 0x0C
    int 0x21
    retf

redraw:
    mov ah, 0x22
    int 0x23
    call paint
    mov ah, 0x23
    int 0x23
    ret

paint:
    pusha
    
    call surf_input
    cmp byte [surf_mb], 1
    jne .no_pressed

    ; get pointer to selected filename
    ; si = ptr_array[selected]
    mov bh, 0
    mov bl, [selected]
    shl bx, 1 ; multiplied by 2, because the pointer occupies two bytes.
    mov si, [ptr_array + bx]

    ; parse 'FILE    PLE' into 'FILE.PLE'
    ; and put it to selected_filename
    xor cx, cx
    mov di, selected_filename
.copy_name_char:
    mov al, [si]
    cmp al, ' '
    je .continue
    mov [di], al
    inc di
.continue:
    inc si
    inc cx
    cmp cx, 8
    jne .copy_name_char

    mov byte [di], '.'

    inc di
    inc si
    mov al, [si]
    mov [di], al
    inc di
    inc si
    mov al, [si]
    mov [di], al
    inc di
    inc si
    mov al, [si]
    mov [di], al

    inc di
    mov byte [di], 0

    mov si, selected_filename
    mov ah, 0x11
    int 0x23

    popa
    jmp .quit
    
.no_pressed:
    mov cx, 0
    mov dx, 0
    mov si, [surf_w]
    mov di, [list_size]
    mov al, 1
    mov bx, ptr_array
    call surf_menu_hit
    cmp al, [selected]
    je .skip_refresh
    call surf_menu
    mov [selected], al

.skip_refresh:
    popa
    ret

.quit:
    mov ah, 0x12
    int 0x23
    jmp .quit

get_list:
    mov ah, 0x09
    mov si, ple_dir
    int 0x22

    mov ah, 0x09
    mov si, gui_dir
    int 0x22

    mov ah, 0x01
    mov si, list_buffer
    int 0x22

    mov cx, 0
    mov si, ptr_array
    mov bx, list_buffer
.fill_ptr_array:
    mov al, [bx]
    cmp al, 0
    je .return
    mov [si], bx
    mov byte [bx+12], 0
    add bx, 18
    add si, 2
    inc cx
    jmp .fill_ptr_array
.return:
    mov [list_size], cx
    call redraw
    ret

ple_dir db 'PLE.DIR', 0
gui_dir db 'GUI.DIR', 0

list_size dw 0
selected db 0
selected_filename resb 11
ptr_array resw 16
list_buffer resb 256

%include "grafx.inc"
%include "surf.inc"

PLE_END