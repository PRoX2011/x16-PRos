; ==================================================================
; x16-PRos -- PIANO. PC Speaker piano.
; Copyright (C) 2025 PRoX2011
;
; Made by PRoX-dev
; =================================================================

[BITS 16]
[ORG 0x8000]

start:
    call clear_screen
    call draw_interface
    mov si, help_msg
    call print_string
    call print_newline
    
    ; Initialize recording buffer
    mov word [record_count], 0
    mov byte [recording], 0
    mov byte [playing], 0
    mov word [last_note_time], 0

key_loop:
    ; Update status
    call update_status
    
    mov ah, 0x01        ; Check if key available
    int 0x16
    jz .no_key          ; No key pressed
    
    ; Key is available, get it
    mov ah, 0x00
    int 0x16
    
    ; Record time since last note if recording
    cmp byte [recording], 1
    jne .skip_pause_record
    call record_pause
    
.skip_pause_record:
    cmp al, 0x1B    ; ESC
    je exit_program
    
    ; Recording controls
    cmp al, '['
    je toggle_recording
    cmp al, ']'
    je play_recording
    cmp al, '\'
    je clear_recording
    
    ; Check if playing back
    cmp byte [playing], 1
    je key_loop
    
    ; Low octave (zxcvbnm)
    cmp al, 'z'
    je play_C2
    cmp al, 'x'
    je play_D2
    cmp al, 'c'
    je play_E2
    cmp al, 'v'
    je play_F2
    cmp al, 'b'
    je play_G2
    cmp al, 'n'
    je play_A2
    cmp al, 'm'
    je play_B2
    
    ; Mid octave (asdfghjk)
    cmp al, 'a'
    je play_C3
    cmp al, 's'
    je play_D3
    cmp al, 'd'
    je play_E3
    cmp al, 'f'
    je play_F3
    cmp al, 'g'
    je play_G3
    cmp al, 'h'
    je play_A3
    cmp al, 'j'
    je play_B3
    cmp al, 'k'
    je play_C4
    
    ; High octave (qwertyui)
    cmp al, 'q'
    je play_C4
    cmp al, 'w'
    je play_D4
    cmp al, 'e'
    je play_E4
    cmp al, 'r'
    je play_F4
    cmp al, 't'
    je play_G4
    cmp al, 'y'
    je play_A4
    cmp al, 'u'
    je play_B4
    cmp al, 'i'
    je play_C5
    
    ; Black keys (sharps/flats) - row 2
    cmp al, 'S'
    je play_Cs2
    cmp al, 'D'
    je play_Ds2
    cmp al, 'G'
    je play_Fs2
    cmp al, 'H'
    je play_Gs2
    cmp al, 'J'
    je play_As2
    
    ; Black keys - row 3  
    cmp al, 'W'
    je play_Cs3
    cmp al, 'E'
    je play_Ds3
    cmp al, 'T'
    je play_Fs3
    cmp al, 'Y'
    je play_Gs3
    cmp al, 'U'
    je play_As3
    
    ; Black keys - row 1
    cmp al, '2'
    je play_Cs4
    cmp al, '3'
    je play_Ds4
    cmp al, '5'
    je play_Fs4
    cmp al, '6'
    je play_Gs4
    cmp al, '7'
    je play_As4
    
    jmp key_loop

.no_key:
    ; Update time counter when recording
    cmp byte [recording], 1
    jne key_loop
    inc word [last_note_time]
    
    ; Small delay to not overflow counter too fast (~18ms per tick)
    mov dx, 18
    call delay_ms
    jmp key_loop

; ========== Recording Functions ==========
record_pause:
    pusha
    
    ; Check if this is first note
    cmp word [record_count], 0
    je .first_note
    
    ; Check if buffer has space
    cmp word [record_count], 500
    jge .done
    
    ; Get pause duration
    mov ax, [last_note_time]
    cmp ax, 0
    je .done            ; No pause to record
    
    ; Record pause (frequency 0 = pause)
    mov di, record_buffer
    mov cx, [record_count]
    shl cx, 2
    add di, cx
    
    xor ax, ax          ; Frequency 0 = pause
    stosw
    mov ax, [last_note_time]
    
    ; Convert to milliseconds (multiply by 18)
    mov bx, 18
    mul bx
    
    ; Limit max pause to 2000ms
    cmp ax, 2000
    jbe .store_pause
    mov ax, 2000
    
.store_pause:
    stosw               ; Store pause duration
    inc word [record_count]
    
.first_note:
    ; Reset time counter
    mov word [last_note_time], 0
    
.done:
    popa
    ret

toggle_recording:
    cmp byte [recording], 0
    je .start_recording
    ; Stop recording
    mov byte [recording], 0
    mov word [last_note_time], 0
    jmp key_loop
.start_recording:
    ; Clear previous recording
    mov word [record_count], 0
    mov word [last_note_time], 0
    mov byte [recording], 1
    jmp key_loop

play_recording:
    cmp word [record_count], 0
    je key_loop
    
    mov byte [playing], 1
    mov si, record_buffer
    mov cx, [record_count]
    
.play_loop:
    push cx
    push si
    
    ; Get frequency
    lodsw
    mov bx, ax
    
    ; Get duration
    lodsw
    mov dx, ax
    
    ; Check if this is a pause (frequency = 0)
    cmp bx, 0
    je .play_pause
    
    ; Play note
    mov ax, bx
    call set_frequency
    call on_pc_speaker
    call delay_ms
    call off_pc_speaker
    
    ; Small pause between notes
    mov dx, 30
    call delay_ms
    jmp .next_item
    
.play_pause:
    ; Just delay for pause duration
    call delay_ms
    
.next_item:
    pop si
    add si, 4
    pop cx
    loop .play_loop
    
    mov byte [playing], 0
    jmp key_loop

clear_recording:
    mov word [record_count], 0
    mov word [last_note_time], 0
    jmp key_loop

; ========== Note Definitions (divisor values for PC Speaker) ==========
; Octave 2 (Low)
play_C2:
    mov ax, 9121    ; C2
    mov dx, 250
    mov bx, 'C'
    jmp play_note
play_Cs2:
    mov ax, 8609    ; C#2
    mov dx, 250
    mov bx, 'C'
    jmp play_sharp_note
play_D2:
    mov ax, 8126    ; D2
    mov dx, 250
    mov bx, 'D'
    jmp play_note
play_Ds2:
    mov ax, 7670    ; D#2
    mov dx, 250
    mov bx, 'D'
    jmp play_sharp_note
play_E2:
    mov ax, 7239    ; E2
    mov dx, 250
    mov bx, 'E'
    jmp play_note
play_F2:
    mov ax, 6833    ; F2
    mov dx, 250
    mov bx, 'F'
    jmp play_note
play_Fs2:
    mov ax, 6449    ; F#2
    mov dx, 250
    mov bx, 'F'
    jmp play_sharp_note
play_G2:
    mov ax, 6087    ; G2
    mov dx, 250
    mov bx, 'G'
    jmp play_note
play_Gs2:
    mov ax, 5746    ; G#2
    mov dx, 250
    mov bx, 'G'
    jmp play_sharp_note
play_A2:
    mov ax, 5423    ; A2
    mov dx, 250
    mov bx, 'A'
    jmp play_note
play_As2:
    mov ax, 5119    ; A#2
    mov dx, 250
    mov bx, 'A'
    jmp play_sharp_note
play_B2:
    mov ax, 4831    ; B2
    mov dx, 250
    mov bx, 'B'
    jmp play_note

; Octave 3 (Mid)
play_C3:
    mov ax, 4560    ; C3
    mov dx, 250
    mov bx, 'C'
    jmp play_note
play_Cs3:
    mov ax, 4304    ; C#3
    mov dx, 250
    mov bx, 'C'
    jmp play_sharp_note
play_D3:
    mov ax, 4063    ; D3
    mov dx, 250
    mov bx, 'D'
    jmp play_note
play_Ds3:
    mov ax, 3835    ; D#3
    mov dx, 250
    mov bx, 'D'
    jmp play_sharp_note
play_E3:
    mov ax, 3619    ; E3
    mov dx, 250
    mov bx, 'E'
    jmp play_note
play_F3:
    mov ax, 3416    ; F3
    mov dx, 250
    mov bx, 'F'
    jmp play_note
play_Fs3:
    mov ax, 3224    ; F#3
    mov dx, 250
    mov bx, 'F'
    jmp play_sharp_note
play_G3:
    mov ax, 3043    ; G3
    mov dx, 250
    mov bx, 'G'
    jmp play_note
play_Gs3:
    mov ax, 2873    ; G#3
    mov dx, 250
    mov bx, 'G'
    jmp play_sharp_note
play_A3:
    mov ax, 2711    ; A3
    mov dx, 250
    mov bx, 'A'
    jmp play_note
play_As3:
    mov ax, 2559    ; A#3
    mov dx, 250
    mov bx, 'A'
    jmp play_sharp_note
play_B3:
    mov ax, 2415    ; B3
    mov dx, 250
    mov bx, 'B'
    jmp play_note

; Octave 4 (High)
play_C4:
    mov ax, 2280    ; C4
    mov dx, 250
    mov bx, 'C'
    jmp play_note
play_Cs4:
    mov ax, 2152    ; C#4
    mov dx, 250
    mov bx, 'C'
    jmp play_sharp_note
play_D4:
    mov ax, 2031    ; D4
    mov dx, 250
    mov bx, 'D'
    jmp play_note
play_Ds4:
    mov ax, 1917    ; D#4
    mov dx, 250
    mov bx, 'D'
    jmp play_sharp_note
play_E4:
    mov ax, 1809    ; E4
    mov dx, 250
    mov bx, 'E'
    jmp play_note
play_F4:
    mov ax, 1715    ; F4
    mov dx, 250
    mov bx, 'F'
    jmp play_note
play_Fs4:
    mov ax, 1612    ; F#4
    mov dx, 250
    mov bx, 'F'
    jmp play_sharp_note
play_G4:
    mov ax, 1521    ; G4
    mov dx, 250
    mov bx, 'G'
    jmp play_note
play_Gs4:
    mov ax, 1436    ; G#4
    mov dx, 250
    mov bx, 'G'
    jmp play_sharp_note
play_A4:
    mov ax, 1355    ; A4
    mov dx, 250
    mov bx, 'A'
    jmp play_note
play_As4:
    mov ax, 1279    ; A#4
    mov dx, 250
    mov bx, 'A'
    jmp play_sharp_note
play_B4:
    mov ax, 1207    ; B4
    mov dx, 250
    mov bx, 'B'
    jmp play_note
play_C5:
    mov ax, 1140    ; C5
    mov dx, 250
    mov bx, 'C'
    jmp play_note

; ========== Play Note ==========
play_sharp_note:
    push ax
    push dx
    push bx
    call highlight_sharp_key
    pop bx
    pop dx
    pop ax
    jmp play_note_common

play_note:
    push ax
    push dx
    push bx
    call highlight_white_key
    pop bx
    pop dx
    pop ax

play_note_common:
    push ax
    push dx
    
    ; Record note if recording
    cmp byte [recording], 1
    jne .skip_record
    
    cmp word [record_count], 500
    jge .skip_record
    
    mov di, record_buffer
    mov cx, [record_count]
    shl cx, 2
    add di, cx
    
    stosw           ; Store frequency
    mov ax, dx
    stosw           ; Store duration
    
    inc word [record_count]
    
    ; Reset pause timer after recording note
    mov word [last_note_time], 0

.skip_record:
    pop dx
    pop ax
    
    call set_frequency
    call on_pc_speaker
    call delay_ms
    call off_pc_speaker
    
    jmp key_loop

; ========== Visual Functions ==========
draw_interface:
    mov si, title_msg
    call print_string
    ret

highlight_white_key:
    ret

highlight_sharp_key:
    ret

update_status:
    pusha
    mov dh, 20
    mov dl, 0
    call move_cursor
    
    cmp byte [recording], 1
    je .show_recording
    cmp word [record_count], 0
    je .show_ready
    jmp .show_recorded
    
.show_recording:
    mov si, .rec_msg
    call print_string_red
    jmp .show_count
    
.show_recorded:
    mov si, .saved_msg
    call print_string_green
    jmp .show_count
    
.show_ready:
    mov si, .ready_msg
    call print_string
    popa
    ret
    
.show_count:
    mov si, .notes_msg
    call print_string
    mov ax, [record_count]
    call print_decimal
    mov si, .notes_suffix
    call print_string
    
    popa
    ret

.rec_msg db '[REC] ', 0
.saved_msg db '[SAVED] ', 0
.ready_msg db '[READY]                              ', 0
.notes_msg db 'Items: ', 0
.notes_suffix db '   ', 0

; ========== IO Functions ==========
clear_screen:
    mov ax, 0x12
    int 0x10
    ret

print_string:
    mov ah, 0x0E
    mov bl, 0x0F
.loop:
    lodsb 
    cmp al, 0
    je .done
    cmp al, 10
    je .newline
    int 0x10
    jmp .loop
.newline:
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    jmp .loop
.done:
    ret

print_string_red:
    mov ah, 0x0E
    mov bl, 0x0C
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

print_string_green:
    mov ah, 0x0E
    mov bl, 0x0A
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret
    
print_newline:
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A 
    int 0x10
    ret

move_cursor:
    pusha
    mov ah, 0x02
    mov bh, 0
    int 0x10
    popa
    ret

print_decimal:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 0
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .divide
    
.print:
    pop dx
    add dl, '0'
    mov ah, 0x0E
    mov al, dl
    mov bl, 0x0F
    int 0x10
    loop .print
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

exit_program:
    call clear_screen
    ret

; ========== PC Speaker Functions ==========
on_pc_speaker:
    pusha
    in al, 0x61
    or al, 0x03
    out 0x61, al
    popa
    ret

off_pc_speaker:
    pusha
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

set_frequency:
    push ax
    mov al, 0xB6
    out 0x43, al
    pop ax
    out 0x42, al
    mov al, ah
    out 0x42, al
    ret

delay_ms:
    pusha
    mov ax, dx
    mov cx, 1000
    mul cx
    mov cx, dx
    mov dx, ax
    mov ah, 0x86
    int 0x15
    popa
    ret

; ========== Data Section ==========
title_msg db 0xC9, 60 dup(0xCD), 0xBB, 10, 13
          db 0xBA, '           PRos Piano v2.0 - PC Speaker                     ', 0xBA, 10, 13
          db 0xC0, 60 dup(0xCD), 0xBC, 10, 13, 0

help_msg  db 0xC9, 60 dup(0xCD), 0xBB, 10, 13
          db 0xBA, ' Play notes with keyboard                                   ', 0xBA, 10, 13
          db 0xC3, 60 dup(0xC4), 0xB4, 10, 13
          db 0xBA, ' Low Octave:    Z X C V B N M         (white keys)          ', 0xBA, 10, 13
          db 0xBA, '                 S D   G H J          (black keys/sharps)   ', 0xBA, 10, 13
          db 0xBA, ' Mid Octave:    A S D F G H J K       (white keys)          ', 0xBA, 10, 13
          db 0xBA, '                 W E   T Y U          (black keys/sharps)   ', 0xBA, 10, 13
          db 0xBA, ' High Octave:   Q W E R T Y U I       (white keys)          ', 0xBA, 10, 13
          db 0xBA, '                 2 3   5 6 7          (black keys/sharps)   ', 0xBA, 10, 13
          db 0xC3, 60 dup(0xC4), 0xB4, 10, 13
          db 0xBA, ' Recording:   [  - Start/Stop    ]   - Playback             ', 0xBA, 10, 13
          db 0xBA, '              \  - Clear         ESC - Quit                 ', 0xBA, 10, 13
          db 0xBA, ' Pauses between notes will automatically recorded!          ', 0xBA, 10, 13
          db 0xC0, 60 dup(0xCD), 0xBC, 10, 13, 0

recording        db 0
playing          db 0
record_count     dw 0
last_note_time   dw 0
record_buffer    times 2000 dw 0