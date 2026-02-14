[BITS 16]
[ORG 0x8000]

start:
    cmp si, 0
    je .use_default
    cmp byte [si], 0
    je .use_default
    
    push si
    mov di, filename
    call copy_string
    pop si
    
.use_default:
    call clear_screen
    call draw_interface
    call show_menu

    cmp al, '1'
    je .load

    cmp al, '2'
    je .input

    jmp start

.load:
    call load_file
    jc .load_error
    jmp .draw

.load_error:
    call clear_screen
    mov si, error_load_msg
    call print_string
    call wait_for_key
    jmp start

.input:
    call get_user_input
    call parse_input
    call create_file
    call save_to_file

.draw:
    call draw_diagram
    call wait_for_key
    call clear_screen
    jmp exit

clear_screen:
    mov ax, 0x12
    int 0x10
    ret

draw_interface:
    mov si, welcome_msg
    call print_string
    mov si, input_prompt
    call print_string
    ret

get_user_input:
    mov di, input_buffer
    mov cx, 0

.read_char:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace
    cmp cx, 50
    je .read_char

    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10

    stosb
    inc cx
    jmp .read_char

.backspace:
    cmp cx, 0
    je .read_char
    dec cx
    dec di

    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_char

.done:
    mov byte [di], 0
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

parse_input:
    mov si, input_buffer
    mov di, data_buffer
    mov cx, 0

.parse_loop:
    call skip_spaces
    cmp byte [si], 0
    je .done
    call parse_number
    jc .done
    cmp al, 200
    ja .parse_loop
    stosb
    inc cx
    cmp cx, 20
    je .done
    jmp .parse_loop

.done:
    mov [data_count], cx
    ret

skip_spaces:
    mov al, [si]
    cmp al, ' '
    jne .done
    inc si
    jmp skip_spaces
.done:
    ret

parse_number:
    xor ax, ax
    xor bx, bx
    xor dx, dx

.read_digit:
    mov bl, [si]
    cmp bl, 0
    je .finish
    cmp bl, ' '
    je .finish
    cmp bl, '0'
    jb .error
    cmp bl, '9'
    ja .error

    sub bl, '0'
    mov ah, 10
    mul ah
    jc .error
    add al, bl
    jc .error
    inc si
    jmp .read_digit

.finish:
    inc si
    clc
    ret

.error:
    stc
    ret

create_file:
    mov ah, 0x05
    mov si, filename
    int 0x22
    ret

save_to_file:
    mov ah, 0x03
    mov si, filename
    mov bx, data_buffer
    mov cx, [data_count]
    int 0x22
    ret

load_file:
    mov ah, 0x02
    mov si, filename
    mov cx, data_buffer
    int 0x22
    jc .error
    mov [data_count], bx
    clc
    ret
.error:
    stc
    ret

draw_diagram:
    mov ah, 0x0C
    mov al, 0x0F
    mov cx, 10
    mov dx, 450

.draw_x_axis:
    int 0x10
    inc cx
    cmp cx, 600
    jle .draw_x_axis

    mov cx, 10
    mov dx, 40
.draw_y_axis:
    int 0x10
    inc dx
    cmp dx, 450
    jle .draw_y_axis

    mov cx, [data_count]
    cmp cx, 0
    je .done

    mov si, data_buffer
    mov bx, 50

.draw_bar:
    lodsb
    mov ah, 0
    mov di, ax
    shl di, 1

    mov ah, 0x0C
    mov al, 0x0E
    push cx
    push bx

    mov cx, bx
    add bx, 25

.width_loop:
    mov dx, 450
    sub dx, di
    cmp dx, 40
    jge .height_loop
    mov dx, 40

.height_loop:
    int 0x10
    inc dx
    cmp dx, 450
    jl .height_loop

    inc cx
    cmp cx, bx
    jl .width_loop

    pop bx
    pop cx
    add bx, 35
    loop .draw_bar

.done:
    ret

wait_for_key:
    mov ah, 0x00
    int 0x16
    ret

print_string:
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x0F
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret

show_menu:
    mov si, menu_msg
    call print_string

    mov ah, 0x00
    int 0x16

    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10

    ret

copy_string:
    push ax
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0x0D
    je .done
    cmp al, 0x0A
    je .done
    cmp al, ' '
    je .check_end
    stosb
    jmp .loop
.check_end:
    cmp byte [si], 0
    je .done
    cmp byte [si], 0x0D
    je .done
    stosb
    jmp .loop
.done:
    mov byte [di], 0
    pop ax
    ret

exit:
    ret

welcome_msg    db '-PRos Bar Chart Program v0.2-', 0x0D, 0x0A, 0
input_prompt   db 'Enter numbers (0-200, use space between, Enter to finish): ', 0
menu_msg       db 13,10,"1 - Load file",13,10,"2 - New input (press space and enter the data)",13,10,"> ",0
error_load_msg db "File not found! Press any key...",0

input_buffer   db 51 dup(0)
data_buffer    db 20 dup(0)
data_count     dw 0
filename       db "DATA.bin",0
