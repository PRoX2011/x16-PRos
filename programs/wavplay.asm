; ==================================================================
; WAV Player for x16-PRos 
;
; Based on Leonardo Ono's playpcm.asm (https://github.com/leonardo-ono/Assembly8086SBHardwareLevelDspProgrammingTest/blob/master/playpcm2.asm)
; Ported and improved by PRoX2011
;
; Usage: wavplay <filename.wav>
; ==================================================================

		cpu 8086
[BITS 16]
[ORG 8000h]

start:
		mov [filename_ptr], si

	    mov ah, 0x07
		mov bl, 0x0E
		int 0x21

		mov ah, 0x08
		mov si, warning_msg
		int 0x21

		mov ah, 0x01
		mov si, loading_msg
		int 0x21

		; Load WAV file 
		mov ah, 0x10        
		mov si, [filename_ptr]
		mov cx, 43008        
		mov dx, 0x2000        
		int 0x22
		jc .load_error

		; Parse WAV header 
		mov si, 43008
		
		; Check "RIFF" signature
		mov ax, [si]
		cmp ax, 'RI'
		jne .invalid_format
		mov ax, [si+2]
		cmp ax, 'FF'
		jne .invalid_format
		
		; Check "WAVE" format
		mov ax, [si+8]
		cmp ax, 'WA'
		jne .invalid_format
		mov ax, [si+10]
		cmp ax, 'VE'
		jne .invalid_format

		mov ax, [si+40]
		mov [data_size], ax
		mov ax, [si+42]
		mov [data_size+2], ax

		mov ax, [si+24]
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

		mov ax, 0x2000
		mov es, ax
		mov ax, 43008
		add ax, 44
		mov [curr_off], ax

		mov word [sound_index], 0

	.play_loop:
		mov ah, 1
		int 16h
		jnz .stop_playing

		mov bl, 10h
		call sb_write_dsp

		mov si, [curr_off]
		mov bl, [es:si]
		call sb_write_dsp

		inc word [curr_off]
		jnz .no_seg_update
		mov ax, es
		add ax, 0x1000
		mov es, ax
	.no_seg_update:

		mov cx, [delay_value]
	.delay:
		nop
		loop .delay

		inc word [sound_index]
		
		mov ax, [sound_index]
		mov dx, [sound_index+2]
		cmp dx, [data_size+2]
		ja .stop_playing
		jb .play_loop
		cmp ax, [data_size]
		jb .play_loop

	.stop_playing:
		mov ah, 0
		int 16h

		call sb_speaker_off

		mov ah, 0x02
		mov si, done_msg
		int 0x21

		ret

	.load_error:
		mov ah, 0x04
		mov si, load_error_msg
		int 0x21
		mov ax, 4c01h
		int 21h

	.invalid_format:
		mov ah, 0x04
		mov si, format_error_msg
		int 0x21
		mov ax, 4c01h
		int 21h

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
sound_index    dd 0
data_size      dd 0
sample_rate    dw 0
delay_value    dw 0
curr_off       dw 0

warning_msg      db '+======================================================+', 10, 13
                 db '|                  !! WARNING !!                       |', 10, 13
                 db '|      wavplay only supports files < 512kib            |', 10, 13
				 db '| if your file is larger, playback will not be correct |', 10, 13,
				 db '+======================================================+', 10, 13, 10, 13, 0
loading_msg      db '  Loading WAV file...', 10, 13, 0
playing_msg      db '  Playing WAV file. ', 0
any_key_msg      db 'Press any key to stop.', 10, 13, 0
done_msg         db '  Playback finished.', 10, 13, 0
load_error_msg   db '  Error: Could not load file!', 10, 13, 0
format_error_msg db '  Error: Invalid WAV format!', 10, 13, 0