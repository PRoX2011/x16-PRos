[BITS 16]
[ORG 500h]
%define NEWLINE 0x0A
%define CR 0X0D
%define PRINT 0x0E
%define WHITE 0x0F
%define CYAN 0x0B
%define GREEN 0x0A
%define BLACK 0x00
%define MOVE_CURSOR 0x02

start:
    cli
    call set_video_mode
    call print_interface
    call print_newline
    call print_newline
    call shell
    jmp $

set_video_mode:
    pusha
    mov ax, 0x12
    int 0x10
    popa
    ret

move_cursor_to_top:
    mov ah, MOVE_CURSOR
    mov bh, 0x00   ; Страница
    mov dx, 0x0000 ; Ряд и столбец
    int 0x10
    ret

set_background_color:
    mov ah, 0x06
    mov al, 0x00
    mov bh, BLACK
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    ret
  
print_string:
    mov ah, PRINT
    mov bh, 0x00   ; страница
    mov bl, WHITE
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
print_newline:
    mov ah, PRINT
    mov al, CR
    int 0x10
    mov al, NEWLINE
    int 0x10
    ret

print_interface:
    mov si, header
    call print_string
    mov si, info
    call print_string_green
    mov si, menu
    call print_string_green
    ret

print_help:
    mov si, menu
    call print_string_green
    call print_newline
    ret

shell:
    mov si, prompt
    call print_string
    call read_command
    call print_newline
    call execute_command
    jmp shell

; ===================== Shell =====================

read_command:
    mov di, command_buffer
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, 255
    jge .done_read
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp di, command_buffer
    je .read_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0
    ret

execute_command:
    mov si, command_buffer
    ; Проверка команды "help"
    mov di, help_str
    call compare_strings
    je do_help
    
    mov si, command_buffer
    ; Проверка команды "info"
    mov di, info_str
    call compare_strings
    je print_OS_info

    mov si, command_buffer
    ; Проверка команды "cls"
    mov di, cls_str
    call compare_strings
    je do_cls
    
    mov si, command_buffer
    ; Проверка команды "CPU"
    mov di, CPU_str
    call compare_strings
    je do_CPUinfo
    
    mov si, command_buffer
    ; Проверка команды "date"
    mov di, date_str
    call compare_strings
    je print_date
    
    mov si, command_buffer
    ; Проверка команды "time"
    mov di, time_str
    call compare_strings
    je print_time

    mov si, command_buffer
    ; Проверка команды "shut"
    mov di, shut_str
    call compare_strings
    je do_shutdown
    
    mov si, command_buffer
    ; Проверка команды "reboot"
    mov di, reboot_str
    call compare_strings
    je do_reboot
   
    mov si, command_buffer
    ; Проверка команды "writer"
    mov di, writer_str
    call compare_strings
    je start_writer
    
    mov si, command_buffer
    ; Проверка команды "brainf"
    mov di, brainf_str
    call compare_strings
    je start_brainf
    
    mov si, command_buffer
    ; Проверка команды "barchart"
    mov di, barchart_str
    call compare_strings
    je start_barchart
    
    mov si, command_buffer
    ; Проверка команды "snake"
    mov di, snake_str
    call compare_strings
    je start_snake
    
    mov si, command_buffer
    ; Проверка команды "calc"
    mov di, calc_str
    call compare_strings
    je start_calc
    
    mov si, command_buffer
    ; Проверка команды "load"
    mov di, load_str
    call compare_strings
    je load_program

    call unknown_command
    ret

compare_strings:
    ; si - указатель на вводимую команду
    ; di - указатель на проверяемую команду
    xor cx, cx
.next_char:
    lodsb                ; Загружаем следующий символ из команды пользователя
    cmp al, [di]        ; Сравниваем с символом из команды
    jne .not_equal       ; Если не равны, переходим к метке .not_equal
    cmp al, 0           ; Проверяем конец строки
    je .equal           ; Если конец строки, команды равны
    inc di              ; Переходим к следующему символу проверяемой команды
    jmp .next_char      ; Повторяем сравнение
.not_equal:
    ret                 ; Возвращаемся, если команды не равны
.equal:
    ret                 ; Возвращаемся, если команды равны


help_str db 'help', 0
info_str db 'info', 0
cls_str db 'cls', 0
shut_str db 'shut', 0
reboot_str db 'reboot', 0
CPU_str db 'CPU', 0
date_str db 'date', 0
time_str db 'time', 0
load_str db 'load', 0
writer_str db 'writer', 0
brainf_str db 'brainf', 0
barchart_str db 'barchart', 0
snake_str db 'snake', 0
calc_str db 'calc', 0

; ===================== Other =====================
do_banner:
    call print_interface
    call print_newline
    ret

do_help:
    call print_newline
    call print_help
    call print_newline
    ret

do_cls:
    pusha
    mov ax, 0x12
    int 0x10
    popa
    ret

unknown_command:
    mov si, unknown_msg
    call print_string_red
    call print_newline
    ret

do_shutdown:
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret
    
do_reboot:
    int 0x19
    ret
    
print_OS_info:
    mov si, info
    call print_string_green
    call print_newline
    ret
       
;===================== Start programs =====================

start_writer:
    pusha
    mov ah, 0x02
    mov al, 2       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov dh, 0       ; Номер головки
    mov cl, 9       ; Номер сектора
    mov bx, 800h    ; Адрес загрузки
    int 0x13
    jc .disk_error  ; Если ошибка, перейти к обработке
    jmp 800h        ; Переход к загруженной программе
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret
    
start_brainf:
    pusha
    mov ah, 0x02
    mov al, 2       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov dh, 0       ; Номер головки
    mov cl, 12       ; Номер сектора
    mov bx, 800h    ; Адрес загрузки
    int 0x13
    jc .disk_error  ; Если ошибка, перейти к обработке
    jmp 800h        ; Переход к загруженной программе
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret
   
start_barchart:
    pusha
    mov ah, 0x02
    mov al, 1       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov dh, 0       ; Номер головки
    mov cl, 15       ; Номер сектора
    mov bx, 800h    ; Адрес загрузки
    int 0x13
    jc .disk_error  ; Если ошибка, перейти к обработке
    jmp 800h        ; Переход к загруженной программе
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret
    
start_snake:
    pusha
    mov ah, 0x02
    mov al, 2       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov dh, 0       ; Номер головки
    mov cl, 16       ; Номер сектора
    mov bx, 800h    ; Адрес загрузки
    int 0x13
    jc .disk_error  ; Если ошибка, перейти к обработке
    jmp 800h        ; Переход к загруженной программе
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret
    
start_calc:
    pusha
    mov ah, 0x02
    mov al, 2       ; Количество секторов для чтения
    mov ch, 0       ; Номер дорожки
    mov dh, 0       ; Номер головки
    mov cl, 18      ; Номер сектора
    mov bx, 800h    ; Адрес загрузки
    int 0x13
    jc .disk_error  ; Если ошибка, перейти к обработке
    jmp 800h        ; Переход к загруженной программе
.disk_error:
    mov si, disk_error_msg
    call print_string_red
    call print_newline
    popa
    ret

; ===================== CPU info functions ===================== 
print_edx:
    mov ah, 0eh

    mov bx, 4
    loop4r:
        mov al, dl
        int 10h
        ror edx, 8

        dec bx
        cmp bx, 0
        jne loop4r
    ret
    
print_full_name_part:
    cpuid
    push edx
    push ecx
    push ebx
    push eax

    mov cx, 4
loop4n:
    pop edx
    call print_edx

    dec cx
    cmp cx, 0
    jne loop4n

    ret

print_cores:
    mov si, cores
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 16
    mov al, bl
    call print_al
    ret

print_cache_line:
    mov si, cache_line
    call print_string
    mov eax, 1
    cpuid
    ror ebx, 8
    mov al, bl
    mov bl, 8
    mul bl
    call print_al
    ret

print_stepping:
    mov si, stepping
    call print_string
    mov eax, 1
    cpuid
    and al, 15
    call print_al
    ret
 
print_al:
    mov ah, 0
    mov dl, 10
    div dl
    add ax, '00'
    mov dx, ax

    mov ah, 0eh
    mov al, dl
    cmp dl, '0'
    jz skip_fn
    mov bl, 0x0F
    int 10h
skip_fn:
    mov al, dh
    mov bl, 0x0F
    int 10h
    ret
    
do_CPUinfo:
    pusha
    mov si, cpu_name
    call print_string
    ; Выводим информацию о ЦПУ
    mov eax, 80000002h
    call print_full_name_part
    mov eax, 80000003h
    call print_full_name_part
    mov eax, 80000004h
    call print_full_name_part
    mov si, mt
    call print_string
    call print_cores
    mov si, mt
    call print_string
    call print_cache_line
    mov si, mt
    call print_string
    call print_stepping
    mov si, mt
    call print_string
    popa
    ret
    
cpu_name db '  CPU name: ', 0
cores db '  CPU cores: ', 0
stepping db '  Stepping ID: ', 0
cache_line db '  Cache line: ', 0

; ===================== About OS =====================

info db 10, 13
     db '+----------------------------------------------+', 10, 13
     db '|  x16 PRos is the simple 16 bit operating     |', 10, 13
     db '|  system written in NASM for x86 PC`s         |', 10, 13
     db '|----------------------------------------------|', 10, 13
     db '|  Autor: PRoX (https://github.com/PRoX2011)   |', 10, 13
     db '|  Amount of disk sectors: 25                  |', 10, 13
     db '|  OS version: 0.2.6                           |', 10, 13
     db '+==============================================+', 10, 13, 0

; ===================== Date and time functions =====================

; Функция для вывода даты
; Выводит дату в формате DD.MM.YY
print_date:
    mov si, date_msg
    call print_string
    
    pusha
    ; Получить дату
    mov ah, 0x04
    int 0x1a  ; Получаем дату: ch - век, cl - год, dh - месяц, dl - день

    mov ah, 0x0e  ; Установить функцию для вывода символа

    ; Вывести день (dl)
    mov al, dl
    shr al, 4
    add al, '0'  ; Преобразовать в ASCII
    mov bl, 0x0B
    int 0x10     ; Выводим
    mov al, dl
    and al, 0x0F
    add al, '0'  ; Преобразовать в ASCII
    int 0x10     ; Выводим

    ; Вывести точку
    mov al, '.'
    mov bl, 0x0B
    int 0x10

    ; Вывести месяц (dh)
    mov al, dh
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, dh
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10

    ; Вывести точку
    mov al, '.'
    mov bl, 0x0B
    int 0x10

    ; Вывести год (cl)
    mov al, cl
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, cl
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10
    
    mov si, mt
    call print_string
    
    popa
    ret
    
date_msg db 'Current date: ', 0

; Функция для вывода времяни
; Выводит дату в формате HH.MM.SS
print_time:
    mov si, time_msg
    call print_string
    
    pusha
    ; Получить время
    mov ah, 0x02
    int 0x1a  ; Получаем время: ch - часы, cl - минуты, dh - секунды

    mov ah, 0x0e  ; Установить функцию для вывода символа

    ; Вывести часы
    mov al, ch
    shr al, 4
    add al, '0'  ; Преобразовать в ASCII
    mov bl, 0x0B
    int 0x10     ; Выводим
    mov al, ch
    and al, 0x0F
    add al, '0'  ; Преобразовать в ASCII
    mov bl, 0x0B
    int 0x10     ; Выводим

    ; Вывести разделитель
    mov al, ':'
    mov bl, 0x0B
    int 0x10

    ; Вывести минуты
    mov al, cl
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, cl
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10

    ; Вывести разделитель
    mov al, ':'
    mov bl, 0x0B
    int 0x10

    ; Вывести секунды
    mov al, dh
    shr al, 4
    add al, '0'
    mov bl, 0x0B
    int 0x10
    mov al, dh
    and al, 0x0F
    add al, '0'
    mov bl, 0x0B
    int 0x10
    
    mov si, mt
    call print_string
    
    popa
    ret
    
time_msg db 'Current time: ', 0

; ===================== Load Command =====================

load_program:
    mov si, load_prompt
    call print_string
    call read_number  ; Читаем номер сектора
    call print_newline

    ; Загружаем программу с указанного сектора
    call start_program
    ret

read_number:
    mov di, number_buffer
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D      ; Проверка на Enter
    je .done_read
    cmp al, 0x08      ; Проверка на Backspace
    je .handle_backspace
    cmp cx, 5         ; Максимальная длина числа (5 цифр)
    jge .read_loop    ; Если достигнут максимум, игнорируем ввод
    cmp al, '0'       ; Проверка, что символ является цифрой
    jb .read_loop
    cmp al, '9'
    ja .read_loop
    stosb             ; Сохраняем символ в буфер
    mov ah, 0x0E      ; Выводим символ на экран
    mov bl, 0x1F
    int 0x10
    inc cx            ; Увеличиваем счётчик введённых символов
    jmp .read_loop

.handle_backspace:
    cmp cx, 0         ; Если буфер пуст, игнорируем Backspace
    je .read_loop
    dec di            ; Уменьшаем указатель буфера
    dec cx            ; Уменьшаем счётчик символов
    mov ah, 0x0E      ; Удаляем символ с экрана
    mov al, 0x08      ; Backspace
    int 0x10
    mov al, ' '       ; Пробел
    int 0x10
    mov al, 0x08      ; Снова Backspace
    int 0x10
    jmp .read_loop

.done_read:
    mov byte [di], 0  ; Завершаем строку нулевым символом
    call convert_to_number  ; Преобразуем строку в число
    ret

convert_to_number:
    mov si, number_buffer
    xor ax, ax
    xor cx, cx
.convert_loop:
    lodsb
    cmp al, 0         ; Проверка на конец строки
    je .done_convert
    sub al, '0'       ; Преобразуем символ в цифру
    imul cx, 10       ; Умножаем текущее значение на 10
    add cx, ax        ; Добавляем новую цифру
    jmp .convert_loop
.done_convert:
    mov [sector_number], cx  ; Сохраняем число в переменную
    ret

start_program:
    pusha
    mov ah, 0x02      ; Функция чтения сектора
    mov al, 1         ; Количество секторов для чтения
    mov ch, 0         ; Номер дорожки (цилиндра)
    mov dh, 0         ; Номер головки
    mov cl, [sector_number]  ; Номер сектора
    mov bx, 800h      ; Адрес, куда загружать данные
    int 0x13
    jc .disk_error    ; Если ошибка, переходим к обработке ошибки
    jmp 800h          ; Переход к загруженной программе
    popa
    ret

.disk_error:
    mov si, disk_error_msg
    call print_string_red
    popa
    ret

load_prompt db 'Enter sector number: ', 0
disk_error_msg db 'Disk read error!', 0
number_buffer db 6 dup(0)
sector_number dw 0

; ===================== print =====================

; Зелёное на чёрном
print_string_green:
    mov ah, PRINT
    mov bh, 0x00
    mov bl, GREEN
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
; бирюзовый на чёрном
print_string_cyan:
    mov ah, PRINT
    mov bh, 0x00
    mov bl, CYAN
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
; красный на чёрном
print_string_red:
    mov ah, PRINT
    mov bh, 0x00
    mov bl, 0x055FC
.print_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_char
.done:
    ret
    
; ===================== Data section =====================

header db '============================= x16 PRos v0.2 ====================================', 0
menu db '+-----------------------------------------------+', 10, 13
     db '|Commands:                                      |', 10, 13
     db '|  help - get list of the commands              |', 10, 13
     db '|  info - print information about OS            |', 10, 13
     db '|  cls - clear terminal                         |', 10, 13
     db '|  shut - shutdown PC                           |', 10, 13
     db '|  reboot - go to bootloader (restart system)   |', 10, 13
     db '|  date - print current date (DD.MM.YY)         |', 10, 13
     db '|  time - print current time (HH.MM.SS)         |', 10, 13
     db '|  CPU - print CPU info                         |', 10, 13
     db '|  load - load program from disk sector         |', 10, 13
     db '|  writer - text editor                         |', 10, 13
     db '|  brainf - brainf IDE                          |', 10, 13
     db '|  barchart - charting soft (by Loxsete)        |', 10, 13
     db '|  snake - snake game                           |', 10, 13
     db '|  calc - calculator program (by Saeta)         |', 10, 13
     db '+===============================================+', 0
unknown_msg db 'Unknown command.', 0
prompt db '[PRos] > ', 0
mt db '', 10, 13, 0
buffer db 512 dup(0)
command_buffer db 128 dup(0)
