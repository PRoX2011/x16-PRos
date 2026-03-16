[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x01         ; API output print white string function
    mov si, hello_msg_en ; String to output
    int 0x21             ; Call the API function

    mov ah, 0x01
    mov si, hello_msg_ru
    int 0x21

    ret                  ; Return to the terminal

hello_msg_en db 'Hello, PRos! Live longg and prosper!', 10, 13, 0
hello_msg_ru db 'Привет, PRos! Здравствуйте и процветайте!', 10, 13, 0