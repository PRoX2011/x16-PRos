; ==============================================================================
;  IP Implementation (Internet Protocol)
; ==============================================================================

BITS 16

; IP Header Structure
IP_VHL          equ 0   ; 1 byte
IP_TOS          equ 1   ; 1 byte
IP_LEN          equ 2   ; 2 bytes
IP_ID           equ 4   ; 2 bytes
IP_FRAG         equ 6   ; 2 bytes
IP_TTL          equ 8   ; 1 byte
IP_PROTO        equ 9   ; 1 byte
IP_CKSUM        equ 10  ; 2 bytes
IP_SRC          equ 12  ; 4 bytes
IP_DST          equ 16  ; 4 bytes
IP_SIZE         equ 20

; Protocol Types
IP_PROTO_ICMP   equ 1

section .data
    ip_id_counter   dw 0

section .text

; ------------------------------------------------------------------------------
; ip_send_packet
; IN:  DS:SI = Payload (e.g. ICMP), CX = Payload Length, AL = Protocol
; ------------------------------------------------------------------------------
ip_send_packet:
    pusha
    
    mov bx, cx ; Save payload length
    mov dl, al ; Save protocol
    
    ; disk_buffer + 0-13: Ethernet
    ; disk_buffer + 14-33: IP
    ; disk_buffer + 34+: Payload
    
    ; --- Ethernet Header ---
    mov di, disk_buffer
    
    ; Destination MAC
    push si
    lea si, [arp_target_mac_cache]
    mov cx, 6
    rep movsb
    pop si
    
    ; Source MAC
    push si
    lea si, [ne2k_mac]
    mov cx, 6
    rep movsb
    pop si
    
    ; Type: IP (0x0800) -> 0x0008 Big Endian
    mov ax, 0x0008
    stosw
    
    ; --- IP Body ---
    mov di, disk_buffer + 14
    
    mov byte [di + IP_VHL], 0x45
    mov byte [di + IP_TOS], 0x00
    
    ; Total Length (20 + Payload BX)
    mov ax, bx
    add ax, 20
    xchg al, ah
    mov [di + IP_LEN], ax
    
    ; ID
    mov ax, [ip_id_counter]
    inc ax
    mov [ip_id_counter], ax
    xchg al, ah
    mov [di + IP_ID], ax
    
    ; Flags/Frag
    mov word [di + IP_FRAG], 0x0000
    
    ; TTL
    mov byte [di + IP_TTL], 64
    
    ; Protocol
    mov [di + IP_PROTO], dl
    
    ; Checksum
    mov word [di + IP_CKSUM], 0x0000
    
    ; Source IP
    push si
    lea si, [net_local_ip]
    lea dx, [di + IP_SRC]
    push di
    mov di, dx
    mov cx, 4
    rep movsb
    pop di
    pop si
    
    ; Dest IP
    push si
    lea si, [arp_target_ip_cache]
    lea dx, [di + IP_DST]
    push di
    mov di, dx
    mov cx, 4
    rep movsb
    pop di
    pop si
    
    ; Calculate IP Checksum
    push si
    lea si, [di]
    mov cx, 20
    call ip_calc_checksum
    mov [di + IP_CKSUM], ax
    pop si
    
    ; Copy Payload
    push di
    lea di, [di + 20]
    mov cx, bx
    rep movsb
    pop di
    
    ; Total Packet Length = 14 + 20 + BX
    mov cx, bx
    add cx, 34
    
    ; Pad to 60 if needed
    cmp cx, 60
    jae .no_pad
    mov cx, 60
.no_pad:
    
    mov si, disk_buffer
    call ne2000_send
    
    popa
    ret

; ------------------------------------------------------------------------------
; ip_calc_checksum
; IN:  DS:SI = Data, CX = Length in bytes
; OUT: AX = Checksum (Big Endian)
; ------------------------------------------------------------------------------
ip_calc_checksum:
    push bx
    push cx
    push dx
    push si
    
    mov dx, cx          ; Save original length
    xor ax, ax          ; Clear sum
    xor bx, bx
    
    shr cx, 1           ; Loop for words
    jz .odd_byte
    
.loop:
    mov bx, [si]
    add ax, bx
    adc ax, 0           ; Add carry back for one's complement sum
    add si, 2
    loop .loop

.odd_byte:
    test dx, 1
    jz .finish
    mov bl, [si]        ; Last byte
    xor bh, bh
    add ax, bx
    adc ax, 0

.finish:
    not ax              ; One's complement
    pop si
    pop dx
    pop cx
    pop bx
    ret
