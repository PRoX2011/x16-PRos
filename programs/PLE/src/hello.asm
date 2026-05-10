%include "ple.inc"

PLE_HEADER start, "Just another hello world :)", "PRoX-dev"
PLE_LOGO          "logo/hello.raw"

start:
    push cs
    pop ds

    mov ah, 0x01
    mov si, hello_msg
    int 0x21

    retf

hello_msg db 'Hello, PRos! Live long and prosper!', 10, 13, 0

PLE_END