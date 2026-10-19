com_0Ch:
    mov [cs:.func], al

.flush_loop:
    mov ah, 0x01
    int 0x16
    jz .dispatch
    mov ah, 0x00
    int 0x16
    jmp .flush_loop

.dispatch:
    mov al, [cs:.func]
    cmp al, 0x01
    je com_01h
    cmp al, 0x06
    je com_06h
    cmp al, 0x07
    je com_07h
    cmp al, 0x08
    je com_08h
    cmp al, 0x0A
    je com_0Ah
    iret

.func db 0
