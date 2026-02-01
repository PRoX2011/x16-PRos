; ==================================================================
; x16-PRos -- PROCENTC. Precentages calculator.
;
; Made by Gabriel
; =================================================================

[BITS 16]
[ORG 0x8000]

section .bss
mode         resw 1
step         resw 1
input_buffer resb 6
num1         resw 1
num2         resw 1
exit         resw 1
result_str   resb 7

section .text

start:
    pusha

    mov ax, 0x12
    int 0x10

    mov si, welcome_msg
    call print_string
    call print_newline

    mov si, help_msg
    call print_string_green
    call print_newline

    mov si, input_msg
    call print_string
    mov si, input_buffer
    mov bx, 5
    call scan_string
    call print_newline
    mov di, input_buffer
    mov bx, num1
    call convert_to_number

    mov si, input2_msg
    call print_string
    mov si, input_buffer
    mov bx, 5
    call scan_string
    call print_newline
    mov di, input_buffer
    mov bx, num2
    call convert_to_number

    mov ax, [num1]
    xor dx, dx
    mov bx, 100
    mul bx
    mov bx, [num2]
    div bx

    mov di, result_str
    call convert_to_string

    mov si, result_msg
    call print_string
    mov si, result_str
    call print_string
    mov si, percent_msg
    call print_string
    call print_newline

    mov si, when_done
    call print_string
    call print_newline
    mov ah, 0
    int 0x16

    popa
    ret

section .data
welcome_msg db '---------- [ Percentages v0.1 ] -----------', 13, 10, 0
input_msg   db 'Number 1: ', 0
input2_msg  db 'Number 2: ', 0
result_msg  db 'Result: ', 0
percent_msg db '%', 0
help_msg    db 'This programm will calculate how many percent is num 1 out of num 2. If ', 13, 10
            db 'malfunctioning then make sure num 2 is greater than num 1', 13, 10, 0
when_done   db 'When done press any key', 13, 10, 0

%include "programs/lib/io.inc"
%include "programs/lib/utils.inc"
