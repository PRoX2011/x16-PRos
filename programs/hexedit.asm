; HEXEDIT.ASM - Hex Editor for x16-PRos OS
; Copyright (C) @cuzhima
; Usage: hexedit <filename>

[BITS 16]
[ORG 0x8000] ; Программы загружаются по адресу 0x8000

start:
    ; Сохраняем параметры (SI указывает на аргументы командной строки)
    mov [filename_ptr], si

    ; Проверяем наличие аргумента
    mov si, [filename_ptr]
    cmp byte [si], 0
    jne .load_file

    ; Нет аргументов - показать ошибку
    mov si, no_args_msg
    call print_string_red
    int 20h ; Выход

.load_file:
    ; Загружаем файл
    mov ah, 0x02
    mov si, [filename_ptr]
    mov cx, file_buffer
    int 22h
    jc .load_error
    
    ; Проверка размера файла (макс 32KB)
    cmp bx, 32768
    jbe .size_ok
    mov si, file_too_big_msg
    call print_string_red
    int 20h
    
.size_ok:
    mov [file_size], bx
    mov [cursor_pos], word 0
    mov [view_offset], word 0
    mov [edit_mode], byte 0
    mov [byte_buffer], byte 0
    mov [nibble_flag], byte 0
    mov [modified_flag], byte 0 ; Флаг изменений

    ; Главный цикл редактора
.main_loop:
    call display_ui
    call handle_input
    jmp .main_loop

.load_error:
    mov si, load_error_msg
    call print_string_red
    int 20h ; Выход

;----------------------------------------------------------
; ОБРАБОТКА ВВОДА
;----------------------------------------------------------
handle_input:
    ; Ожидать ввода
    mov ah, 0x00
    int 16h
    
    cmp [edit_mode], byte 1
    je .edit_mode
    
    ; Режим навигации
    cmp ah, 0x48 ; Стрелка вверх
    je .move_up
    cmp ah, 0x50 ; Стрелка вниз
    je .move_down
    cmp ah, 0x4B ; Стрелка влево
    je .move_left
    cmp ah, 0x4D ; Стрелка вправо
    je .move_right
    cmp al, 0x1B ; Escape
    je .exit
    cmp al, 0x0D ; Enter
    je .start_edit
    cmp ah, 0x3B ; F1 - Сохранить
    je .save_file
    cmp ah, 0x3C ; F2 - Отменить изменения
    je .discard_changes
    cmp ah, 0x3D ; F3 - Показать справку
    je .show_help
    jmp .done
    
.move_up:
    cmp [cursor_pos], word 16
    jb .done
    sub [cursor_pos], word 16
    jmp .check_view
    
.move_down:
    mov ax, [file_size]
    sub ax, 16
    cmp ax, [cursor_pos]
    jbe .done
    add [cursor_pos], word 16
    jmp .check_view
    
.move_left:
    cmp [cursor_pos], word 0
    je .done
    dec word [cursor_pos]
    jmp .check_view
    
.move_right:
    mov ax, [file_size]
    dec ax
    cmp [cursor_pos], ax
    jae .done
    inc word [cursor_pos]
    jmp .check_view
    
.check_view:
    ; Проверить видимость курсора
    mov ax, [cursor_pos]
    mov bx, [view_offset]
    
    ; Если курсор выше видимой области
    cmp ax, bx
    jb .scroll_up
    
    ; Если курсор ниже видимой области
    mov dx, bx
    add dx, 256 - 16
    cmp ax, dx
    ja .scroll_down
    jmp .done

.scroll_up:
    sub bx, 256
    jns .set_view
    xor bx, bx
    jmp .set_view

.scroll_down:
    add bx, 256
    ; Проверить не выходит ли за размер файла
    mov ax, [file_size]
    sub ax, 256
    jns .set_view
    xor bx, bx ; Если файл меньше 256 байт
    jmp .set_view
    
.set_view:
    mov [view_offset], bx
    jmp .done

.start_edit:
    ; Начать редактирование
    mov [edit_mode], byte 1
    mov [nibble_flag], byte 0
    
    ; Загрузить текущий байт
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [si]
    mov [byte_buffer], al
    jmp .done

.save_file:
    ; Сохранить файл
    mov si, [filename_ptr]
    mov bx, file_buffer
    mov cx, [file_size]
    mov ah, 0x03 ; Функция записи файла
    int 22h
    jc .save_error
    
    mov [modified_flag], byte 0 ; Сбросить флаг изменений
    mov si, save_success_msg
    call print_string_green
    mov cx, 30
    call delay
    jmp .done

.save_error:
    mov si, save_error_msg
    call print_string_red
    mov cx, 30
    call delay
    jmp .done

.discard_changes:
    ; Перезагрузить файл
    mov si, [filename_ptr]
    mov cx, file_buffer
    mov ah, 0x02
    int 22h
    mov [modified_flag], byte 0 ; Сбросить флаг изменений
    jmp .done

.show_help:
    ; Показать справку (упрощенная версия)
    mov si, help_extended_msg
    call print_string_cyan
    mov cx, 100
    call delay
    jmp .done

.exit:
    int 0x19

.done:
    ret

; Режим редактирования
.edit_mode:
    cmp al, 0x1B ; Escape
    je .cancel_edit
    cmp al, 0x0D ; Enter
    je .finish_edit
    cmp al, 0x08 ; Backspace
    je .backspace
    
    ; Проверить hex-цифру
    call is_hex_digit
    jnc .done_edit
    
    ; Преобразовать в число
    call char_to_hex
    
    ; Обновить байт
    mov bl, [byte_buffer]
    cmp [nibble_flag], byte 0
    je .high_nibble
    
    ; Младший ниббл
    and bl, 0xF0
    or bl, al
    mov [byte_buffer], bl
    mov [nibble_flag], byte 0
    jmp .update_byte
    
.high_nibble:
    shl al, 4
    and bl, 0x0F
    or bl, al
    mov [byte_buffer], bl
    mov [nibble_flag], byte 1

.update_byte:
    ; Обновить в буфере
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [byte_buffer]
    mov [si], al
    mov [modified_flag], byte 1 ; Установить флаг изменений

.done_edit:
    ret

.backspace:
    ; Сбросить редактирование
    mov [nibble_flag], byte 0
    jmp .done_edit

.finish_edit:
    ; Завершить редактирование
    mov [edit_mode], byte 0
    mov [nibble_flag], byte 0
    
    ; Переместить курсор вправо
    mov ax, [cursor_pos]
    inc ax
    cmp ax, [file_size]
    jae .stay
    mov [cursor_pos], ax
    jmp .check_view
    
.stay:
    dec ax
    mov [cursor_pos], ax
    jmp .done

.cancel_edit:
    ; Восстановить оригинальный байт
    mov si, file_buffer
    add si, [cursor_pos]
    mov al, [si]
    mov [byte_buffer], al
    mov [edit_mode], byte 0
    mov [nibble_flag], byte 0
    jmp .done

;----------------------------------------------------------
; ПОЛЬЗОВАТЕЛЬСКИЙ ИНТЕРФЕЙС
;----------------------------------------------------------
display_ui:
    ; Очистить экран
    mov ah, 0x06 
    int 21h

    ; Показать заголовок с именем файла
    mov si, [filename_ptr]
    mov di, header_str
    call string_copy
    
    ; Добавить звездочку если были изменения
    cmp [modified_flag], byte 0
    je .no_modify
    mov si, modified_str
    call string_append
    
.no_modify:
    mov si, header_str
    call print_string_cyan
    
    ; Показать размер файла
    mov si, size_prefix
    call print_string
    mov ax, [file_size]
    call int_to_string
    mov si, ax
    call print_string
    
    ; Показать позицию курсора
    mov si, pos_prefix
    call print_string
    mov ax, [cursor_pos]
    call int_to_string
    mov si, ax
    call print_string
    call print_newline

    ; Вывести адреса
    mov si, addr_header
    call print_string_green
    call print_newline

    ; Вывести hex-дамп
    mov cx, 16 ; 16 строк
    mov bx, [view_offset] ; Текущее смещение
    xor di, di ; Счетчик строк

.hex_loop:
    push cx
    push di
    push bx
    
    ; Вывести адрес
    mov ax, bx
    call print_hex_word
    mov al, ':'
    call print_char
    
    ; Вывести hex-байты
    mov cx, 16
    mov si, file_buffer
    add si, bx
    xor di, di ; Счетчик байтов в строке

.hex_bytes:
    push cx
    mov al, ' '
    call print_char
    
    ; Проверить позицию курсора
    mov dx, [cursor_pos]
    cmp dx, bx
    jne .normal_byte
    
    ; Это текущая позиция курсора
    mov ah, 0x02 
    mov bl, 0x0A ; Зеленый
    int 21h

.normal_byte:
    lodsb
    push ax
    call print_hex_byte
    pop ax
    
    ; Проверить режим редактирования
    cmp [edit_mode], byte 1
    jne .next_byte
    
    mov dx, [cursor_pos]
    cmp dx, bx
    jne .next_byte
    
    ; Показать редактируемый байт
    push ax
    mov al, '['
    call print_char
    mov al, [byte_buffer]
    call print_hex_byte
    mov al, ']'
    call print_char
    pop ax
    jmp .skip_advance

.next_byte:
    inc bx
    inc di

.skip_advance:
    pop cx
    loop .hex_bytes
    
    ; ASCII представление
    mov al, ' '
    call print_char
    mov al, '|'
    call print_char
    
    pop bx ; Восстановить начало строки
    push bx
    mov cx, 16
    mov si, file_buffer
    add si, bx

.ascii_bytes:
    lodsb
    cmp al, 32
    jb .non_printable
    cmp al, 126
    ja .non_printable
    jmp .print_ascii

.non_printable:
    mov al, '.'

.print_ascii:
    ; Выделение текущего символа
    mov dx, [cursor_pos]
    cmp dx, bx
    jne .normal_ascii
    
    mov ah, 0x02 
    mov bl, 0x0A ; Зеленый
    int 21h
    call print_char
    mov ah, 0x02 
    mov bl, 0x0F ; Белый
    int 21h
    jmp .ascii_next

.normal_ascii:
    call print_char

.ascii_next:
    inc bx
    loop .ascii_bytes
    
    mov al, '|'
    call print_char
    call print_newline
    
    pop bx
    add bx, 16
    pop di
    inc di
    pop cx
    dec cx
    jnz .hex_loop
    
    ; Статус бар
    cmp [edit_mode], byte 1
    je .edit_status
    
    ; Стандартный статус
    mov si, help_msg
    call print_string
    call print_newline
    ret
    
.edit_status:
    mov si, edit_help_msg
    call print_string
    call print_newline
    ret

;----------------------------------------------------------
; ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
;----------------------------------------------------------
print_hex_word:
    ; AX = число для печати
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    ret

print_hex_byte:
    ; AL = число для печати
    push ax
    shr al, 4
    call print_hex_digit
    pop ax
    push ax
    and al, 0x0F
    call print_hex_digit
    pop ax
    ret

print_hex_digit:
    ; AL = цифра (0-15)
    cmp al, 9
    jg .letter
    add al, '0'
    jmp .print
.letter:
    add al, 'A' - 10
.print:
    call print_char
    ret

print_char:
    ; AL = символ
    pusha
    mov ah, 0x0E
    mov bx, 0007h ; Цвет по умолчанию
    int 10h
    popa
    ret

print_string:
    ; SI = указатель на строку
    pusha
    mov ah, 0x0E
    mov bx, 0007h ; Белый на черном
.print_loop:
    lodsb
    test al, al
    jz .done
    int 10h
    jmp .print_loop
.done:
    popa
    ret

print_string_red:
    ; SI = указатель на строку
    pusha
    mov ah, 0x0E
    mov bx, 0004h ; Красный на черном
.print_loop:
    lodsb
    test al, al
    jz .done
    int 10h
    jmp .print_loop
.done:
    popa
    ret

print_string_green:
    ; SI = указатель на строку
    pusha
    mov ah, 0x0E
    mov bx, 0002h ; Зеленый на черном
.print_loop:
    lodsb
    test al, al
    jz .done
    int 10h
    jmp .print_loop
.done:
    popa
    ret

print_string_cyan:
    ; SI = указатель на строку
    pusha
    mov ah, 0x0E
    mov bx, 0003h ; Голубой на черном
.print_loop:
    lodsb
    test al, al
    jz .done
    int 10h
    jmp .print_loop
.done:
    popa
    ret

print_newline:
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    mov bx, 0007h
    int 10h
    mov al, 0x0A
    int 10h
    popa
    ret

is_hex_digit:
    ; AL = символ
    cmp al, '0'
    jb .not_hex
    cmp al, '9'
    jbe .is_hex
    cmp al, 'A'
    jb .not_hex
    cmp al, 'F'
    jbe .is_hex
    cmp al, 'a'
    jb .not_hex
    cmp al, 'f'
    jbe .is_hex
.not_hex:
    clc
    ret
.is_hex:
    stc
    ret

char_to_hex:
    ; AL = hex символ
    cmp al, '9'
    jle .digit
    cmp al, 'F'
    jle .upper
    sub al, 'a' - 10 ; a-f
    ret
.upper:
    sub al, 'A' - 10 ; A-F
    ret
.digit:
    sub al, '0' ; 0-9
    ret

delay:
    ; CX = время ожидания (примерно 1 единица = 1 мс)
    pusha
    mov ah, 0x86
    int 15h
    popa
    ret

; Копирование строки
string_copy:
    ; SI = источник, DI = назначение
    pusha
.copy_loop:
    lodsb
    stosb
    test al, al
    jnz .copy_loop
    popa
    ret

; Конкатенация строк
string_append:
    ; SI = добавляемая строка, DI = целевая строка
    pusha
    ; Найти конец целевой строки
    mov al, 0
    mov cx, -1
    repne scasb
    dec di ; Вернуться на терминатор
    
    ; Скопировать добавляемую строку
.append_loop:
    lodsb
    stosb
    test al, al
    jnz .append_loop
    popa
    ret

; Преобразование числа в строку
int_to_string:
    ; AX = число
    pusha
    mov di, num_buffer
    add di, 6 ; Буфер на 7 символов
    mov byte [di], 0 ; Терминатор
    dec di
    
    mov cx, 10 ; Основание системы
    mov bx, 0 ; Счетчик цифр
    
.convert_loop:
    xor dx, dx
    div cx
    add dl, '0'
    mov [di], dl
    dec di
    inc bx
    
    test ax, ax
    jnz .convert_loop
    
    ; Сдвинуть результат в начало буфера
    mov si, di
    inc si
    mov di, num_buffer
    mov cx, bx
    rep movsb
    mov byte [di], 0
    
    popa
    mov ax, num_buffer
    ret

;----------------------------------------------------------
; ДАННЫЕ
;----------------------------------------------------------
filename_ptr dw 0
file_size dw 0
cursor_pos dw 0
view_offset dw 0
edit_mode db 0 ; 0=навигация, 1=редактирование
byte_buffer db 0
nibble_flag db 0 ; 0=старший ниббл, 1=младший
modified_flag db 0 ; 0=не изменен, 1=изменен

; Сообщения
no_args_msg db 'Error: No arguments!    Usage: hexedit <filename>', 0
load_error_msg db 'Error loading file', 0
file_too_big_msg db 'Error: File >32KB!', 0
save_success_msg db 'File saved!', 0
save_error_msg db 'Save error!', 0
modified_str db ' *', 0

; Строки интерфейса
help_msg db 'Arrows:Navigate  Enter:Edit  F1:Save  F2:Revert  F3:Help  Esc:Exit', 0
edit_help_msg db 'Edit: Hex digits  Enter:Accept  Esc:Cancel', 0
help_extended_msg db 'Hex Editor Help: Arrows navigate, Enter edit, F1 save, F2 revert changes, Esc exit', 0

header_str times 32 db 0
size_prefix db 'Size:', 0
pos_prefix db ' Pos:', 0
addr_header db 'Offset  00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  ASCII', 0
num_buffer times 8 db 0

; Буфер для файла (32 КБ)
file_buffer: