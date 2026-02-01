; ==================================================================
; x16-PRos - PC Speaker functions for x16-PRos kernel
; Copyright (C) 2025 PRoX2011
; ==================================================================

; -----------------------------
; Turns on PC speaker
; IN  : Nothing
turn_on_pc_speaker:
    pusha
    in al, 0x61
    or al, 0x03
    out 0x61, al
    popa
    ret

; -----------------------------
; Turns off PC speaker
; IN  : Nothing
turn_off_pc_speaker:
    pusha
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    popa
    ret

; -----------------------------
; Play melody
; IN  : SI = melody location
play_melody:
    pusha
.next_note:
    mov ax, [si]
    cmp ax, 0
    je .done
    mov dx, [si+2]
    add si, 4
    call set_frequency
    call turn_on_pc_speaker
    call delay_ms
    call turn_off_pc_speaker
    jmp .next_note
.done:
    popa
    ret

; ------ Sets frequency ------
set_frequency:
    push ax
    mov al, 0xB6
    out 0x43, al
    pop ax
    out 0x42, al
    mov al, ah
    out 0x42, al
    ret