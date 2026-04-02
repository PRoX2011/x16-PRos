[BITS 16]
[ORG 0x8000]

CAL_LEFT    equ 10
CAL_TOP     equ 3
CELL_W      equ 6

start:
    mov ah, 0x0B
    int 0x21
    mov [current_month], dh

    push dx
    xor ah, ah
    mov al, ch
    mov bl, 100
    mul bl
    xor bh, bh
    mov bl, cl
    add ax, bx
    mov [current_year], ax
    pop dx

    jmp main_loop

main_loop:
    mov ah, 0x06
    int 0x21

    call draw_header
    call draw_grid
    call draw_weekdays
    call draw_days
    call draw_nav

    mov ah, 0x00
    int 0x16

    cmp ah, 0x4B
    je .go_prev
    cmp ah, 0x4D
    je .go_next
    cmp al, 27
    je .exit
    jmp main_loop

.go_prev:
    call prev_month
    jmp main_loop

.go_next:
    call next_month
    jmp main_loop

.exit:
	mov ah, 0x06
	int 0x21
    ret

set_cursor:
    push ax
    push bx
    mov ah, 0x02
    mov bh, 0
    int 0x10
    pop bx
    pop ax
    ret

print_char_attr:
    push ax
    push bx
    push cx
    mov ah, 0x09
    mov bh, 0
    mov cx, 1
    int 0x10
    mov ah, 0x0E
    int 0x10
    pop cx
    pop bx
    pop ax
    ret

print_str_attr:
    push ax
    push si
.lp:
    lodsb
    cmp al, 0
    je .done
    call print_char_attr
    jmp .lp
.done:
    pop si
    pop ax
    ret

print_year_ax:
    push ax
    push bx
    push cx
    push dx
    xor dx, dx
    mov cx, 1000
    div cx
    add al, '0'
    mov bl, 0x0E
    call print_char_attr
    mov ax, dx
    xor dx, dx
    mov cx, 100
    div cx
    add al, '0'
    call print_char_attr
    mov ax, dx
    xor dx, dx
    mov cx, 10
    div cx
    add al, '0'
    call print_char_attr
    mov al, dl
    add al, '0'
    call print_char_attr
    pop dx
    pop cx
    pop bx
    pop ax
    ret

get_days_in_month:
    push bx
    dec al
    xor ah, ah
    mov bx, ax
    mov al, [days_table + bx]
    pop bx
    ret

zeller:
    push bx
    push cx
    push dx

    xor ah, ah
    mov al, [current_month]
    mov bx, [current_year]
    cmp al, 3
    jge .no_adj
    add al, 12
    dec bx
.no_adj:
    mov [.m], al
    mov [.y], bx

    mov ax, bx
    xor dx, dx
    mov cx, 100
    div cx
    mov [.j], ax
    mov [.k], dx

    xor ah, ah
    mov al, [.m]
    inc al
    mov bl, 13
    mul bl
    mov bl, 5
    div bl
    xor ah, ah
    mov [.t], ax

    mov ax, [.k]
    shr ax, 2
    add ax, [.t]
    add ax, [.k]
    add ax, [.j]
    add ax, 5

    xor dx, dx
    mov cx, 7
    div cx
    mov al, dl

    pop dx
    pop cx
    pop bx
    ret

.m dw 0
.y dw 0
.j dw 0
.k dw 0
.t dw 0

draw_header:
    mov dh, 0
    mov dl, 20
    call set_cursor

    xor ah, ah
    mov al, [current_month]
    dec al
    shl al, 1
    mov bx, ax
    mov si, [month_ptrs + bx]
    mov bl, 0x0E
    call print_str_attr

    mov al, ' '
    call print_char_attr

    mov ax, [current_year]
    call print_year_ax
    ret

draw_grid:
    push ax
    push bx
    push cx
    push dx

    mov dh, CAL_TOP
    mov dl, CAL_LEFT
    call set_cursor

    mov cx, 42
.top:
    mov al, '-'
    mov bl, 0x08
    call print_char_attr
    loop .top

    mov byte [.r], 0
.row:
    cmp byte [.r], 6
    jae .done

    mov dh, CAL_TOP + 1
    add dh, [.r]
    mov dl, CAL_LEFT
    call set_cursor

    mov cx, 42
.col:
    mov al, ' '
    mov bl, 0x07
    call print_char_attr
    loop .col

    inc byte [.r]
    jmp .row

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.r db 0

draw_weekdays:
    push si
    mov si, wd_names
    mov byte [.i], 0
.lp:
    cmp byte [.i], 7
    jae .done

    mov al, [.i]
    mov bl, CELL_W
    mul bl
    add al, CAL_LEFT + 2
    mov dl, al
    mov dh, CAL_TOP
    call set_cursor

    mov bl, 0x0B
    lodsb
    call print_char_attr
    lodsb
    call print_char_attr
    lodsb

    inc byte [.i]
    jmp .lp
.done:
    pop si
    ret

.i db 0

draw_days:
    call zeller
    mov [.fd], al

    mov al, [current_month]
    call get_days_in_month
    mov [.td], al

    mov byte [.col], 0
    mov byte [.row], 0
    mov byte [.day], 1

    mov al, [.fd]
    mov [.col], al

.lp:
    mov al, [.day]
    cmp al, [.td]
    ja .done

    cmp byte [.col], 7
    jne .place
    mov byte [.col], 0
    inc byte [.row]

.place:
    mov al, [.col]
    mov bl, CELL_W
    mul bl
    add al, CAL_LEFT + 2
    mov dl, al

    mov al, [.row]
    add al, CAL_TOP + 1
    mov dh, al

    call set_cursor

    mov bl, 0x0F
    mov al, [.day]
    xor ah, ah
    mov cl, 10
    div cl

    cmp al, 0
    jne .tens
    mov al, ' '
    call print_char_attr
    jmp .ones
.tens:
    add al, '0'
    call print_char_attr
.ones:
    mov al, ah
    add al, '0'
    call print_char_attr

    inc byte [.col]
    inc byte [.day]
    jmp .lp
.done:
    ret

.fd db 0
.td db 0
.col db 0
.row db 0
.day db 1

draw_nav:
    mov dh, 20
    mov dl, 10
    call set_cursor
    mov si, nav_str
    mov bl, 0x08
    call print_str_attr
    ret

prev_month:
    dec byte [current_month]
    cmp byte [current_month], 0
    jne .done
    mov byte [current_month], 12
    dec word [current_year]
.done:
    ret

next_month:
    inc byte [current_month]
    cmp byte [current_month], 13
    jne .done
    mov byte [current_month], 1
    inc word [current_year]
.done:
    ret

wd_names:
    db 'Mo',0
    db 'Tu',0
    db 'We',0
    db 'Th',0
    db 'Fr',0
    db 'Sa',0
    db 'Su',0

month_ptrs:
    dw .jan,.feb,.mar,.apr,.may,.jun
    dw .jul,.aug,.sep,.oct,.nov,.dec

.jan db 'January',0
.feb db 'February',0
.mar db 'March',0
.apr db 'April',0
.may db 'May',0
.jun db 'June',0
.jul db 'July',0
.aug db 'August',0
.sep db 'September',0
.oct db 'October',0
.nov db 'November',0
.dec db 'December',0

nav_str db '<-- Prev                --> Next               Esc Exit',0

days_table db 31,28,31,30,31,30,31,31,30,31,30,31

current_month db 0
current_year dw 0
