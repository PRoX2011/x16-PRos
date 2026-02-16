; ==================================================================
; x16-PRos - Memory Allocator Validation Utility
; ==================================================================

[BITS 16]
[ORG 0x8000]

start:
    ; --- Validation of Bounds & Safety ---
    
    ; Test: Zero-length allocation
    mov ah, 0x01
    mov si, msg_test_0
    int 0x21
    mov ah, 0x01
    mov cx, 0
    int 0x23
    cmp ax, 0
    jne .fail
    mov si, msg_pass
    call print_msg

    ; Test: Null-pointer release
    mov ah, 0x01
    mov si, msg_test_f0
    int 0x21
    mov ah, 0x02
    mov bx, 0
    int 0x23
    mov si, msg_pass
    call print_msg

    ; Test: Excessive allocation request
    mov ah, 0x01
    mov si, msg_test_big
    int 0x21
    mov ah, 0x01
    mov cx, 0xFFFF
    int 0x23
    cmp ax, 0
    jne .fail
    mov si, msg_pass
    call print_msg

    ; --- Allocation & Data Integrity ---

    ; Allocation 1
    mov ah, 0x01
    mov cx, 100
    int 0x23
    mov [ptr1], ax
    
    ; Allocation 2
    mov ah, 0x01
    mov cx, 200
    int 0x23
    mov [ptr2], ax
    
    ; Verify Segment Write Access
    mov es, [heap_seg_val]
    mov di, [ptr2]
    mov al, 'A'
    mov cx, 200
    rep stosb

    ; Release Allocation 1
    mov ah, 0x02
    mov bx, [ptr1]
    int 0x23

    ; Re-allocation (should utilize reclaimed space)
    mov ah, 0x01
    mov cx, 50
    int 0x23
    mov [ptr3], ax

    ; Verify Data Integrity of Allocation 2
    mov si, [ptr2]
    mov cx, 200
.check_p2:
    mov al, [es:si]
    cmp al, 'A'
    jne .integrity_fail
    inc si
    loop .check_p2

    ; Verify Space Reclamation
    mov ax, [ptr3]
    cmp ax, [ptr1]
    jne .not_reused

    mov si, msg_validation_ok
    call print_msg
    ret

.not_reused:
    mov si, msg_reclamation_fail
    call print_msg
    ret

.integrity_fail:
    mov si, msg_integrity_fail
    call print_msg
    ret

.fail:
    mov si, msg_fail
    call print_msg
    ret

print_msg:
    mov ah, 0x01
    int 0x21
    ret

ptr1 dw 0
ptr2 dw 0
ptr3 dw 0
heap_seg_val dw 0x9000

msg_test_0          db 'Zero-length request (Expect NULL): ', 0
msg_test_f0         db 'Null-pointer release (Expect NO-OP): ', 0
msg_test_big        db 'Over-capacity request (Expect NULL): ', 0
msg_pass            db 'PASSED', 10, 13, 0
msg_fail            db 'FAILED', 10, 13, 0
msg_validation_ok   db 'System Validation: SUCCESS', 10, 13, 0
msg_reclamation_fail db 'Memory Reclamation: FAILED', 10, 13, 0
msg_integrity_fail  db 'Data Integrity: FAILED', 10, 13, 0
