[BITS 16]
[ORG 0x100]

start:
    mov dx, hello_msg
    mov ah, 0x09
    int 0x21

    mov dx, newline
    mov ah, 0x09
    int 0x21

    mov ah, 0x4C
    int 0x21

hello_msg db 'Hello, DOS!$'
newline   db 10, 13, '$'