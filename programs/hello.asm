[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x01        ; API output print white string function
    mov si, hello_msg   ; String to output
    int 0x21            ; Call the API function

    ret                 ; Return to the terminal

hello_msg db 'Hello, PRos!', 10, 13, 0