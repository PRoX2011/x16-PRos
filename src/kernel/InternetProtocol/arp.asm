; ==============================================================================
;  ARP Implementation (Address Resolution Protocol)
; ==============================================================================

BITS 16

; ARP Packet Structure
ARP_HW_TYPE     equ 0   ; 2 bytes
ARP_PROTO_TYPE  equ 2   ; 2 bytes
ARP_HW_LEN      equ 4   ; 1 byte
ARP_PROTO_LEN   equ 5   ; 1 byte
ARP_OPCODE      equ 6   ; 2 bytes
ARP_SENDER_MAC  equ 8   ; 6 bytes
ARP_SENDER_IP   equ 14  ; 4 bytes
ARP_TARGET_MAC  equ 18  ; 6 bytes
ARP_TARGET_IP   equ 24  ; 4 bytes
ARP_SIZE        equ 28

; ARP Opcodes
ARP_OP_REQUEST  equ 1
ARP_OP_REPLY    equ 2

section .data
    arp_target_ip_cache   times 4 db 0
    arp_target_mac_cache  times 6 db 0
    arp_resolved          db 0

section .text

; ------------------------------------------------------------------------------
; arp_send_request
; IN:  DS:SI = Target IP (4 bytes)
; ------------------------------------------------------------------------------
arp_send_request:
    pusha
    push ds
    pop es
    
    ; Save target IP for comparison
    mov di, arp_target_ip_cache
    mov cx, 4
    rep movsb
    
    mov byte [arp_resolved], 0
    
    ; Construct Packet in disk_buffer
    mov di, disk_buffer
    
    ; --- Ethernet Header ---
    ; Destination MAC: Broadcast (FF:FF:FF:FF:FF:FF)
    mov al, 0xFF
    mov cx, 6
    rep stosb
    
    ; Source MAC: Our MAC
    lea si, [ne2k_mac]
    mov cx, 6
    rep movsb
    
    ; Type: ARP (0x0806) -> 0x0608 Big Endian
    mov ax, 0x0608
    stosw
    
    ; --- ARP Body ---
    mov ax, 0x0100 ; HW: Ethernet (1)
    stosw
    mov ax, 0x0008 ; Proto: IP (0x0800)
    stosw
    mov al, 6      ; HW Len
    stosb
    mov al, 4      ; Proto Len
    stosb
    mov ax, 0x0100 ; Opcode: Request (1)
    stosw
    
    ; Sender MAC
    lea si, [ne2k_mac]
    mov cx, 6
    rep movsb
    
    ; Sender IP
    lea si, [net_local_ip]
    mov cx, 4
    rep movsb
    
    ; Target MAC (0 for request)
    xor al, al
    mov cx, 6
    rep stosb
    
    ; Target IP
    lea si, [arp_target_ip_cache]
    mov cx, 4
    rep movsb
    
    ; Send Packet (min 60 bytes)
    mov si, disk_buffer
    mov cx, 60
    call ne2000_send
    
    popa
    ret

; ------------------------------------------------------------------------------
; arp_handle_packet
; IN:  DS:SI = Packet (starting at Ethernet Header)
; ------------------------------------------------------------------------------
arp_handle_packet:
    pusha
    
    ; Check if Type is ARP (offset 12)
    cmp word [si + 12], 0x0608
    jne .done
    
    ; Move to ARP Body (offset 14)
    add si, 14
    
    ; Check Opcode: Reply (2) -> 0x0200
    cmp word [si + ARP_OPCODE], 0x0200
    jne .check_request
    
    ; Is it replying to our pending IP?
    lea di, [si + ARP_SENDER_IP]
    lea bx, [arp_target_ip_cache]
    mov cx, 4
.check_reply_ip:
    mov al, [bx]
    cmp al, [di]
    jne .done
    inc bx
    inc di
    loop .check_reply_ip
    
    ; Found our MAC!
    mov di, arp_target_mac_cache
    lea bx, [si + ARP_SENDER_MAC]
    mov cx, 6
.copy_mac:
    mov al, [bx]
    mov [di], al
    inc bx
    inc di
    loop .copy_mac
    
    mov byte [arp_resolved], 1
    jmp .done

.check_request:
    ; ... (Optional: reply to others' requests)

.done:
    popa
    ret
