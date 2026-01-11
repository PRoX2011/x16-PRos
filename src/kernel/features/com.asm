; ==================================================================
; x16-PRos - Compatibility layer with MS DOS programs. 
;            Emulates MS DOS system calls through PRos kernel functions
; ==================================================================

int20_handler:
    cli      
    
    mov ax, 0x2000       
    mov ds, ax
    mov es, ax

    mov ss, [com_ss_save]
    mov sp, [com_stack_save]
    
    sti    

    mov dx, .finished_msg
    mov ah, 0x09
    int 0x21

    ; Wait for key press
    mov ah, 0
    int 16h

    call api_output_init
    call EnableMouse
    call load_and_apply_theme

    jmp get_cmd

.finished_msg db 'Program finished. Press any key to contine...', 10, 13, '$'

api_dos_init:
    pusha
    push es
    
    xor ax, ax
    mov es, ax
    mov word [es:0x21*4], int21_dos_handler 
    mov word [es:0x21*4+2], cs           

    pop es
    popa
    ret

int21_dos_handler:
    enable_interrupts:
    sti              

    cmp ah, 0x01
    je .input_char_echo
    cmp ah, 0x02
    je .output_char
    cmp ah, 0x06
    je .direct_console_io
    cmp ah, 0x07
    je .input_char_no_echo
    cmp ah, 0x08
    je .input_char_no_echo
    cmp ah, 0x09
    je .output_string_dollar
    cmp ah, 0x0A
    je .buffered_input
    cmp ah, 0x0B
    je .check_input_status
    cmp ah, 0x4C
    je .terminate
    
    iret

.input_char_echo:
    mov ah, 0x00
    int 0x16           
    push ax
    mov dl, al
    mov ah, 0x02
    int 0x21           
    pop ax
    iret

.output_char:
    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F    
    int 0x10
    pop bx
    pop ax
    iret

.input_char_no_echo:
    mov ah, 0x00
    int 0x16
    iret

.check_input_status:
    mov ah, 0x01
    int 0x16
    jz .no_key_available
    mov al, 0xFF        
    iret
.no_key_available:
    mov al, 0x00        
    iret

.direct_console_io:
    cmp dl, 0xFF
    je .direct_input

    push ax
    push bx
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    pop bx
    pop ax
    iret

.direct_input:
    mov ah, 0x01
    int 0x16
    jz .no_char_ready

    mov ah, 0x00
    int 0x16
    clc                
    iret

.no_char_ready:
    xor al, al        
    or al, al        
    iret

.output_string_dollar:
    push ax
    push bx
    push si
    
    mov si, dx     
.dos_print_loop:
    lodsb              
    cmp al, '$'        
    je .dos_print_done
    
    mov ah, 0x0E
    mov bl, 0x0F
    int 0x10
    jmp .dos_print_loop

.dos_print_done:
    pop si
    pop bx
    pop ax
    iret

.buffered_input:
    pusha
    mov si, dx   

    xor cx, cx
    mov cl, [si]
    cmp cl, 0
    je .buf_done     

    mov di, dx          
    add di, 2       
    xor bx, bx     

.buf_input_loop:
    mov ah, 0x00
    int 0x16        

    cmp al, 0x0D      
    je .buf_enter
    
    cmp al, 0x08      
    je .buf_backspace

    cmp bl, cl
    jae .buf_input_loop 

    mov ah, 0x0E
    push bx
    mov bl, 0x0F
    int 0x10
    pop bx

    mov [di + bx], al
    inc bx
    jmp .buf_input_loop

.buf_backspace:
    cmp bx, 0
    je .buf_input_loop 

    dec bx
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .buf_input_loop

.buf_enter:
    mov byte [di + bx], 0x0D
    
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10

    mov [si + 1], bl

.buf_done:
    popa
    iret

.terminate:
    int 0x20
    iret