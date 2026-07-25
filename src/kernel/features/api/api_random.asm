; ==================================================================
; x16-PRos - Kernel Random API (ChaCha20-based CSPRNG)
; Copyright (C) 2026 Antigravity
; ==================================================================

[BITS 16]

section .data
random_initialized db 0

section .bss
random_state      resd 16
random_keystream  resd 16

section .text

; ========================================================================
; chacha20_quarter_round - Performs the ChaCha20 quarter-round on 4 dwords
; IN:  EAX = word a
;      EBX = word b
;      ECX = word c
;      EDX = word d
; OUT: EAX, EBX, ECX, EDX = updated words a, b, c, d
; ========================================================================
chacha20_quarter_round:
    add eax, ebx
    xor edx, eax
    rol edx, 16

    add ecx, edx
    xor ebx, ecx
    rol ebx, 12

    add eax, ebx
    xor edx, eax
    rol edx, 8

    add ecx, edx
    xor ebx, ecx
    rol ebx, 7
    ret

; ========================================================================
; chacha20_double_round - Performs the ChaCha20 double-round (column + diagonal)
; IN:  SI = pointer to the 16-dword state matrix
; OUT: State matrix at SI updated in-place
; ========================================================================
chacha20_double_round:
    push si

    ; Column 0: 0, 4, 8, 12
    mov eax, [si + 0]
    mov ebx, [si + 16]
    mov ecx, [si + 32]
    mov edx, [si + 48]
    call chacha20_quarter_round
    mov [si + 0], eax
    mov [si + 16], ebx
    mov [si + 32], ecx
    mov [si + 48], edx

    ; Column 1: 1, 5, 9, 13
    mov eax, [si + 4]
    mov ebx, [si + 20]
    mov ecx, [si + 36]
    mov edx, [si + 52]
    call chacha20_quarter_round
    mov [si + 4], eax
    mov [si + 20], ebx
    mov [si + 36], ecx
    mov [si + 52], edx

    ; Column 2: 2, 6, 10, 14
    mov eax, [si + 8]
    mov ebx, [si + 24]
    mov ecx, [si + 40]
    mov edx, [si + 56]
    call chacha20_quarter_round
    mov [si + 8], eax
    mov [si + 24], ebx
    mov [si + 40], ecx
    mov [si + 56], edx

    ; Column 3: 3, 7, 11, 15
    mov eax, [si + 12]
    mov ebx, [si + 28]
    mov ecx, [si + 44]
    mov edx, [si + 60]
    call chacha20_quarter_round
    mov [si + 12], eax
    mov [si + 28], ebx
    mov [si + 44], ecx
    mov [si + 60], edx

    ; Diagonal 1: 0, 5, 10, 15
    mov eax, [si + 0]
    mov ebx, [si + 20]
    mov ecx, [si + 40]
    mov edx, [si + 60]
    call chacha20_quarter_round
    mov [si + 0], eax
    mov [si + 20], ebx
    mov [si + 40], ecx
    mov [si + 60], edx

    ; Diagonal 2: 1, 6, 11, 12
    mov eax, [si + 4]
    mov ebx, [si + 24]
    mov ecx, [si + 44]
    mov edx, [si + 48]
    call chacha20_quarter_round
    mov [si + 4], eax
    mov [si + 24], ebx
    mov [si + 44], ecx
    mov [si + 48], edx

    ; Diagonal 3: 2, 7, 8, 13
    mov eax, [si + 8]
    mov ebx, [si + 28]
    mov ecx, [si + 32]
    mov edx, [si + 52]
    call chacha20_quarter_round
    mov [si + 8], eax
    mov [si + 28], ebx
    mov [si + 32], ecx
    mov [si + 52], edx

    ; Diagonal 4: 3, 4, 9, 14
    mov eax, [si + 12]
    mov ebx, [si + 16]
    mov ecx, [si + 36]
    mov edx, [si + 56]
    call chacha20_quarter_round
    mov [si + 12], eax
    mov [si + 16], ebx
    mov [si + 36], ecx
    mov [si + 56], edx

    pop si
    ret

; ========================================================================
; chacha20_hash - Performs the ChaCha12 block hash function (12 rounds)
; IN:  SI = pointer to input state (64 bytes)
;      DI = pointer to output buffer (64 bytes)
; OUT: Output buffer at DI filled with hashed state + original state
; ========================================================================
chacha20_hash:
    pusha

    ; Copy input state SI to output state DI
    mov cx, 16
    xor bx, bx
.copy_loop:
    mov eax, [si + bx]
    mov [di + bx], eax
    add bx, 4
    loop .copy_loop

    ; Run 6 double rounds on the output state (DI) for ChaCha12
    push si
    mov si, di
    mov cx, 6
.round_loop:
    push cx
    call chacha20_double_round
    pop cx
    loop .round_loop
    pop si

    ; Add back original state SI to output state DI
    mov cx, 16
    xor bx, bx
.add_loop:
    mov eax, [si + bx]
    add [di + bx], eax
    add bx, 4
    loop .add_loop

    popa
    ret

; ========================================================================
; api_random_init - Seeds and scrambles the global ChaCha20 state
; IN:  Nothing
; OUT: Nothing (Updates random_state and sets random_initialized flag)
; ========================================================================
api_random_init:
    pusha
    push ds

    mov ax, cs
    mov ds, ax

    ; 1. Set Constants (words 0-3)
    mov dword [random_state + 0],  0x61707865 ; "expa"
    mov dword [random_state + 4],  0x3320646e ; "nd 3"
    mov dword [random_state + 8],  0x79622d32 ; "2-by"
    mov dword [random_state + 12], 0x6b206574 ; "te k"

    ; 2. Read BIOS Timer Tick (0040:006C) into word 4
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov eax, [0x006C]
    pop ds
    mov [random_state + 16], eax

    ; 3. Read RDTSC into words 5 and 6
    rdtsc
    mov [random_state + 20], eax
    mov [random_state + 24], edx

    ; 4. Read CMOS clock into words 7 and 8
    call timezone_get_local_datetime
    mov al, [timezone_local_hour]
    mov ah, [timezone_local_minute]
    shl eax, 16
    mov al, [timezone_local_second]
    mov ah, [timezone_local_century]
    mov [random_state + 28], eax

    mov al, [timezone_local_year]
    mov ah, [timezone_local_month]
    shl eax, 16
    mov al, [timezone_local_day]
    mov ah, 0 ; padding
    mov [random_state + 32], eax

    ; 5. Read SP & CS into word 9
    mov ax, sp
    mov dx, cs
    shl eax, 16
    mov ax, dx
    mov [random_state + 36], eax

    ; 6. Read another RDTSC into word 10
    rdtsc
    mov [random_state + 40], eax

    ; 7. Set fixed salt into word 11
    mov dword [random_state + 44], 0xDEADBEEF

    ; 8. Clear block counter (words 12-13)
    mov dword [random_state + 48], 0
    mov dword [random_state + 52], 0

    ; 9. Set IV (words 14-15) from high part of RDTSC
    mov [random_state + 56], edx
    rdtsc
    mov [random_state + 60], eax

    ; 10. Scramble initial state using chacha20_hash
    mov si, random_state
    mov di, random_keystream
    call chacha20_hash

    ; 11. Feed back scrambled output to set final key and IV
    mov cx, 8
    xor bx, bx
.feed_key:
    mov eax, [random_keystream + bx]
    mov [random_state + 16 + bx], eax
    add bx, 4
    loop .feed_key

    mov eax, [random_keystream + 32]
    mov [random_state + 56], eax
    mov eax, [random_keystream + 36]
    mov [random_state + 60], eax

    ; 12. Clear block counter again
    mov dword [random_state + 48], 0
    mov dword [random_state + 52], 0

    mov byte [random_initialized], 1

    pop ds
    popa
    ret

; ========================================================================
; api_random_generate - Generates random bytes to satisfy user buffer request
; IN:  ES:DI = buffer pointer in user segment
;      CX = request size in bytes
; OUT: Buffer filled with random bytes
; ========================================================================
api_random_generate:
    pusha
    push ds
    push es

    mov ax, cs
    mov ds, ax

    ; Save caller's destination pointer DI to DX
    mov dx, di

    cmp byte [random_initialized], 0
    jne .generate_loop
    call api_random_init

.generate_loop:
    cmp cx, 0
    je .done

    ; Generate 64-byte block
    mov si, random_state
    mov di, random_keystream
    call chacha20_hash

    ; Increment 64-bit block counter (words 12-13)
    add dword [random_state + 48], 1
    adc dword [random_state + 52], 0

    ; Copy up to 32 bytes of user data per block
    mov bx, 32
    cmp cx, bx
    jae .copy_size_ok
    mov bx, cx
.copy_size_ok:

    push cx
    push si
    push di
    mov cx, bx
    mov si, random_keystream
    add si, 32
    mov di, dx              ; Restore destination pointer from DX
.copy_bytes:
    lodsb
    stosb
    loop .copy_bytes
    mov dx, di              ; Save updated destination pointer back to DX
    pop di
    pop si
    pop cx

    sub cx, bx

    ; Update key with first 32 bytes of output block
    push cx
    mov cx, 8
    xor bx, bx
.update_key:
    mov eax, [random_keystream + bx]
    mov [random_state + 16 + bx], eax
    add bx, 4
    loop .update_key
    pop cx

    jmp .generate_loop

.done:
    pop es
    pop ds
    popa
    ret
