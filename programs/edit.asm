; ################################################################################
; #                                                                              #
; #      Author: <Pektiyaz Talibov>                                              #
; #      Email:  pektiyaztalibov@gmail.com                                       #
; #      Github: github.com/pektiyaz                                             #
; #                                                                              #
; ################################################################################


[BITS 16]
[ORG 0x8000]

section .text
start:
    mov byte [buffer], 0 
    mov WORD [file_size], 0
    
    call get_file_name
    cmp ax, 0
    je .check_file_exists
    ret

.check_file_exists:
    call file_exists

    cmp ah, 0
    jne .load_file
    call create_file


.load_file:
    call load_file 

    mov ax, 0x0003 
    int 0x10

    mov si, buffer
    call strlen
    mov bx, cx
    mov word [cursor_pos], bx


    call refresh_screen

.editor_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x18
    je .exit

    cmp al, 0x08
    je .handle_backspace

    cmp al, 0x0D
    je .handle_enter

    cmp al, 0x01
    je .show_about


    cmp al, 0
    je .handle_special
    cmp al, 0xE0
    je .handle_special


    cmp al, 32
    jl .editor_loop
    call write_char
    call refresh_screen
    jmp .editor_loop

.handle_special:
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    jmp .editor_loop

.up:
    call move_cursor_up
    call refresh_screen
    jmp .editor_loop

.down:
    call move_cursor_down
    call refresh_screen
    jmp .editor_loop


.left:
    call move_left
    call refresh_screen
    jmp .editor_loop

.right:
    call move_right
    call refresh_screen
    jmp .editor_loop

.handle_backspace:
    call do_backspace
    call refresh_screen
    jmp .editor_loop

.handle_enter:
    mov al, 0x0D  
    call write_char
    mov al, 0x0A  
    call write_char
    call refresh_screen
    jmp .editor_loop

.exit:
    mov ax, [original_file_size]
    cmp [file_size], ax
    jne .saveExit

    mov ax, 0x0003
    int 0x10
    ret

.saveExit:

    mov ah, 0x02
    mov bh, 0
    mov dx, 0x1800  
    int 0x10


    mov si, FILE_CHANGED_MESSAGGE
    call print_string

.wait_choice:
    mov ah, 0x00
    int 0x16        

    cmp al, 'y'
    je .do_save
    cmp al, 'Y'
    je .do_save

    cmp al, 'n'
    je .exitWithoutSave        
    cmp al, 'N'
    je .exitWithoutSave

    cmp al, 0x1B    
    je .cancel_exit
    
    jmp .wait_choice

.do_save:
    call write_file 
    ret

.exitWithoutSave:
    mov ax, 0x0003
    int 0x10
    ret

.cancel_exit:
    mov ah, 0x02
    mov bh, 0
    mov dx, 0x1800  
    int 0x10
    call refresh_screen
    jmp .editor_loop

.show_about:
    mov ax, 0x0003
    int 0x10

    mov ah, 0x02
    mov dx, 0x0400
    int 0x10

    mov si, about_box
    call print_string
    
    mov ah, 0x00 
    int 0x16
    call refresh_screen
    jmp .editor_loop

refresh_screen:
    pusha

    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10


    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0000
    int 0x10
    mov si, header_text
    call print_string


    mov ah, 0x02
    mov dx, 0x0100
    int 0x10
    mov si, buffer
    call print_string


    mov ah, 0x02
    mov dx, 0x1800
    int 0x10
    mov si, footer_text
    call print_string



    mov si, buffer
    mov cx, [cursor_pos]
    mov dx, 0x0100 
    
    test cx, cx
    jz .set_hw_cursor
.calc_loop:
    lodsb
    cmp al, 0x0D  
    je .reset_col
    cmp al, 0x0A  
    je .next_line
    
    inc dl        
    cmp dl, 80
    je .next_line
    jmp .next_iter

.reset_col:
    xor dl, dl    
    jmp .next_iter

.next_line:
    inc dh        
    xor dl, dl    

.next_iter:
    loop .calc_loop

.set_hw_cursor:
    mov ah, 0x02
    mov bh, 0
    int 0x10


    
    popa
    ret

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret


write_char:
    pusha
    mov bx, [cursor_pos]

    mov si, buffer
.find_end:
    cmp byte [si], 0
    je .start_shift
    inc si
    jmp .find_end

.start_shift:

    mov di, si
    inc di          
    mov bx, [cursor_pos]
    add bx, buffer  

.shift_loop:
    mov al, [si]    
    mov [di], al    
    cmp si, bx      
    je .insert_now  
    dec si
    dec di
    jmp .shift_loop

.insert_now:
    popa            
    pusha           
    mov bx, [cursor_pos]
    mov [buffer + bx], al 
    inc word [cursor_pos] 
    inc word [file_size]

    mov si, [file_size]
    mov byte [buffer + si], 0 
.done:
    popa
    ret


do_backspace:
    pusha
    mov bx, [cursor_pos]
    test bx, bx
    jz .exit_bs    
    
    dec bx         
    mov [cursor_pos], bx
    

.shift_loop:
    mov al, [buffer + bx + 1] 
    mov [buffer + bx], al 
    inc bx
    cmp al, 0             
    jne .shift_loop       

.exit_bs:
    popa
    ret


move_left:
    cmp word [cursor_pos], 0
    je .done
    dec word [cursor_pos]
.done:
    ret

move_right:
    mov bx, [cursor_pos]
    cmp byte [buffer + bx], 0
    je .done
    inc word [cursor_pos]
.done:
    ret



move_cursor_up:
    pusha
    mov bx, [cursor_pos]
    test bx, bx
    jz .done        


    call get_current_column 
    

    mov di, [cursor_pos]
    call find_line_start
    
    test di, di
    jz .done        


    dec di          
    cmp byte [buffer + di], 0x0D
    jne .skip_cr
    dec di          
.skip_cr:
    

    call find_line_start_at_offset 
    

    mov si, di      
.find_col:
    cmp cx, 0       
    je .found
    mov al, [buffer + si]
    cmp al, 0x0D    
    je .found
    cmp al, 0x0A
    je .found
    cmp al, 0       
    je .found
    
    inc si
    dec cx
    jmp .find_col

.found:
    mov [cursor_pos], si
.done:
    popa
    ret


move_cursor_down:
    pusha

    call get_current_column 
    

    mov si, [cursor_pos]
.find_next_line:
    mov al, [buffer + si]
    test al, al
    jz .done        
    inc si
    cmp al, 0x0A    
    jne .find_next_line
    


.find_col:
    cmp cx, 0
    je .found
    mov al, [buffer + si]
    test al, al
    jz .found       
    cmp al, 0x0D
    je .found       
    cmp al, 0x0A
    je .found
    
    inc si
    dec cx
    jmp .find_col

.found:
    mov [cursor_pos], si
.done:
    popa
    ret




get_current_column:
    mov si, [cursor_pos]
    xor cx, cx
.loop:
    test si, si
    jz .exit
    dec si
    mov al, [buffer + si]
    cmp al, 0x0A
    je .exit
    inc cx
    jmp .loop
.exit:
    ret


find_line_start:
    mov di, [cursor_pos]
find_line_start_at_offset:
.loop:
    test di, di
    jz .exit
    dec di
    mov al, [buffer + di]
    cmp al, 0x0A
    je .found_line_feed
    jmp .loop
.found_line_feed:
    inc di          
.exit:
    ret

get_file_name:
    mov cx, MAX_FILENAME_SIZE
    mov di, file_name
    .loop_next_char:
      
      mov al, [si]
      mov byte [di], al

      cmp al, 0
      je .done

      inc si
      inc di
      loop .loop_next_char

    mov ax, 1
    ret
    .done:
      xor ax, ax
      ret

create_file:
    mov si, file_name
    mov ah, 0x05
    int 0x22
    ret

file_exists:
    mov si, file_name
    mov ah, 0x04
    int 0x22
    jc .not_exists
    mov ah, 1
    ret
    .not_exists:
      xor ah, ah
      ret

delete_file:
    mov ah, 0x06
    mov si, file_name
    int 0x22
    ret

write_file:
    mov si, buffer
    call strlen
    
    xor ax, ax
    call delete_file
    mov ah, 0x03
    mov si, file_name
    mov bx, buffer
    int 0x22
    ret

load_file:
    mov ah, 0x02
    mov si, file_name
    mov cx, buffer
    int 0x22
    mov WORD [file_size], bx
    mov WORD [original_file_size], bx
    ret


strlen:
    xor cx, cx
.count_loop:
    cmp byte [si], 0
    je .end
    inc cx
    inc si
    jmp .count_loop
.end:
    ret






section .data
MAX_FILENAME_SIZE equ 2048
header_text db " ################## PRos Editor v1.0 #######################", 0
footer_text db "[Ctrl+X] Exit  [Ctrl+A] About", 0
FILE_CHANGED_MESSAGGE db "File was changed! do you want to save ? Yes(Y) No(N)", 0xA, 0x0

about_box db " ##################################################", 0x0D, 0x0A
          db " #            P R o s   E d i t o r               #", 0x0D, 0x0A
          db " # ---------------------------------------------- #", 0x0D, 0x0A
          db " #  Developed by: Pektiyaz Talibov                #", 0x0D, 0x0A
          db " #  Email: pektiyaztalibov@gmail.com              #", 0x0D, 0x0A
          db " #  GitHub: @pektiyaz                             #", 0x0D, 0x0A
          db " # ---------------------------------------------- #", 0x0D, 0x0A
          db " #       Press any key to return to editor        #", 0x0D, 0x0A
          db " ##################################################", 0, 0
section .bss
cursor_pos resw 1
original_file_size resw 1
file_size resw 1
file_name resb 2048
buffer     resb 2048
scroll_line resw 1