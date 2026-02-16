; ==================================================================
; memtest - Test program for x16-PRos memory allocator
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    ; Test 1: Malloc 100 bytes
    mov ah, 0x01
    mov si, msg_test1
    int 0x21

    mov ah, 0x01
    mov cx, 100
    int 0x23
    mov [ptr1], ax
    
    cmp ax, 0
    je .fail
    
    mov ah, 0x01
    mov si, msg_ok
    int 0x21

    ; Test 2: Malloc 200 bytes
    mov ah, 0x01
    mov si, msg_test2
    int 0x21

    mov ah, 0x01
    mov cx, 200
    int 0x23
    mov [ptr2], ax
    
    cmp ax, 0
    je .fail
    
    mov ah, 0x01
    mov si, msg_ok
    int 0x21

    ; Test 3: Free first block
    mov ah, 0x01
    mov si, msg_test3
    int 0x21

    mov bx, [ptr1]      ; Use BX for pointer
    mov ah, 0x02        ; AH=2 for free
    int 0x23
    
    mov ah, 0x01
    mov si, msg_ok
    int 0x21

    ; Test 4: Malloc 50 bytes (should reuse hole)
    mov ah, 0x01
    mov si, msg_test4
    int 0x21

    mov ah, 0x01
    mov cx, 50
    int 0x23
    
    cmp ax, [ptr1]
    jne .not_reused
    
    mov ah, 0x01
    mov si, msg_ok
    int 0x21
    jmp .done

.not_reused:
    mov ah, 0x01
    mov si, msg_not_reused
    int 0x21
    jmp .done

.fail:
    mov ah, 0x01
    mov si, msg_fail
    int 0x21

.done:
    ret

ptr1 dw 0
ptr2 dw 0

msg_test1 db 'Malloc 100: ', 0
msg_test2 db 'Malloc 200: ', 0
msg_test3 db 'Free 100: ', 0
msg_test4 db 'Malloc 50 (expect reuse): ', 0
msg_ok    db 'OK', 10, 13, 0
msg_fail  db 'FAILED', 10, 13, 0
msg_not_reused db 'OK (but not reused)', 10, 13, 0
