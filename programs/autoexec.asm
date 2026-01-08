[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22

    mov ah, 0x02
    mov si, user_cfg
    mov cx, buffer
    int 0x22

    mov ah, 0x0A
    int 0x22

    mov ah, 0x01
    mov si, hello_msg
    int 0x21

    mov ah, 0x03
    mov si, buffer
    int 0x21

    mov ah, 0x01
    mov si, hello_end_msg
    int 0x21

    mov ah, 0x01
    mov si, welcome_msg
    int 0x21

    ret

.copy_user:
    rep movsb
    mov byte [di], 0
    
    ret

user_cfg       db 'USER.CFG', 0
conf_dir_name  db 'CONF.DIR', 0
hello_msg      db 'Hello, ', 0
hello_end_msg  db '! ', 0
welcome_msg    db 'Welcome to the x16-PRos!', 10, 13, 10, 13,0

buffer times 32 db 0