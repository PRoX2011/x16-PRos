com_0Bh:
    mov ah, 0x01
    int 0x16
    jz .empty
    mov al, 0xFF
    iret
.empty:
    mov al, 0x00
    iret