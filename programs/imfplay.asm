; ==================================================================
; very simple IMF player (for type-1)
;
; https://moddingwiki.shikadi.net/wiki/IMF_Format
; http://www.vgmpf.com/Wiki/index.php?title=IMF
; MID2IMF2 - http://k1n9duk3.shikadi.net/imftools.html
; Made by Leo-ono and PRoX-dev
;
; Usage: imfplay <filename.imf>
; ==================================================================

		cpu 8086
[BITS 16]
[ORG 8000h]

IMF_BUF_SEG equ 0x3000
IMF_CHUNK   equ 0xF000


start:
		mov [filename_ptr], si

		mov ah, 0x01
		mov si, loading_msg
		int 0x21

		mov ax, 0x1500
		mov si, [filename_ptr]
		int 0x22
		jc .not_found
		mov [handle], bx

		call read_chunk
		cmp ax, 2
		jb .not_found

		mov ah, 0x01
		mov si, playing_msg
		int 0x21

		mov ah, 0x03
		mov si, any_key_msg
		int 0x21

		call reset_all_registers
		call start_fast_clock

		; imf type-1: first word is the data length
		call get_byte
		mov cl, al
		call get_byte
		mov ch, al
		mov [music_length], cx

		mov word [bytes_read], 0

	.next_note:
		cmp byte [at_eof], 0
		jne .exit

		; select opl2 register through port 388h
		call get_byte
		mov bl, al ; opl2 register

		call get_byte
		mov bh, al ; data

		call write_adlib

		call get_byte
		mov cl, al
		call get_byte
		mov ch, al
		mov bx, cx

		add word [bytes_read], 4

	.repeat_delay:
		call delay
		; if keypress then exit
		mov ah, 1
		int 16h
		jnz .exit

		dec bx
		jg .repeat_delay

		mov ax, [bytes_read]
		cmp ax, [music_length]
		jb .next_note

		jmp .exit

	.not_found:
	    mov ah, 0x04
	    mov si, notfound_msg
		int 0x21

		mov ah, 0x05
		int 0x21

		jmp .exit

	.exit:
		call close_file
		call stop_fast_clock
		call reset_all_registers

		mov ax, 4c00h
		int 21h

; ==================================================================
; get_byte - next byte of the file, refilling the buffer as needed
; OUT: AL = byte, 0 once the file runs out (at_eof is set)
; ==================================================================
get_byte:
		push si
		push es

		cmp word [buf_left], 0
		jne .have
		call read_chunk
		test ax, ax
		jz .eof

	.have:
		mov ax, IMF_BUF_SEG
		mov es, ax
		mov si, [curr_off]
		mov al, [es:si]
		inc word [curr_off]
		dec word [buf_left]
		pop es
		pop si
		ret

	.eof:
		mov byte [at_eof], 1
		xor al, al
		pop es
		pop si
		ret

; ==================================================================
; read_chunk - pull the next piece of the file into IMF_BUF_SEG:0000
; OUT: AX = bytes read, 0 at end of file
; ==================================================================
read_chunk:
		push bx
		push cx
		push dx
		push di

		mov ax, 0x1501
		mov bx, [handle]
		mov cx, IMF_CHUNK
		mov dx, IMF_BUF_SEG
		xor di, di
		int 0x22
		jnc .ok
		xor ax, ax
	.ok:
		mov [buf_left], ax
		mov word [curr_off], 0

		pop di
		pop dx
		pop cx
		pop bx
		ret

close_file:
		push ax
		push bx
		mov bx, [handle]
		test bx, bx
		jz .none
		mov ax, 0x1504
		int 0x22
		mov word [handle], 0
	.none:
		pop bx
		pop ax
		ret

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
handle       dw 0
buf_left     dw 0
curr_off     dw 0
bytes_read   dw 0
at_eof       db 0

loading_msg  db '  Loading IMF file...', 10, 13, 0
playing_msg  db '  Playing IMF file. ', 0
any_key_msg  db 'Press any key to stop.', 10, 13, 0
notfound_msg db 'File not found', 0