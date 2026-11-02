;  +----------------------------------------------------------------+
;  |  Made by Gabriel Sîrbu and distributed under the MIT license   |
;  +----------------------------------------------------------------+

[BITS 16]
[ORG 0x8000]

section .text

PING_COUNT      equ 4

ETH_DST         equ 0
ETH_SRC         equ 6
ETH_TYPE        equ 12
ETH_HDR_LEN     equ 14

IP_VER_IHL      equ 0
IP_TOS          equ 1
IP_TOTLEN       equ 2
IP_ID           equ 4
IP_FLAGS        equ 6
IP_TTL          equ 8
IP_PROTO        equ 9
IP_CHECKSUM     equ 10
IP_SRC          equ 12
IP_DST          equ 16
IP_HDR_LEN      equ 20

ICMP_TYPE       equ 0
ICMP_CODE       equ 1
ICMP_CHECKSUM   equ 2
ICMP_ID         equ 4
ICMP_SEQ        equ 6
ICMP_DATA       equ 8
ICMP_DATA_LEN   equ 32
ICMP_HDR_LEN    equ 8

ICMP_TOTAL      equ ICMP_HDR_LEN + ICMP_DATA_LEN
IP_TOTAL        equ IP_HDR_LEN + ICMP_TOTAL
FRAME_TOTAL     equ ETH_HDR_LEN + IP_TOTAL

start:
    mov [param_list], si

    mov ah, 0x05
    int 0x21

    pusha

    mov si, [param_list]
    call parse_args
    cmp ax, 0
    je .show_usage

    mov [ip_str_ptr], ax

    mov si, [ip_str_ptr]
    mov di, target_ip
    call parse_ipv4
    jc .bad_ip

    call ne2000_init
    jc .nic_error

    push ds
    pop es
    mov di, our_mac
    call ne2000_get_mac

    mov ah, 0x01
    mov si, ping_header_msg
    int 0x21

    mov si, [ip_str_ptr]
    mov ah, 0x01
    int 0x21

    mov ah, 0x05
    int 0x21

    call arp_resolve
    jc .arp_failed

    mov word [ping_sent], 0
    mov word [ping_recv], 0
    mov word [icmp_seq], 1

.ping_loop:
    cmp word [ping_sent], PING_COUNT
    jge .ping_done

    call send_icmp_echo
    inc word [ping_sent]

    call wait_icmp_reply
    jc .ping_timeout

    inc word [ping_recv]

    call print_reply
    jmp .ping_next

.ping_timeout:
    mov ah, 0x04
    mov si, timeout_msg
    int 0x21
    mov ah, 0x05
    int 0x21

.ping_next:
    inc word [icmp_seq]

    call delay_1sec

    jmp .ping_loop

.ping_done:
    mov ah, 0x05
    int 0x21

    mov ah, 0x01
    mov si, summary_hdr
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x03
    mov si, sent_label
    int 0x21
    mov ax, [ping_sent]
    call print_decimal
    mov ah, 0x01
    mov si, packets_label
    int 0x21
    mov ah, 0x05
    int 0x21

    mov ah, 0x02
    mov si, recv_label
    int 0x21
    mov ax, [ping_recv]
    call print_decimal
    mov ah, 0x01
    mov si, packets_label
    int 0x21
    mov ah, 0x05
    int 0x21

    jmp .done

.show_usage:
    mov ah, 0x01
    mov si, usage_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.bad_ip:
    mov ah, 0x04
    mov si, bad_ip_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.nic_error:
    mov ah, 0x04
    mov si, nic_err_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.arp_failed:
    mov ah, 0x04
    mov si, arp_fail_msg
    int 0x21
    mov ah, 0x05
    int 0x21
    jmp .done

.done:
    popa
    ret


parse_args:
    push si
    mov ax, si
    push ax
.loop1:
    lodsb
    cmp al, 0
    je .finish
    cmp al, ' '
    jne .loop1
    dec si
    mov byte [si], 0
    inc si
.finish:
    pop ax
    push si
    mov si, ax
    cmp byte [si], 0
    pop si
    jne .has_arg
    xor ax, ax
.has_arg:
    pop si
    ret


parse_ipv4:
    pusha
    mov cx, 4

.next_octet:
    xor ax, ax
    xor bh, bh

.digit_loop:
    mov bl, [si]
    cmp bl, 0
    je .end_octet
    cmp bl, '.'
    je .dot_found
    cmp bl, '0'
    jb .ip_error
    cmp bl, '9'
    ja .ip_error

    mov dx, 10
    mul dx
    sub bl, '0'
    xor bh, bh
    add ax, bx
    inc si
    cmp ax, 255
    ja .ip_error
    jmp .digit_loop

.dot_found:
    inc si
.end_octet:
    stosb
    dec cx
    jcxz .ip_done
    cmp byte [si-1], 0
    je .ip_error
    jmp .next_octet

.ip_done:
    popa
    clc
    ret

.ip_error:
    popa
    stc
    ret


arp_resolve:
    pusha
    mov word [arp_timer], 0
    mov word [arp_retries], 0

.send_arp:
    mov di, tx_frame

    mov al, 0xFF
    mov cx, 6
    rep stosb

    mov si, our_mac
    mov cx, 6
    rep movsb

    mov byte [di], 0x08
    mov byte [di+1], 0x06
    add di, 2

    mov byte [di], 0x00
    mov byte [di+1], 0x01
    add di, 2

    mov byte [di], 0x08
    mov byte [di+1], 0x00
    add di, 2

    mov byte [di], 6
    inc di
    mov byte [di], 4
    inc di

    mov byte [di], 0x00
    mov byte [di+1], 0x01
    add di, 2

    mov si, our_mac
    mov cx, 6
    rep movsb

    mov si, our_ip
    mov cx, 4
    rep movsb

    xor al, al
    mov cx, 6
    rep stosb

    mov si, target_ip
    mov cx, 4
    rep movsb

    mov cx, 42
    mov si, tx_frame
    call ne2000_send
    jc .arp_timeout

.arp_poll:
    push ds
    pop es
    mov di, rx_frame
    call ne2000_poll
    jc .arp_no_pkt

    cmp byte [rx_frame + 12], 0x08
    jne .arp_no_pkt
    cmp byte [rx_frame + 13], 0x06
    jne .arp_no_pkt

    cmp byte [rx_frame + 20], 0x00
    jne .arp_no_pkt
    cmp byte [rx_frame + 21], 0x02
    jne .arp_no_pkt

    mov si, target_ip
    mov di, rx_frame + 28
    mov cx, 4
.arp_cmp_ip:
    cmpsb
    jne .arp_no_pkt
    loop .arp_cmp_ip

    mov si, rx_frame + 22
    mov di, target_mac
    mov cx, 6
    rep movsb

    popa
    clc
    ret

.arp_no_pkt:
    inc word [arp_timer]
    cmp word [arp_timer], 30000
    jb .arp_poll

    inc word [arp_retries]
    cmp word [arp_retries], 5
    jge .arp_timeout
    mov word [arp_timer], 0
    jmp .send_arp

.arp_timeout:
    popa
    stc
    ret


send_icmp_echo:
    pusha
    mov di, tx_frame

    mov si, target_mac
    mov cx, 6
    rep movsb
    mov si, our_mac
    mov cx, 6
    rep movsb
    mov byte [di], 0x08
    mov byte [di+1], 0x00
    add di, 2

    mov bx, di
    mov byte [di + IP_VER_IHL], 0x45
    mov byte [di + IP_TOS], 0x00
    mov byte [di + IP_TOTLEN], 0x00
    mov byte [di + IP_TOTLEN + 1], IP_TOTAL

    mov ax, [icmp_seq]
    xchg al, ah
    mov [di + IP_ID], ax

    mov byte [di + IP_FLAGS], 0x40
    mov byte [di + IP_FLAGS + 1], 0x00
    mov byte [di + IP_TTL], 64
    mov byte [di + IP_PROTO], 1
    mov word [di + IP_CHECKSUM], 0

    mov si, our_ip
    lea cx, [di + IP_SRC]
    mov di, cx
    push bx
    mov cx, 4
    rep movsb
    pop bx
    mov di, bx

    mov si, target_ip
    push bx
    lea cx, [di + IP_DST]
    push di
    mov di, cx
    mov cx, 4
    rep movsb
    pop di
    pop bx

    push di
    mov si, bx
    mov cx, 10
    call calc_checksum
    mov [bx + IP_CHECKSUM], ax
    pop di

    add di, IP_HDR_LEN
    mov bx, di

    mov byte [di + ICMP_TYPE], 8
    mov byte [di + ICMP_CODE], 0
    mov word [di + ICMP_CHECKSUM], 0
    mov byte [di + ICMP_ID], 0x12
    mov byte [di + ICMP_ID + 1], 0x34

    mov ax, [icmp_seq]
    xchg al, ah
    mov [di + ICMP_SEQ], ax

    add di, ICMP_DATA
    mov cx, ICMP_DATA_LEN
    mov al, 'A'
.fill_data:
    stosb
    inc al
    cmp al, 'Z' + 1
    jne .no_wrap_fill
    mov al, 'A'
.no_wrap_fill:
    loop .fill_data

    push bx
    mov si, bx
    mov cx, ICMP_TOTAL / 2
    call calc_checksum
    mov [bx + ICMP_CHECKSUM], ax
    pop bx

    mov si, tx_frame
    mov cx, FRAME_TOTAL
    call ne2000_send

    popa
    ret


wait_icmp_reply:
    pusha
    mov word [reply_timer], 0

.poll_loop:
    push ds
    pop es
    mov di, rx_frame
    call ne2000_poll
    jc .no_reply_pkt

    cmp byte [rx_frame + 12], 0x08
    jne .no_reply_pkt
    cmp byte [rx_frame + 13], 0x00
    jne .no_reply_pkt

    cmp byte [rx_frame + ETH_HDR_LEN + IP_PROTO], 1
    jne .no_reply_pkt

    cmp byte [rx_frame + ETH_HDR_LEN + IP_HDR_LEN + ICMP_TYPE], 0
    jne .no_reply_pkt

    cmp byte [rx_frame + ETH_HDR_LEN + IP_HDR_LEN + ICMP_ID], 0x12
    jne .no_reply_pkt
    cmp byte [rx_frame + ETH_HDR_LEN + IP_HDR_LEN + ICMP_ID + 1], 0x34
    jne .no_reply_pkt

    mov al, [rx_frame + ETH_HDR_LEN + IP_TTL]
    mov [reply_ttl], al

    popa
    clc
    ret

.no_reply_pkt:
    inc word [reply_timer]
    cmp word [reply_timer], 60000
    jge .reply_timeout
    jmp .poll_loop

.reply_timeout:
    popa
    stc
    ret


print_reply:
    pusha
    mov ah, 0x02
    mov si, reply_from_msg
    int 0x21

    mov si, [ip_str_ptr]
    mov ah, 0x01
    int 0x21

    mov ah, 0x01
    mov si, bytes_msg
    int 0x21

    mov ax, ICMP_TOTAL
    call print_decimal

    mov ah, 0x01
    mov si, seq_msg
    int 0x21

    mov ax, [icmp_seq]
    call print_decimal

    mov ah, 0x01
    mov si, ttl_msg
    int 0x21

    xor ah, ah
    mov al, [reply_ttl]
    call print_decimal

    mov ah, 0x05
    int 0x21

    popa
    ret


calc_checksum:
    push bx
    push cx
    push si
    push dx
    xor dx, dx
    xor bx, bx
.cksum_loop:
    lodsw
    add bx, ax
    adc dx, 0
    loop .cksum_loop
    mov ax, bx
    add ax, dx
    adc ax, 0
    not ax
    pop dx
    pop si
    pop cx
    pop bx
    ret


delay_1sec:
    pusha
    push es
    xor ax, ax
    mov es, ax
    mov eax, [es:0x046C]
    add eax, 18
.wait_tick:
    mov ebx, [es:0x046C]
    cmp ebx, eax
    jge .tick_done
    jmp .wait_tick
.tick_done:
    pop es
    popa
    ret


print_decimal:
    pusha
    mov cx, 0
    cmp ax, 0
    jne .divloop
    push ax
    mov ah, 0x0E
    mov al, '0'
    mov bl, 0x07
    int 0x10
    pop ax
    jmp .pd_done
.divloop:
    cmp ax, 0
    je .printdigits
    mov bx, 10
    xor dx, dx
    div bx
    push dx
    inc cx
    jmp .divloop
.printdigits:
    mov ah, 0x0E
    mov bl, 0x07
.digitloop:
    pop dx
    mov al, dl
    add al, '0'
    int 0x10
    dec cx
    jnz .digitloop
.pd_done:
    popa
    ret


%include "programs/lib/ne2000.inc"



section .data

usage_msg       db 'Usage: ping <IPv4 address>', 0
bad_ip_msg      db 'Error: invalid IP address', 0
nic_err_msg     db 'Error: NE2000 NIC not found at 0x300', 0
arp_fail_msg    db 'Error: ARP resolution failed (host unreachable)', 0
ping_header_msg db 'PING ', 0
reply_from_msg  db 'Reply from ', 0
bytes_msg       db ': bytes=', 0
seq_msg         db ' seq=', 0
ttl_msg         db ' TTL=', 0
timeout_msg     db 'Request timed out.', 0
summary_hdr     db '+---statistics--------+', 0
sent_label      db '|  Sent:     ', 0
recv_label      db '|  Received: ', 0
packets_label   db ' packets', 0

param_list      dw 0
ip_str_ptr      dw 0

our_ip          db 10, 0, 2, 15
our_mac         times 6 db 0
target_mac      times 6 db 0


ping_sent       dw 0
ping_recv       dw 0
icmp_seq        dw 0
reply_ttl       db 0
reply_timer     dw 0
arp_timer       dw 0
arp_retries     dw 0

tx_frame        times 1536 db 0
rx_frame        times 1536 db 0
