[BITS 16]
[ORG 0x8000]

start:
    ; mov byte [buf], 0
    mov byte [cur_file_name], 0
    mov byte [file_text_buffer], 0
    mov byte [command_buffer], 0

    ; cx - counter of file name lenght
    mov cx, 0
    ; di - pointer to file name buffer
    mov di, cur_file_name
get_opening_file_name_loop:
    mov al, [si]
    cmp al, 0
    je open_file
    cmp al, 0x20  ; if char = ' ' file name have end
    je open_file
    cmp cx, FILE_NAME_MAX_LENGTH
    jge err_file_name_lenght
    
    mov byte [di], al
    inc si
    inc cx
    inc di

    jmp get_opening_file_name_loop

open_file:
    mov byte [di], 0

    mov si, cur_file_name
    mov di, text_help_command
    call strcmp
    cmp ax, 0
    je put_help_message

    mov si, cur_file_name
    mov cx, file_text_buffer
    mov ah, 0x02
    int 0x22

    mov si, file_text_buffer
    call strlen
    cmp cx, 0
    je err_file_not_be_opened

    ; не отслеживает ошибки
    ; cmp bx, 0
    ; jz err_file_not_be_opened
    ; jc err_file_not_be_opened

    ; === put successfully message ===
        mov ah, 0x01
        mov si, text_file_readed1
        int 0x21
        
        mov ax, cx
        mov di, number_convert_buffer
        call convert_to_string
        mov si, number_convert_buffer
        mov ah, 0x01
        int 0x21

        mov si, text_file_readed2
        int 0x21
    ; ================================

    call save_buffer_for_undo
    call split_text_by_lines

command_loop:
    mov cx, 0
    mov di, command_buffer
    mov dh, 0x0E
get_command_char:
    mov ah, 0
    int 0x16
    xchg ah, dh
    mov bx, 0x0F
    int 0x10
    xchg ah, dh

    cmp ah, 0x0E
    je get_command_bs_handle
    cmp ah, 0x1C
    je parse_command

    mov [di], al
    inc di
    inc cx
    jmp get_command_char

get_command_bs_handle:
    mov ah, 0x0E
    mov al, 0x20
    int 0x10
    mov al, 0x08
    int 0x10

    cmp cx, 0
    jne .bs_handle_del_from_buf
    jmp get_command_char
.bs_handle_del_from_buf:
    dec di
    dec cx
    jmp get_command_char

parse_command:
    mov byte [di], 0

    mov ah, 0x0E
    mov bx, 0
    mov al, 0x0A
    int 0x10

    mov al, 0x0D
    int 0x10

    mov si, command_buffer
    mov ax, [si]
    inc si

    cmp al, 0
    je command_loop
    cmp al, 'q'
    je command_q
    cmp al, 'Q'
    je exit_prog
    cmp al, 'p'
    je command_p
    cmp al, 'w'
    je command_w
    cmp al, 'd'
    je command_d
    cmp al, 'u'
    je command_u
    cmp al, 'a'
    je command_a

    jmp err_unknown_command

exit_prog:
    ret

err_unknown_command:
    mov si, err_text_unknown_command
    mov ah, 0x01
    int 0x21
    jmp command_loop

err_file_name_lenght:
    mov si, err_text_file_name_lenght
    mov ah, 0x01
    int 0x21
    jmp command_loop

err_file_not_be_opened:
    mov si, err_text_file_not_be_opened
    mov ah, 0x01
    int 0x21
    ret

put_help_message:
    mov si, text_help_message
    mov ah, 0x01
    int 0x21
    ret


; === includes ===
    %include "programs/ed-common.inc"
    %include "programs/ed-commands.inc"
    %include "programs/lib/utils.inc"
; ================