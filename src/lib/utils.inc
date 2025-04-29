%ifndef UTILS
%define UTILS

; Compare two Strings
; si - 1st string
; di - 2nd string
compare_strings:
    xor cx, cx
.next_char:
    lodsb               
    cmp al, [di]        
    jne .not_equal      
    cmp al, 0           
    je .equal           
    inc di              
    jmp .next_char      
.not_equal:
    ret                 
.equal:
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
    jb .error
    cmp al, '9'
    ja .error
    imul cx, 10       
    add cx, ax        
    jmp .convert_loop
.done_convert:
    mov [bx], cx  
    ret
.error:
    mov al, 1    ;Пометка об ошибке
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
 
; Set cursor position
set_cursor_pos:
    mov ah, 2h
    xor bh, bh
    int 10h
    ret
	
%endif
