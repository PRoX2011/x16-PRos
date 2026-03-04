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

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x02
    mov si, help_msg
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, input_msg
    int 0x21
    mov si, input_buffer
    mov bx, 5
    call scan_string
    mov ah, 0x05
    int 0x21
    mov di, input_buffer
    mov bx, num1
    call convert_to_number

    mov ah, 0x01
    mov si, input2_msg
    int 0x21
    mov si, input_buffer
    mov bx, 5
    call scan_string
    mov ah, 0x05
    int 0x21
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

    mov ah, 0x01
    mov si, result_msg
    int 0x21
    mov ah, 0x01
    mov si, result_str
    int 0x21
    mov ah, 0x01
    mov si, percent_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    
    mov ah, 0x01
    mov si, when_done
    int 0x21
    mov ah, 0x05
    int 0x21
    mov ah, 0
    int 0x16

    popa
    ret

; Convert String to Number
; di - buffer
; bx - to save
convert_to_number:
    mov si, di
    xor ax, ax
    xor cx, cx
.convert_loop:
    lodsb
    cmp al, 0
    je .done_convert
    sub al, '0'
    imul cx, 10
    add cx, ax
    jmp .convert_loop
.done_convert:
    mov [bx], cx
    ret

; Scan String From Input
; si - buffer
; bx - max count
scan_string:
    mov di, si
    xor cx, cx
.read_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .done_read
    cmp al, 0x08
    je .handle_backspace
    cmp cx, bx
    jge .done_read
    stosb
    mov ah, 0x0E
    mov bl, 0x1F
    int 0x10
    inc cx
    jmp .read_loop

.handle_backspace:
    cmp di, si
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

; Number To String
; ax - number
; di - buffer [6 bytes]
convert_to_string:
    mov si, di          
    test ax, ax         
    jnz .non_zero       
    mov byte [di], '0'  
    inc di              
    jmp .terminate      

.non_zero:
    mov bx, 10          
    xor cx, cx          

.extract_digits:
    xor dx, dx          
    div bx              
    add dl, '0'         
    push dx             
    inc cx              
    test ax, ax         
    jnz .extract_digits 

.reverse_digits:
    pop dx              
    mov [di], dl        
    inc di              
    loop .reverse_digits

.terminate:
    mov byte [di], 0              
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