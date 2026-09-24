; ==================================================================
; x16-PRos -- KILL. Terminate a background task by id
; Copyright (C) 2026 PRoX2011
;
; Usage: KILL <id>
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

section .text

start:
    mov [param_list], si

    pusha

    mov ah, 0x05
    int 0x21

    mov si, [param_list]
    test si, si
    jz .usage
    call string_string_parse
    cmp ax, 0
    je .usage

    mov di, ax
    mov al, [di]
    mov bl, [di + 1]
    test bl, bl
    jnz .bad_id

    sub al, '0'
    cmp al, 4
    jae .bad_id
    cmp al, 0
    je .bad_id

    mov bl, al
    mov ah, 0x18
    int 0x23
    jc .fail

    mov ah, 0x02
    mov si, ok_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.usage:
    mov ah, 0x04
    mov si, usage_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.bad_id:
    mov ah, 0x04
    mov si, bad_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.fail:
    mov ah, 0x04
    mov si, fail_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.done:
    popa
    ret

string_string_parse:
    push si
    mov ax, si
    push ax
.skip_lead:
    lodsb
    cmp al, ' '
    je .skip_lead
    cmp al, 0
    je .none
    dec si
    pop ax
    mov ax, si
    push ax
.scan:
    lodsb
    cmp al, 0
    je .fin
    cmp al, ' '
    jne .scan
    dec si
    mov byte [si], 0
.fin:
    pop ax
    pop si
    ret
.none:
    pop ax
    pop si
    xor ax, ax
    ret

section .data

usage_msg  db 'Usage: KILL <id>', 0
bad_msg    db 'Invalid task id', 0
fail_msg   db 'Kill failed', 0
ok_msg     db 'Task killed', 0

param_list dw 0
