; ==============================================================================
;  ICMP Implementation (Internet Control Message Protocol)
; ==============================================================================

BITS 16

; ICMP Header
ICMP_TYPE       equ 0   ; 1 byte
ICMP_CODE       equ 1   ; 1 byte
ICMP_CKSUM      equ 2   ; 2 bytes
ICMP_ID         equ 4   ; 2 bytes
ICMP_SEQ        equ 6   ; 2 bytes
ICMP_SIZE       equ 8

; ICMP Types
ICMP_TYPE_ECHO_REPLY    equ 0
ICMP_TYPE_ECHO_REQUEST  equ 8

section .data
    icmp_id_val     dw 0xBEEF
    icmp_seq_val    dw 0
    icmp_target_ip  times 4 db 0

section .text

; ------------------------------------------------------------------------------
; icmp_ping
; IN:  DS:SI = Target IP String (e.g. "10.0.2.2")
; ------------------------------------------------------------------------------
icmp_ping:
    pusha
    
    ; Hardware check: if MAC is all 0, probe failed
    mov bx, ne2k_mac
    mov ax, [bx]
    or ax, [bx+2]
    or ax, [bx+4]
    jnz .hw_ok
    
    mov si, err_msg_no_card
    call print_string_red
    popa
    ret

.hw_ok:
    ; 1. Parse IP String
    mov di, icmp_target_ip
    call icmp_parse_ip
    jc .error_parse
    
    ; Print target info
    push si
    mov si, msg_pinging
    call print_string
    pop si
    call print_string
    mov si, msg_newline
    call print_string

    ; 2. Check if target is our own IP (loopback)
    lea si, [icmp_target_ip]
    lea di, [net_local_ip]
    mov cx, 4
    xor bx, bx
.check_self_ip:
    mov al, [si]
    cmp al, [di]
    jne .not_self_ip
    inc si
    inc di
    loop .check_self_ip
    ; Target IP matches our IP - use our MAC directly
    mov si, msg_resolving_arp
    call print_string
    mov si, msg_self_ping
    call print_string
    lea di, [arp_target_mac_cache]
    lea si, [ne2k_mac]
    mov cx, 6
    rep movsb
    mov byte [arp_resolved], 1
    jmp .send_ping

.not_self_ip:
    ; 2. Resolve MAC via ARP
    push si
    mov si, msg_resolving_arp
    call print_string
    pop si
    
    mov si, icmp_target_ip
    call arp_send_request
    
    ; Wait for ARP Reply
    mov cx, 500
.arp_wait:
    push cx
    
    ; 10ms delay using BIOS INT 15h
    mov ah, 0x86
    mov cx, 0
    mov dx, 10000 ; 10,000 us = 10 ms
    int 0x15
    
    push ds
    pop es
    mov di, disk_buffer
    call ne2000_recv
    pop cx
    jc .no_arp_packet
    
    ; Naive dispatcher: call arp_handle_packet
    mov si, disk_buffer
    call arp_handle_packet
    cmp byte [arp_resolved], 1
    je .send_ping

.no_arp_packet:
    ; Check keyboard for Ctrl+C
    mov ah, 0x01
    int 0x16
    jz .no_key_arp
    mov ah, 0x00
    int 0x16
    cmp al, 3 ; Ctrl+C
    je .interrupted
.no_key_arp:
    loop .arp_wait
    jmp .error_timeout

.send_ping:
    ; 3. Loop Pings
    mov cx, 4 ; 4 pings
.ping_loop:
    push cx
    
    ; Construct ICMP Packet
    mov di, disk_buffer + 200 ; Temporary buffer for ICMP payload
    mov byte [di + ICMP_TYPE], ICMP_TYPE_ECHO_REQUEST
    mov byte [di + ICMP_CODE], 0
    mov word [di + ICMP_CKSUM], 0
    mov ax, [icmp_id_val]
    mov [di + ICMP_ID], ax
    mov ax, [icmp_seq_val]
    inc ax
    mov [icmp_seq_val], ax
    mov [di + ICMP_SEQ], ax
    
    ; Simple Payload
    mov byte [di + 8], 'A'
    mov byte [di + 9], 'B'
    mov byte [di + 10], 'C'
    
    ; Calculate ICMP Checksum
    push di
    mov si, di
    mov cx, 11 ; 8 header + 3 payload
    call icmp_calc_checksum
    pop di
    mov [di + ICMP_CKSUM], ax
    
    ; Send via IP
    mov si, di
    mov cx, 11
    mov al, IP_PROTO_ICMP
    call ip_send_packet
    
    ; Wait for Reply
    mov cx, 500
.reply_wait:
    push cx
    push ds
    pop es
    mov di, disk_buffer
    call ne2000_recv
    pop cx
    jc .no_packet
    
    ; Check if it's an ICMP Echo Reply for us
    mov si, disk_buffer + 14 ; IP Header
    cmp byte [si + 9], 1 ; Protocol ICMP
    jne .no_packet
    
    add si, 20 ; ICMP Header
    cmp byte [si + ICMP_TYPE], ICMP_TYPE_ECHO_REPLY
    jne .no_packet
    
    ; Success!
    mov si, msg_reply
    call print_string
    jmp .next_ping

.no_packet:
    ; Check keyboard
    mov ah, 0x01
    int 0x16
    jz .no_key_reply
    mov ah, 0x00
    int 0x16
    cmp al, 3 ; Ctrl+C
    je .interrupted_pop
.no_key_reply:
    loop .reply_wait
    mov si, msg_timeout
    call print_string

.next_ping:
    pop cx
    dec cx
    jnz near .ping_loop
    
    popa
    ret

.interrupted_pop:
    pop cx
.interrupted:
    mov si, msg_interrupted
    call print_string
    popa
    ret

.error_parse:
    mov si, err_msg_parse
    call print_string_red
    popa
    ret

.error_timeout:
    mov si, err_msg_timeout
    call print_string_red
    popa
    ret

; --- Helpers ---

icmp_parse_ip:
    pusha
    ; Destination DI set by caller
    xor bx, bx ; Current byte value
    xor bh, bh ; Dot count
.loop:
    lodsb
    cmp al, '.'
    je .dot
    cmp al, 0
    je .end
    cmp al, ' '
    je .end
    cmp al, 13 ; Carriage Return
    je .end
    
    sub al, '0'
    jb .fail
    cmp al, 9
    ja .fail
    
    mov cl, al       ; Save digit
    mov al, bl       ; Current byte value
    mov dl, 10
    mul dl           ; ax = bl * 10
    add al, cl       ; Add digit
    mov bl, al       ; Store back
    jmp .loop

.dot:
    mov [di], bl
    inc di
    xor bl, bl
    inc bh
    jmp .loop

.end:
    mov [di], bl
    cmp bh, 3
    jne .fail
    popa
    clc
    ret

.fail:
    popa
    stc
    ret

icmp_calc_checksum:
    jmp ip_calc_checksum

msg_resolving_arp  db 'Resolving MAC address...', 13, 10, 0
msg_self_ping      db 'Loopback (self-ping)', 13, 10, 0
msg_pinging     db 'Pinging ', 0
msg_newline     db 13, 10, 0
msg_reply       db 'Reply from host: bytes=32 time<1ms TTL=64', 13, 10, 0
msg_timeout     db 'Request timed out.', 13, 10, 0
msg_interrupted db '^C', 13, 10, 0
err_msg_parse   db 'Bad IP.', 13, 10, 0
err_msg_timeout db 'No ARP.', 13, 10, 0
err_msg_no_card  db 'No NE2000 card found.', 13, 10, 0
