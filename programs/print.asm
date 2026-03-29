[BITS 16]
[ORG 0x8000]

start:
    test si, si
    jz .no_args
    cmp byte [si], 0
    je .no_args

    mov ah, 0x04
    int 0x22
    jc .file_not_found

    mov ah, 0x02
    mov cx, file_buffer
    int 0x22
    jc .load_error

    mov cx, bx
    jcxz .empty_file

    call printer_check
    jc .no_printer

    call printer_init
    jc .printer_error

    mov si, file_buffer
.print_loop:
    cmp cx, 0
    je .done_printing
    lodsb
    call printer_send_char
    jc .printer_error
    dec cx
    jmp .print_loop

.done_printing:
    mov al, 0x0C
    call printer_send_char
    mov ah, 0x02
    mov si, msg_ok
    int 0x21
    ret

.no_args:
    mov ah, 0x01
    mov si, msg_usage
    int 0x21
    ret

.file_not_found:
    mov ah, 0x04
    mov si, msg_not_found
    int 0x21
    ret

.load_error:
    mov ah, 0x04
    mov si, msg_load_err
    int 0x21
    ret

.empty_file:
    mov ah, 0x04
    mov si, msg_empty
    int 0x21
    ret

.no_printer:
    mov ah, 0x04
    mov si, msg_no_printer
    int 0x21
    ret

.printer_error:
    mov ah, 0x04
    mov si, msg_print_err
    int 0x21
    ret


printer_check:
    push es
    push bx
    mov ax, 0x0040
    mov es, ax
    mov bx, [es:0x0008]
    test bx, bx
    jz .no_port
    clc
    pop bx
    pop es
    ret
.no_port:
    stc
    pop bx
    pop es
    ret


printer_init:
    mov ah, 0x01
    mov dx, 0x00
    int 0x17
    test ah, 0x20
    jnz .out_of_paper
    test ah, 0x08
    jnz .io_error
    clc
    ret
.out_of_paper:
    mov ah, 0x04
    mov si, msg_no_paper
    int 0x21
    stc
    ret
.io_error:
    stc
    ret

printer_send_char:
    push ax
    push cx
    push dx

    mov cx, 0xFFFF
.wait_ready:
    mov ah, 0x02
    mov dx, 0x00
    int 0x17
    test ah, 0x80
    jnz .ready
    test ah, 0x08
    jnz .error
    loop .wait_ready
    jmp .error

.ready:
    pop dx
    pop cx
    pop ax
    mov ah, 0x00
    mov dx, 0x00
    int 0x17
    test ah, 0x08
    jnz .error_sent
    clc
    ret

.error:
    pop dx
    pop cx
    pop ax
    stc
    ret

.error_sent:
    stc
    ret


msg_usage      db "Usage: print <filename>", 0x0D, 0x0A, 0
msg_ok         db "Printed successfully.", 0x0D, 0x0A, 0
msg_not_found  db "File not found.", 0x0D, 0x0A, 0
msg_load_err   db "Could not load file.", 0x0D, 0x0A, 0
msg_empty      db "File is empty.", 0x0D, 0x0A, 0
msg_no_printer db "No printer port (LPT1) detected.", 0x0D, 0x0A, 0
msg_no_paper   db "Printer out of paper.", 0x0D, 0x0A, 0
msg_print_err  db "Printer error or timeout.", 0x0D, 0x0A, 0

file_buffer:
