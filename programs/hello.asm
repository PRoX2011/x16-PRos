[BITS 16]
[ORG 0x8000]

start:
    mov ah, 0x01
    mov si, prompt
    int 0x21

    ; Get username input
    mov ah, 0x08          ; API string input string function
    mov si, user_name     ; Buffer
    int 0x23              ; Call the API function


    ; Print newline
    mov ah, 0x05
    int 0x21

    ; ------ Print "Hello + NAME" ------
    mov ah, 0x01
    mov si, hello_msg
    int 0x21

    mov ah, 0x01
    mov si, user_name
    int 0x21
    ; ----------------------------------

    ; Print newline
    mov ah, 0x05
    int 0x21

    ret                   ; Return to the terminal

prompt    db 'Enter your name: ', 0
hello_msg db 'Hello, ', 0
user_name times 32 db 0