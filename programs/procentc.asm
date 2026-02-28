; ==================================================================
; x16-PRos -- PROCENTC. Precentages calculator.
;
; Made by Gabriel
; ==================================================================
[BITS 16]
[ORG 0x8000]

; ------------------------------------------------------------------
; BSS (uninitialized data)
; ------------------------------------------------------------------
section .bss
input_buffer resb 6
num1         resw 1
num2         resw 1
result_str   resb 8

; ------------------------------------------------------------------
; Entry point
; ------------------------------------------------------------------
section .text
start:
    pusha

    ; Set VGA mode 0x12 (640x480, 16 colors)
    mov ax, 0x0012
    int 0x10

    call tui_init
    call tui_clear_screen

    ; Draw title bar + shortcut bar
    mov ax, title_str
    mov bx, shortcut_str
    call tui_draw_background

    ; Draw main content box
    mov cl, 17             ; x
    mov ch, 5              ; y
    mov dl, 46             ; width
    mov dh, 18             ; height
    mov bl, TUI_DIALOG_ATTR
    call tui_draw_box

    ; Print help text inside box
    mov si, help_l1
    mov cl, 20
    mov ch, 7
    mov bl, TUI_DIALOG_ATTR
    call tui_print_at

    mov si, help_l2
    mov cl, 20
    mov ch, 8
    mov bl, TUI_DIALOG_ATTR
    call tui_print_at

    ; --- Input Number 1 ---
    mov ax, input1_prompt
    mov di, input_buffer
    mov si, 5
    call tui_input_dialog
    jc .cancelled

    mov di, input_buffer
    call convert_to_number
    mov [num1], ax

    ; --- Input Number 2 ---
    mov ax, input2_prompt
    mov di, input_buffer
    mov si, 5
    call tui_input_dialog
    jc .cancelled

    mov di, input_buffer
    call convert_to_number
    mov [num2], ax

    ; --- Calculate: (num1 * 100) / num2 ---
    mov ax, [num1]
    xor dx, dx
    mov bx, 100
    mul bx
    mov bx, [num2]
    test bx, bx
    jz .div_zero
    div bx

    ; Convert result to string, then append '%' before the null
    mov di, result_str
    call convert_to_string
    ; di points AT the null written by convert_to_string -- overwrite it with '%'
    mov byte [di], '%'
    inc di
    mov byte [di], 0

    mov ax, result_str
    mov bx, result_note
    xor cx, cx
    xor dx, dx
    call tui_dialog_box
    jmp .done

.div_zero:
    mov ax, err_l1
    mov bx, err_l2
    xor cx, cx
    xor dx, dx
    call tui_dialog_box
    jmp .done

.cancelled:
    mov ax, cancel_l1
    xor bx, bx
    xor cx, cx
    xor dx, dx
    call tui_dialog_box

.done:
    ; Restore text mode and return
    mov ax, 0x0012
    int 0x10
    popa
    ret

; ------------------------------------------------------------------
; strcpy_inline -- Copy null-terminated string from SI to DI
; ------------------------------------------------------------------
strcpy_inline:
    push ax
.lp:
    lodsb
    stosb
    test al, al
    jnz .lp
    pop ax
    ret

; ------------------------------------------------------------------
; convert_to_number -- Parse decimal string at DI into AX
; ------------------------------------------------------------------
convert_to_number:
    mov si, di
    xor ax, ax
    xor cx, cx
.loop:
    lodsb
    cmp al, 0
    je .done
    sub al, '0'
    imul cx, 10
    add cx, ax
    jmp .loop
.done:
    mov ax, cx
    ret

; ------------------------------------------------------------------
; convert_to_string -- Convert AX to decimal string at DI
; ------------------------------------------------------------------
convert_to_string:
    test ax, ax
    jnz .non_zero
    mov byte [di], '0'
    inc di
    jmp .terminate
.non_zero:
    mov bx, 10
    xor cx, cx
.extract:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    test ax, ax
    jnz .extract
.reverse:
    pop dx
    mov [di], dl
    inc di
    loop .reverse
.terminate:
    mov byte [di], 0
    ret

; ------------------------------------------------------------------
; Data
; ------------------------------------------------------------------
section .data

title_str     db 'Percentages v0.2', 0
shortcut_str  db 'Enter=Confirm   Esc=Cancel', 0

help_l1       db 'Calculates what percent Num1 is of Num2', 0
help_l2       db 'Note: Num2 must be greater than Num1.', 0

input1_prompt db 'Enter Number 1 (base):', 0
input2_prompt db 'Enter Number 2 (total):', 0

result_note   db 'Calculation complete.', 0

err_l1        db 'Error: Division by zero!', 0
err_l2        db 'Number 2 cannot be zero.', 0

cancel_l1     db 'Cancelled. No result computed.', 0

; ------------------------------------------------------------------
; Includes
; ------------------------------------------------------------------
%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"
