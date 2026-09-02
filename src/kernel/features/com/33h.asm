com_33h:
    cmp al, 0x00
    je .get
    cmp al, 0x05
    je .boot_drive
    iret
.get:
    xor dl, dl
    iret
.boot_drive:
    mov dl, 1
    iret
