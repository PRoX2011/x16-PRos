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
    call interactive_mode
    jmp exit

clear_screen:
    mov ax, 0x0012
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
    xor cx, cx

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

interactive_mode:
    cmp byte [data_count], 0
    jne .loop
    ret

.loop:
    call clear_screen
    call draw_diagram
    call show_status

    call wait_for_key

    cmp ah, 0x4B
    je .left

    cmp ah, 0x4D
    je .right

    cmp al, 27
    je .exit

    cmp al, '0'
    jb .loop
    cmp al, '9'
    ja .loop
    call input_value
    call save_to_file
    jmp .loop

.left:
    cmp byte [selected_index], 0
    je .loop
    dec byte [selected_index]
    jmp .loop

.right:
    movzx ax, byte [data_count]
    cmp ax, 0
    je .loop
    dec ax
    cmp byte [selected_index], al
    jae .loop
    inc byte [selected_index]
    jmp .loop

.exit:
    ret

input_value:
    mov di, temp_buffer
    mov byte [di], al
    sub byte [di], '0'
    inc di

    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10

.read_digit:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D
    je .apply

    cmp al, 0x08
    je .backspace

    cmp al, '0'
    jb .read_digit
    cmp al, '9'
    ja .read_digit

    mov si, temp_buffer
    mov bx, di
    sub bx, si
    cmp bx, 3
    jae .read_digit

    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10

    sub al, '0'
    stosb
    jmp .read_digit

.backspace:
    mov si, temp_buffer
    cmp di, si
    je .read_digit
    inc si
    cmp di, si
    je .read_digit

    dec di
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_digit

.apply:
    mov si, temp_buffer
    xor ax, ax
    xor bx, bx

.calc_loop:
    cmp si, di
    jae .calc_done
    mov bl, 10
    mul bl
    mov bl, [si]
    add al, bl
    inc si
    jmp .calc_loop

.calc_done:
    cmp ax, 200
    ja .done

    movzx bx, byte [selected_index]
    mov si, data_buffer
    add si, bx
    mov [si], al

.done:
    ret

show_status:
    mov dh, 28
    mov dl, 0
    mov bh, 0
    mov ah, 0x02
    int 0x10

    mov si, status_msg
    call print_string

    movzx bx, byte [selected_index]
    mov al, [data_buffer + bx]
    call print_number

    ret

print_number:
    xor cx, cx
    mov bl, 10

.divide:
    xor ah, ah
    div bl
    push ax
    inc cx
    cmp al, 0
    jne .divide

.print:
    pop ax
    mov al, ah
    add al, '0'
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    loop .print
    ret

parse_input:
    mov si, input_buffer
    mov di, data_buffer
    xor cx, cx

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
    mov [data_count], cl
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
    mov ah, 0
    mov dl, 10
    mul dl
    add al, bl
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
    movzx cx, byte [data_count]
    int 0x22
    ret

load_file:
    mov ah, 0x02
    mov si, filename
    mov cx, data_buffer
    int 0x22
    jc .error
    mov [data_count], bl
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

    movzx cx, byte [data_count]
    cmp cx, 0
    je .done

    mov si, data_buffer
    mov bx, 50
    xor dh, dh

.draw_bar:
    lodsb
    mov ah, 0
    mov di, ax
    shl di, 1

    cmp dh, [selected_index]
    jne .normal_color
    mov al, 0x0C
    jmp .set_color

.normal_color:
    mov al, 0x0E

.set_color:
    mov ah, 0x0C

    push cx
    push bx
    push dx

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

    pop dx
    pop bx
    pop cx
    add bx, 35
    inc dh
    loop .draw_bar

.done:
    ret

wait_for_key:
    mov ah, 0x00
    int 0x16
    ret

print_string:
    mov ah, 0x0E
    mov bh, 0
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
    mov ax, 0x0012
    int 0x10
    ret

welcome_msg    db '-PRos Bar Chart Program v0.2-', 13,10,0
input_prompt   db 'Enter numbers (0-200, use space between, Enter to finish): ',0
menu_msg       db 13,10,"1 - Load file",13,10,"2 - New input",13,10,"> ",0
error_load_msg db "File not found! Press any key...",0
status_msg     db "Selected value: ",0

selected_index db 0
input_buffer   db 51 dup(0)
data_buffer    db 20 dup(0)
data_count     db 0

filename       db "DATA.BIN",0
temp_buffer    db 4 dup(0)