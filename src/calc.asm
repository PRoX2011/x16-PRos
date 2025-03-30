[BITS 16]
[ORG 800h]
jmp start

%include "src/lib/io.inc"
%include "src/lib/utils.inc"

start:
        pusha
        mov ax, 0x03
        int 0x10
        popa
    
    	mov dl, 0 
    	mov dh, 0
    	call set_cursor_pos

    	mov bp, wmsg
    	mov cx, 80
    	call print_message
    	
	call print_newline
	call calc_cycle
	ret
	
	
calc_cycle:
	mov ax, [step]
	cmp ax, 0
	je .step0			; input num 1
	cmp ax, 1
	je .step1			; imput num 2
	cmp ax, 2
	je .step2			; operation
	cmp ax, 3
	je .step3			; print result
	
	mov si, quit_msg
	call print_string_green
	call print_newline
	; check exit
	mov ah, 10h
    int 16h
	
	cmp al, 1Bh
    jz .end_cycle
	
	mov al, 0
	mov [step], al
	
	jmp calc_cycle
	
	
.end_cycle:
	int 0x19 
	ret
	

; STEP0 - Number 1	
.step0:
	mov si, inpn1
	call print_string

	mov si, input_buffer
	mov bx, 4
	call scan_string
	call print_newline
	
	mov di, input_buffer
	mov bx, num1
	call convert_to_number
        cmp al, 1   ;Проверка на ошибку
        je .error
	
	mov al, [step]
	inc al
	mov [step], al
	
	jmp calc_cycle


; STEP1 - Number 2
.step1:
	mov si, inpn2
	call print_string

	mov si, input_buffer
	mov bx, 4
	call scan_string
	call print_newline
	
	mov di, input_buffer
	mov bx, num2
	call convert_to_number
        cmp al, 1   ;Проверка на ошибку
        je .error
	
	mov al, [step]
	inc al
	mov [step], al
	
	jmp calc_cycle

; STEP2 - Operation Select
.step2:
	mov si, select_mode
	call print_string_green

	mov si, input_buffer
	mov bx, 4
	call scan_string
	call print_newline
	
	mov di, input_buffer
	mov bx, mode
	call convert_to_number
	
	mov al, [step]
	inc al
	mov [step], al
	
	jmp calc_cycle


; STEP3 - Result
.step3:
	mov si, result_prompt
	call print_string
	
	mov ax, [mode]
	cmp ax, 1
	je .mode_1
	cmp ax, 2
	je .mode_2
	cmp ax, 3
	je .mode_3
	cmp ax, 4
	je .mode_4
	
	jmp .mode_err

.mode_1:
	mov ax, [num1]
	mov bx, [num2]
	add ax, bx
	mov di, result_str
	call convert_to_string
	
	mov si, result_str
	call print_string
	call print_newline
	mov si, idk
	call print_string_green
	call print_newline
	jmp .step3_end
	
.mode_2:
	mov ax, [num1]
	mov bx, [num2]
	sub ax, bx
	mov di, result_str
	call convert_to_string
	
	mov si, result_str
	call print_string
	call print_newline
	mov si, idk
	call print_string_green
	call print_newline
	jmp .step3_end
	
.mode_3:
	mov ax, [num1]
	mov bx, [num2]
	mul bx
	mov di, result_str
	call convert_to_string
	
	mov si, result_str
	call print_string
	call print_newline
	mov si, idk
	call print_string_green
	call print_newline
	jmp .step3_end
	
	
.mode_4:
	xor dx, dx
	mov ax, [num1]
	mov bx, [num2]
	div bx
	mov di, result_str
	call convert_to_string
	
	mov si, result_str
	call print_string_cyan
	call print_newline
	mov si, idk
	call print_string_green
	call print_newline
	jmp .step3_end


.mode_err:
	mov si, error_mode_msg
	call print_string_red
	
	jmp .step3_end

.step3_end:
	mov al, [step]
	inc al
	mov [step], al

	jmp calc_cycle
.error:
        mov si, error_inp_msg
        call print_string_red

        jmp calc_cycle
	
print_message:
    mov bl, 0x1F
    mov ax, 1301h
    int 10h
    ret
		
; --DATA--
wmsg db 'PRos calculator v0.1                                                           ', 13, 10, 0
inpn1 db "Enter a first num: ", 0
inpn2 db "Enter a second num: ", 0
result_prompt db "Result: ", 0
idk db "==========================", 0
quit_msg 	db "Press: ", 10, 13
			db "ESC - exit", 10, 13
			db "Any key - continue", 10, 13
			db 0
select_mode db "Select operation:", 10, 13
			db "1 - add", 10, 13
			db "2 - sub", 10, 13
			db "3 - mul", 10, 13
			db "4 - div", 10, 13
			db 0

error_mode_msg db "Unknown operation", 10, 13, 0
error_inp_msg db "Wrong input, try again", 10, 13, 0

mode resw 1
step resw 1
input_buffer db 6 dup(0)
num1 resw 1
num2 resw 1
result_str db 7 dup(0)

