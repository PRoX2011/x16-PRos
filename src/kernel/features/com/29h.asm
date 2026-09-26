com_29h:
    push bp
    mov bp, sp
    push bx
    push cx
    push dx

    mov [cs:parse_flags], al
    mov byte [cs:parse_wild], 0
.skip_blanks:
    mov al, [si]
    cmp al, ' '
    je .eat
    cmp al, 9
    je .eat
    jmp .blanks_done
.eat:
    inc si
    jmp .skip_blanks

.blanks_done:
    test byte [cs:parse_flags], 0x01
    jz .drive
.skip_seps:
    mov al, [si]
    call parse_is_sep
    jnc .drive
    inc si
    jmp .skip_seps
.drive:
    mov al, [si]
    test al, al
    jz .no_drive
    cmp byte [si + 1], ':'
    jne .no_drive

    cmp al, 'a'
    jb .drive_upper
    cmp al, 'z'
    ja .drive_upper
    sub al, 'a' - 'A'
.drive_upper:
    cmp al, 'A'
    jb .bad_drive
    cmp al, 'Z'
    ja .bad_drive
    sub al, 'A' - 1
    mov [es:di], al
    add si, 2
    jmp .name

.no_drive:
    test byte [cs:parse_flags], 0x02
    jnz .name
    mov byte [es:di], 0

.name:
    inc di
    mov cx, 8
    mov al, [si]
    call parse_is_end
    jc .name_empty

.name_loop:
    mov al, [si]
    call parse_is_end
    jc .name_pad
    cmp al, '.'
    je .name_pad
    inc si
    cmp al, '*'
    je .name_star
    call parse_upper
    stosb
    loop .name_loop
    jmp .to_ext

.name_star:
    mov byte [cs:parse_wild], 1
    mov al, '?'
.star_fill:
    stosb
    loop .star_fill
    jmp .to_ext

.name_pad:
    mov al, ' '
    rep stosb
    jmp .to_ext

.name_empty:
    test byte [cs:parse_flags], 0x04
    jnz .skip_name_field
    mov al, ' '
    rep stosb
    jmp .ext_empty_check
.skip_name_field:
    add di, cx
    jmp .ext_empty_check

.to_ext:
    test cx, cx
    jz .have_all_name
.have_all_name:
    mov al, [si]
    cmp al, '.'
    jne .ext_none
    inc si

    mov cx, 3
.ext_loop:
    mov al, [si]
    call parse_is_end
    jc .ext_pad
    inc si
    cmp al, '*'
    je .ext_star
    call parse_upper
    stosb
    loop .ext_loop
    jmp .done

.ext_star:
    mov byte [cs:parse_wild], 1
    mov al, '?'
.ext_star_fill:
    stosb
    loop .ext_star_fill
    jmp .done

.ext_pad:
    mov al, ' '
    rep stosb
    jmp .done

.ext_none:
    mov cx, 3
.ext_empty_check:
    test byte [cs:parse_flags], 0x08
    jnz .done
    mov al, ' '
    rep stosb

.done:
    mov al, [cs:parse_wild]
    pop dx
    pop cx
    pop bx
    and word [bp+6], 0xFFFE
    pop bp
    iret

.bad_drive:
    mov al, 0xFF
    pop dx
    pop cx
    pop bx
    and word [bp+6], 0xFFFE
    pop bp
    iret

parse_is_sep:
    cmp al, ':'
    je .yes
    cmp al, ';'
    je .yes
    cmp al, ','
    je .yes
    cmp al, '='
    je .yes
    cmp al, '+'
    je .yes
    clc
    ret
.yes:
    stc
    ret

parse_is_end:
    cmp al, ' '
    jbe .yes
    call parse_is_sep
    jc .yes
    cmp al, '\'
    je .yes
    cmp al, '/'
    je .yes
    cmp al, '"'
    je .yes
    cmp al, '['
    je .yes
    cmp al, ']'
    je .yes
    cmp al, '|'
    je .yes
    cmp al, '<'
    je .yes
    cmp al, '>'
    je .yes
    clc
    ret
.yes:
    stc
    ret

parse_upper:
    cmp al, 'a'
    jb .done
    cmp al, 'z'
    ja .done
    sub al, 'a' - 'A'
.done:
    ret

parse_flags db 0
parse_wild  db 0
