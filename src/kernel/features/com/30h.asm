com_30h:
    mov ax, 0x0005      ; AL=major(5), AH=minor(0)
    xor bx, bx          ; BH=OEM, BL=revision
    xor cx, cx
    iret
