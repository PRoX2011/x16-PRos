; ==================================================================
; very simple IMF player (for type-1)
;
; https://moddingwiki.shikadi.net/wiki/IMF_Format
; http://www.vgmpf.com/Wiki/index.php?title=IMF
; MID2IMF2 - http://k1n9duk3.shikadi.net/imftools.html
; Made by Leo-ono and PRoX-dev
; ==================================================================

		cpu 8086
[BITS 16]
[ORG 8000h]
		
		

start:
		mov [filename_ptr], si

		mov ah, 0x01
		mov si, loading_msg
		int 0x21

		mov ah, 0x10
        mov si, [filename_ptr]
        mov cx, 43008    
        mov dx, 0x2000    
        int 22h

		mov ah, 0x01
		mov si, playing_msg
		int 0x21

		mov ah, 0x03
		mov si, any_key_msg
		int 0x21

		call reset_all_registers
		call start_fast_clock
		
		; imf type-1: first word is the data length
		mov dx, [43008]
		mov [music_length], dx

		; if imf is type-1 then index starts at 2
		mov si, 2 ; current index for music_data
		
	.next_note:
		; select opl2 register through port 388h
		mov bl, [si + 43008 + 0] ; opl2 register
		mov bh, [si + 43008 + 1] ; data
		call write_adlib

		mov bx, [si + 43008 + 2]
		add si, 4
		
	.repeat_delay:
		call delay
		; if keypress then exit
		mov ah, 1
		int 16h
		jnz .exit
	
		dec bx
		jg .repeat_delay
		
		cmp si, [music_length]
		jb .next_note
		
	.exit:
		call stop_fast_clock
		call reset_all_registers
		
		mov ax, 4c00h
		int 21h

reset_all_registers:
		mov bl, 0h
		mov bh, 0
	.next_register:
		; bl = register
		; bh = value
		call write_adlib
		inc bl
		cmp bl, 0f5h
		jbe .next_register
	.end:
		ret

; bl = register
; bh = value
write_adlib:
		push ax
		push bx
		push cx
		push dx
		
		mov dx, 388h
		mov al, bl
		out dx, al

		mov dx, 389h

		mov cx, 6
	.delay_1:
		in al, dx
		loop .delay_1

		mov al, bh
		out dx, al

		mov cx, 35
	.delay_2:
		in al, dx
		loop .delay_2
		
		pop dx
		pop cx
		pop bx
		pop ax
		ret
			
; count = 1193180 / sampling_rate
; sampling_rate = n cycles per second
; count = 1193180 / 140  = 214a (in hex) 
; count = 1193180 / 560  =  852 (in hex) 
; count = 1193180 / 700  =  6a8 (in hex) 
; count = 1193180 / 2000 =  254 (in hex) 
; count = 1193180 / 8000 =   95 (in hex) 
start_fast_clock:
		cli
		mov al, 36h
		out 43h, al
		mov al, 0a8h ; low 
		out 40h, al
		mov al, 06h ; high
		out 40h, al
		sti
		ret

stop_fast_clock:
		cli
		mov al, 36h
		out 43h, al
		mov al, 0h ; low 
		out 40h, al
		mov al, 0h ; high
		out 40h, al
		sti
		ret
		
; delay 1/sampling_rate seconds
delay:
		push es
		mov ax, 0
		mov es, ax
	.delay:
		mov ax, [es:46ch] ; system time
		cmp ax, [last_time]
		je .delay
		mov [last_time], ax
		pop es
		ret
		
last_time    dw 0	
music_length dw 0	
filename_ptr dw 0

loading_msg  db '  Loading IMF file...', 10, 13, 0
playing_msg  db '  Playing IMF file. ', 0
any_key_msg  db 'Press any key to stop.', 10, 13, 0