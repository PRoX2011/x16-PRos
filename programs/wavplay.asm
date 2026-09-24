; ==================================================================
; WAV Player for x16-PRos
;
; Based on Leonardo Ono's playpcm.asm (https://github.com/leonardo-ono/Assembly8086SBHardwareLevelDspProgrammingTest/blob/master/playpcm2.asm)
; Ported and improved by PRoX2011
;
; The file is streamed off the volume a chunk at a time (INT 0x22
; function 0x15), so its size is not limited by free memory.
;
; Usage: wavplay <filename.wav>
; ==================================================================

		cpu 8086
[BITS 16]
[ORG 8000h]

WAV_BUF_SEG   equ 0x3000
WAV_CHUNK     equ 0xF000		; bytes pulled off the volume at a time
WAV_DATA_OFF  equ 44

start:
		mov [filename_ptr], si

	    mov ah, 0x07
		mov bl, 0x0E
		int 0x21

		mov ah, 0x01
		mov si, loading_msg
		int 0x21

		; Open the file for streaming
		mov ax, 0x1500
		mov si, [filename_ptr]
		int 0x22
		jc .load_error
		mov [handle], bx

		call read_chunk
		cmp ax, WAV_DATA_OFF
		jbe .invalid_format

		mov [buf_left], ax
		sub word [buf_left], WAV_DATA_OFF

		mov ax, WAV_BUF_SEG
		mov es, ax
		xor si, si

		; Check "RIFF" signature
		mov ax, [es:si]
		cmp ax, 'RI'
		jne .invalid_format
		mov ax, [es:si+2]
		cmp ax, 'FF'
		jne .invalid_format

		; Check "WAVE" format
		mov ax, [es:si+8]
		cmp ax, 'WA'
		jne .invalid_format
		mov ax, [es:si+10]
		cmp ax, 'VE'
		jne .invalid_format

		mov ax, [es:si+40]
		mov [data_size], ax
		mov ax, [es:si+42]
		mov [data_size+2], ax

		mov ax, [es:si+24]
		mov [sample_rate], ax

		call calculate_delay

		mov ah, 0x01
		mov si, playing_msg
		int 0x21

		mov ah, 0x03
		mov si, any_key_msg
		int 0x21

		call sb_reset

		call sb_speaker_on

		mov word [curr_off], WAV_DATA_OFF

	.play_loop:
		mov ah, 1
		int 16h
		jnz .stop_playing

		cmp word [buf_left], 0
		jne .have_data

		call read_chunk
		cmp ax, 0
		je .stop_playing
		mov [buf_left], ax
		mov word [curr_off], 0
		mov ax, WAV_BUF_SEG
		mov es, ax

	.have_data:
		mov bl, 10h
		call sb_write_dsp

		mov si, [curr_off]
		mov bl, [es:si]
		call sb_write_dsp

		inc word [curr_off]
		dec word [buf_left]

		mov cx, [delay_value]
	.delay:
		nop
		loop .delay

		sub word [data_size], 1
		sbb word [data_size+2], 0
		mov ax, [data_size]
		or ax, [data_size+2]
		jnz .play_loop

	.stop_playing:
		mov ah, 1
		int 16h
		jz .no_key
		mov ah, 0
		int 16h
	.no_key:

		call sb_speaker_off

		call close_file

		mov ah, 0x02
		mov si, done_msg
		int 0x21

		ret

	.load_error:
		mov ah, 0x04
		mov si, load_error_msg
		int 0x21
		ret

	.invalid_format:
		call close_file
		mov ah, 0x04
		mov si, format_error_msg
		int 0x21
		ret

; ==================================================================
; read_chunk - pull the next piece of the file into WAV_BUF_SEG:0000
; OUT: AX = bytes read, 0 at end of file
; ==================================================================
read_chunk:
		push bx
		push cx
		push dx
		push di

		mov ax, 0x1501
		mov bx, [handle]
		mov cx, WAV_CHUNK
		mov dx, WAV_BUF_SEG
		xor di, di
		int 0x22
		jnc .done
		xor ax, ax

	.done:
		pop di
		pop dx
		pop cx
		pop bx
		ret

close_file:
		push ax
		push bx
		mov ax, 0x1504
		mov bx, [handle]
		int 0x22
		pop bx
		pop ax
		ret

; ==================================================================
; Sound Blaster Functions
; ==================================================================

; Reset Sound Blaster DSP
sb_reset:
		push ax
		push cx
		push dx

		mov dx, 226h
		mov al, 1
		out dx, al

		mov cx, 100
	.wait1:
		nop
		loop .wait1

		mov al, 0
		out dx, al

		mov cx, 100
	.wait2:
		nop
		loop .wait2

		mov dx, 22Ah
		mov cx, 1000
	.wait_ready:
		in al, dx
		test al, 10000000b
		jz .wait_ready_next

		mov dx, 22Ah
		in al, dx
		cmp al, 0AAh
		je .reset_ok

	.wait_ready_next:
		loop .wait_ready

	.reset_ok:
		pop dx
		pop cx
		pop ax
		ret

; Turn on SB speakers
sb_speaker_on:
		push bx
		mov bl, 0D1h           ; Speaker on command
		call sb_write_dsp
		pop bx
		ret

; Turn off SB speakers
sb_speaker_off:
		push bx
		mov bl, 0D3h           ; Speaker off command
		call sb_write_dsp
		pop bx
		ret

sb_write_dsp:
		push ax
		push cx
		push dx

		mov dx, 22Ch
		mov cx, 10000
	.busy:
		in al, dx
		test al, 10000000b
		jz .ready
		loop .busy
		jmp .timeout

	.ready:
		mov al, bl
		out dx, al

	.timeout:
		pop dx
		pop cx
		pop ax
		ret

calculate_delay:
        push ax
        push bx
        push dx

        mov word [delay_value], 500

        mov ax, [sample_rate]
        cmp ax, 0
        je .done

        cmp ax, 3000
        jbe .rate_3000
        cmp ax, 4000
        jbe .rate_4000
        cmp ax, 8000
        jbe .rate_8000
        cmp ax, 11025
        jbe .rate_11025
        cmp ax, 16000
        jbe .rate_16000
        cmp ax, 22050
        jbe .rate_22050
        jmp .rate_44100

.rate_3000:
        mov word [delay_value], 500
        jmp .done

.rate_4000:
        mov word [delay_value], 350
        jmp .done

.rate_8000:
        mov word [delay_value], 149
        jmp .done

.rate_11025:
        mov word [delay_value], 107
        jmp .done

.rate_16000:
        mov word [delay_value], 74
        jmp .done

.rate_22050:
        mov word [delay_value], 54
        jmp .done

.rate_44100:
        mov word [delay_value], 27

.done:
        pop dx
        pop bx
        pop ax
        ret


filename_ptr   dw 0
handle         dw 0
buf_left       dw 0
data_size      dd 0
sample_rate    dw 0
delay_value    dw 0
curr_off       dw 0

loading_msg      db '  Loading WAV file...', 10, 13, 0
playing_msg      db '  Playing WAV file. ', 0
any_key_msg      db 'Press any key to stop.', 10, 13, 0
done_msg         db '  Playback finished.', 10, 13, 0
load_error_msg   db '  Error: Could not load file!', 10, 13, 0
format_error_msg db '  Error: Invalid WAV format!', 10, 13, 0