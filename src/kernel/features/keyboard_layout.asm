; ==================================================================
; x16-PRos - Keyboard layout support (EN / RU) and program abort
; Copyright (C) 2025 PRoX2011
;
; INT 0x16 hook: translates the returned character to the active
; layout (0 = EN, 1 = RU, CP866). Ctrl+Shift toggles the layout.
; The hook chains to the BIOS handler (the standard TSR technique).
;
; Program abort: while a BIN/COM/EXE/PLE program runs, Ctrl+Shift+F1
; aborts it and returns to the shell. The check runs on the BIOS
; timer tick (INT 0x1C) so it works even while a game is busy-looping
; and never calls INT 0x16.
; ==================================================================

keyboard_layout db 0          ; 0 = EN, 1 = RU
old_int16_vector dd 0         ; far pointer to the previous INT 0x16 handler

; ==================================================================
; INIT_KEYBOARD_LAYOUT - saves the old INT 0x16 vector, installs the
; translation handler, and hooks INT 0x1C for the abort hotkey.
; Called once during init.
; ==================================================================
init_keyboard_layout:
    push ax
    push es
    xor ax, ax
    mov es, ax
    cli
    mov ax, [es:0x16*4]
    mov word [old_int16_vector], ax
    mov ax, [es:0x16*4+2]
    mov word [old_int16_vector+2], ax
    mov word [es:0x16*4], int16_handler
    mov word [es:0x16*4+2], cs
    mov word [es:0x1C*4], int1c_abort_check
    mov word [es:0x1C*4+2], cs
    sti
    pop es
    pop ax
    ret

; ==================================================================
; SET_KEYBOARD_LAYOUT - set layout (AL = 0 EN, 1 RU)
; ==================================================================
set_keyboard_layout:
    mov [keyboard_layout], al
    ret

; ==================================================================
; INT 0x16 handler
; ==================================================================
int16_handler:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax

    cmp ah, 0x00
    je .read_key
    cmp ah, 0x10
    je .read_key
    cmp ah, 0x01
    je .peek_key
    cmp ah, 0x11
    je .peek_key
    jmp .old_handler

.old_handler:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pushf
    call far [cs:old_int16_vector]
    iret

.read_key:
    mov byte [.func_ah], ah
    call .call_old_handler
    call check_abort_hotkey
    call translate_key
    mov bp, sp
    mov [bp+16], ax
    jmp .handler_return

.peek_key:
    mov byte [.func_ah], ah
    call .call_old_handler
    jz .peek_no_key
    call check_abort_hotkey
    call translate_key
    mov bp, sp
    mov [bp+16], ax
    and word [bp+22], 0xFFBF    ; clear ZF in the caller's saved flags
    jmp .handler_return
.peek_no_key:
    mov bp, sp
    or word [bp+22], 0x0040     ; set ZF in the caller's saved flags
    jmp .handler_return

.handler_return:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

.call_old_handler:
    mov ah, [.func_ah]
    pushf
    call far [cs:old_int16_vector]
    ret

.func_ah db 0

; ==================================================================
; CHECK_ABORT_HOTKEY - Ctrl+Shift+F1 during a running program aborts
; it and returns to the shell. Called from the INT 0x16 hook after
; the BIOS handler returns a key, so the hotkey is caught BEFORE the
; running program receives it.
; IN : AX = key (AH = scancode).
; OUT: returns normally, or jumps to abort_program_to_shell.
; ==================================================================
check_abort_hotkey:
    ; The old INT 0x16 handler does not preserve DS.
    push ax
    push es
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    mov es, ax
    cmp byte [current_program_type], 0
    je .chk_done
    cmp ah, 0x3B                ; F1 scancode
    jne .chk_done
    mov ax, 0x0040
    mov es, ax
    mov bl, [es:0x17]           ; keyboard flags byte 1
    test bl, 0x04               ; Ctrl
    jz .chk_done
    test bl, 0x03               ; Shift (left or right)
    jz .chk_done
    mov al, [current_program_type]
    ; The pushed registers stay on the (abandoned) program stack.
    jmp abort_program_to_shell
.chk_done:
    pop es
    pop ax
    ret

; ==================================================================
; KEYBOARD_READ_KEY - blocking read of one key from the BIOS keyboard
; buffer (BDA 0x40:0x1A/0x1C). Returns AX = key (AH = scan, AL = char).
; ==================================================================
keyboard_read_key:
    mov ax, 0x0040
    mov es, ax
.kr_wait:
    sti
    mov si, [es:0x1A]          ; head
    mov di, [es:0x1C]          ; tail
    cmp si, di
    je .kr_wait
    mov ax, [es:si]
    add si, 2
    cmp si, 0x3E
    jb .kr_ok
    mov si, 0x1E
.kr_ok:
    mov [es:0x1A], si
    ret

; ==================================================================
; INT 0x1C timer-tick hook. If a program is running and Ctrl+Shift+F1
; is pending in the keyboard buffer, the key is consumed and the
; program is aborted back to the shell.
; ==================================================================
int1c_abort_check:
    push ax
    push bx
    push es
    cmp byte [cs:current_program_type], 0
    je .done
    mov ax, 0x0040
    mov es, ax
    mov bx, [es:0x1A]          ; buffer head
    cmp bx, [es:0x1C]          ; buffer tail
    je .done
    cmp byte [es:bx+1], 0x3B   ; F1 scancode (high byte of key word)
    jne .done
    mov bl, [es:0x17]          ; keyboard flags byte 1
    test bl, 0x04              ; Ctrl
    jz .done
    test bl, 0x03              ; Shift
    jz .done
    ; Consume the F1 key from the buffer.
    mov bx, [es:0x1A]
    add bx, 2
    cmp bx, 0x3E
    jb .adv_ok
    mov bx, 0x1E
.adv_ok:
    mov [es:0x1A], bx

    ; AL = program type, then EOI the master PIC: this hook runs inside
    ; the BIOS timer INT 8 handler, so the timer IRQ must be acknowledged
    ; before we abandon that context, otherwise IRQ0 stays pending and the
    ; system clock stops.
    mov al, [cs:current_program_type]
    push ax
    mov al, 0x20
    out 0x20, al
    pop ax

    pop es
    pop bx
    pop ax
    jmp abort_program_to_shell
.done:
    pop es
    pop bx
    pop ax
    iret

; ==================================================================
; TRANSLATE_KEY - translate AX (AL = char, AH = scancode) to the
; active layout. If the layout is EN, AX is returned unchanged.
; Ctrl+Shift toggles the layout (the hotkey is consumed).
; Restores DS/ES to KERNEL_DATA_SEG (the BIOS handler may clobber DS).
; ==================================================================
translate_key:
    push bx
    push dx
    push si
    mov ax, KERNEL_DATA_SEG
    mov ds, ax
    cmp byte [keyboard_layout], 0
    je .tk_out

    mov ax, 0x0040
    mov es, ax

    ; ---- Hotkey: Ctrl+Shift toggles the layout ----
    mov bl, [es:0x17]          ; keyboard flags byte 1
    test bl, 0x04              ; Ctrl
    jz .tk_do_translate
    test bl, 0x03              ; Shift (left or right)
    jz .tk_do_translate

    xor byte [keyboard_layout], 1
    ; consume the hotkey keypress and fetch the next real key
    pop si
    pop dx
    pop bx
    call keyboard_read_key
    jmp translate_key

.tk_do_translate:
    push ax                    ; save the original key
    mov dl, ah                 ; dl = scancode
    mov si, ru_layout_table
.tk_find:
    mov al, [si]
    test al, al
    jz .tk_not_found
    cmp al, dl
    je .tk_found
    add si, 3
    jmp .tk_find
.tk_not_found:
    pop ax
    jmp .tk_out

.tk_found:
    ; Determine case: (Shift pressed) XOR (CapsLock on)
    mov bl, [es:0x17]
    mov bh, 0
    test bl, 0x03
    jz .tk_no_shift
    mov bh, 1
.tk_no_shift:
    test bl, 0x40
    jz .tk_case_ready
    xor bh, 1
.tk_case_ready:
    test bh, bh
    jnz .tk_upper
    mov al, [si+1]             ; lowercase
    jmp .tk_store
.tk_upper:
    mov al, [si+2]             ; uppercase
.tk_store:
    mov ah, dl                 ; keep the scancode
    pop dx                     ; discard the original key
.tk_out:
    pop si
    pop dx
    pop bx
.tk_done:
    ret

; ==================================================================
; RU layout table: scancode, lowercase (CP866), uppercase (CP866)
; ==================================================================
ru_layout_table:
    db 0x29, 0xF1, 0xF0    ; `  -> ё / Ё
    db 0x10, 0xA9, 0x89    ; q  -> й / Й
    db 0x11, 0xE6, 0x96    ; w  -> ц / Ц
    db 0x12, 0xE3, 0x93    ; e  -> у / У
    db 0x13, 0xAA, 0x8A    ; r  -> к / К
    db 0x14, 0xA5, 0x85    ; t  -> е / Е
    db 0x15, 0xAD, 0x8D    ; y  -> н / Н
    db 0x16, 0xA3, 0x83    ; u  -> г / Г
    db 0x17, 0xE8, 0x98    ; i  -> ш / Ш
    db 0x18, 0xE9, 0x99    ; o  -> щ / Щ
    db 0x19, 0xA7, 0x87    ; p  -> з / З
    db 0x1A, 0xE5, 0x95    ; [  -> х / Х
    db 0x1B, 0xEA, 0x9A    ; ]  -> ъ / Ъ
    db 0x1E, 0xE4, 0x94    ; a  -> ф / Ф
    db 0x1F, 0xEB, 0x9B    ; s  -> ы / Ы
    db 0x20, 0xA2, 0x82    ; d  -> в / В
    db 0x21, 0xA0, 0x80    ; f  -> а / А
    db 0x22, 0xAF, 0x8F    ; g  -> п / П
    db 0x23, 0xE0, 0x90    ; h  -> р / Р
    db 0x24, 0xAE, 0x8E    ; j  -> о / О
    db 0x25, 0xAB, 0x8B    ; k  -> л / Л
    db 0x26, 0xA4, 0x84    ; l  -> д / Д
    db 0x27, 0xA6, 0x86    ; ;  -> ж / Ж
    db 0x28, 0xED, 0x9D    ; '  -> э / Э
    db 0x2C, 0xEF, 0x9F    ; z  -> я / Я
    db 0x2D, 0xE7, 0x97    ; x  -> ч / Ч
    db 0x2E, 0xE1, 0x91    ; c  -> с / С
    db 0x2F, 0xAC, 0x8C    ; v  -> м / М
    db 0x30, 0xA8, 0x88    ; b  -> и / И
    db 0x31, 0xE2, 0x92    ; n  -> т / Т
    db 0x32, 0xEC, 0x9C    ; m  -> ь / Ь
    db 0x33, 0xA1, 0x81    ; ,  -> б / Б
    db 0x34, 0xEE, 0x9E    ; .  -> ю / Ю
    db 0x35, 0x2E, 0x2E    ; /  -> . / .
    db 0x00
