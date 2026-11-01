com_59h:
    mov ax, [cs:dos_last_error]
    mov bx, 0x0704
    mov ch, 0x01
    cmp ax, 0x0002
    je .missing
    cmp ax, 0x0003
    je .missing
    cmp ax, 0x0012
    je .missing
    cmp ax, 0x0005
    je .denied
    cmp ax, 0x0050
    je .exists
    cmp ax, 0x0004
    je .resource
    cmp ax, 0x0008
    je .resource
    iret
.missing:
    mov bx, 0x0803
    mov ch, 0x02
    iret
.denied:
    mov bx, 0x0303
    mov ch, 0x02
    iret
.exists:
    mov bx, 0x0C03
    mov ch, 0x02
    iret
.resource:
    mov bh, 0x01
    iret
