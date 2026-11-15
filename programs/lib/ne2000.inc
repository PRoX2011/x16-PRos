;  +----------------------------------------------------------------+
;  |  Made by Gabriel Sîrbu and distributed under the MIT license   |
;  +----------------------------------------------------------------+

NE_BASE         equ 0x300

NE_CR           equ (NE_BASE + 0x00)
NE_PSTART       equ (NE_BASE + 0x01)
NE_PSTOP        equ (NE_BASE + 0x02)
NE_BNRY         equ (NE_BASE + 0x03)
NE_TPSR         equ (NE_BASE + 0x04)
NE_TSR          equ (NE_BASE + 0x04)
NE_TBCR0        equ (NE_BASE + 0x05)
NE_TBCR1        equ (NE_BASE + 0x06)
NE_ISR          equ (NE_BASE + 0x07)
NE_RSAR0        equ (NE_BASE + 0x08)
NE_RSAR1        equ (NE_BASE + 0x09)
NE_RBCR0        equ (NE_BASE + 0x0A)
NE_RBCR1        equ (NE_BASE + 0x0B)
NE_RCR          equ (NE_BASE + 0x0C)    
NE_TCR          equ (NE_BASE + 0x0D)
NE_DCR          equ (NE_BASE + 0x0E)
NE_IMR          equ (NE_BASE + 0x0F)

NE_PAR0         equ (NE_BASE + 0x01)
NE_CURR         equ (NE_BASE + 0x07)

NE_DATA         equ (NE_BASE + 0x10)
NE_RESET        equ (NE_BASE + 0x1F)

NE_START_PG     equ 0x40
NE_STOP_PG      equ 0x80
NE_RX_START     equ 0x46

NE_CMD_STOP     equ 0x21
NE_CMD_START    equ 0x22
NE_CMD_TX       equ 0x26
NE_CMD_RREAD    equ 0x0A
NE_CMD_RWRITE   equ 0x12
NE_CMD_PAGE1    equ 0x40

NE_ISR_PRX      equ 0x01
NE_ISR_PTX      equ 0x02
NE_ISR_RDC      equ 0x40

ne2000_init:
    pusha

    mov dx, NE_RESET
    in al, dx
    out dx, al

    mov cx, 0x1FFF
.reset_delay:
    loop .reset_delay

    mov dx, NE_CR
    mov al, NE_CMD_STOP
    out dx, al

    mov dx, NE_ISR
    mov al, 0xFF
    out dx, al

    in al, dx
    cmp al, 0xFF
    je .nic_fail

    ; Byte-wide DMA, normal operation
    mov dx, NE_DCR
    mov al, 0x48
    out dx, al

    mov dx, NE_RBCR0
    xor al, al
    out dx, al
    mov dx, NE_RBCR1
    out dx, al

    mov dx, NE_RCR
    mov al, 0x20                        
    out dx, al

    mov dx, NE_TCR
    mov al, 0x02                        
    out dx, al

    mov dx, NE_PSTART
    mov al, NE_RX_START
    out dx, al

    mov dx, NE_BNRY
    mov al, NE_RX_START
    out dx, al

    mov dx, NE_PSTOP
    mov al, NE_STOP_PG
    out dx, al

    mov dx, NE_ISR
    mov al, 0xFF
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_STOP + NE_CMD_PAGE1
    out dx, al

    mov al, 0x52
    mov dx, NE_PAR0 + 0
    out dx, al
    mov al, 0x54
    mov dx, NE_PAR0 + 1
    out dx, al
    mov al, 0x00
    mov dx, NE_PAR0 + 2
    out dx, al
    mov al, 0x12
    mov dx, NE_PAR0 + 3
    out dx, al
    mov al, 0x34
    mov dx, NE_PAR0 + 4
    out dx, al
    mov al, 0x56
    mov dx, NE_PAR0 + 5
    out dx, al

    mov dx, NE_CURR
    mov al, NE_RX_START + 1
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_STOP
    out dx, al

    mov dx, NE_RCR
    mov al, 0x0C                        
    out dx, al

    mov dx, NE_TCR
    mov al, 0x00
    out dx, al

    mov dx, NE_IMR
    xor al, al                          
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_START
    out dx, al

    popa
    clc
    ret

.nic_fail:
    popa
    stc
    ret

ne2000_get_mac:
    pusha
    mov dx, NE_CR
    mov al, NE_CMD_START + NE_CMD_PAGE1
    out dx, al

    mov cx, 6
    mov dx, NE_PAR0
.read_mac_loop:
    in al, dx
    stosb
    inc dx
    loop .read_mac_loop

    mov dx, NE_CR
    mov al, NE_CMD_START
    out dx, al
    popa
    ret

ne2000_wait_isr:
    push cx
    push dx
    mov ah, al
    mov cx, 0xFFFF
.loop:
    mov dx, NE_ISR
    in al, dx
    test al, ah
    jnz .got_it
    loop .loop
    pop dx
    pop cx
    stc
    ret
.got_it:
    mov al, ah
    out dx, al
    pop dx
    pop cx
    clc
    ret

ne2000_send:
    pusha

    cmp cx, 60
    jae .no_pad
    mov cx, 60
.no_pad:
    mov bx, cx

    mov dx, NE_CR
.wait_tx:
    in al, dx
    test al, 0x04
    jz .tx_clear
    jmp .wait_tx
.tx_clear:

    mov al, NE_CMD_START
    out dx, al

    mov ax, bx
    mov dx, NE_RBCR0
    out dx, al
    mov al, ah
    mov dx, NE_RBCR1
    out dx, al

    mov dx, NE_RSAR0
    xor al, al
    out dx, al
    mov al, NE_START_PG
    mov dx, NE_RSAR1
    out dx, al

    mov dx, NE_ISR
    mov al, NE_ISR_RDC
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_RWRITE
    out dx, al

    mov dx, NE_DATA
    mov cx, bx
.write_loop:
    lodsb
    out dx, al
    loop .write_loop

    mov al, NE_ISR_RDC
    call ne2000_wait_isr

    mov dx, NE_TPSR
    mov al, NE_START_PG
    out dx, al

    mov ax, bx
    mov dx, NE_TBCR0
    out dx, al
    mov al, ah
    mov dx, NE_TBCR1
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_TX
    out dx, al

    mov cx, 0xFFFF
.wait_ptx:
    mov dx, NE_TSR
    in al, dx
    test al, 0x01
    jnz .tx_done
    loop .wait_ptx
.tx_done:

    mov dx, NE_ISR
    mov al, NE_ISR_PTX
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_START
    out dx, al

    popa
    clc
    ret

.send_fail:
    mov dx, NE_CR
    mov al, NE_CMD_START
    out dx, al
    popa
    clc
    ret


ne2000_poll:
    pusha

    mov dx, NE_CR
    mov al, NE_CMD_START + NE_CMD_PAGE1
    out dx, al
    mov dx, NE_CURR
    in al, dx
    mov ch, al

    mov dx, NE_CR
    mov al, NE_CMD_START
    out dx, al
    mov dx, NE_BNRY
    in al, dx

    inc al
    cmp al, NE_STOP_PG
    jb .page_ok
    mov al, NE_RX_START
.page_ok:
    cmp al, ch
    je .ring_empty

    mov bh, al
    mov dx, NE_RSAR0
    xor al, al
    out dx, al
    mov al, bh
    mov dx, NE_RSAR1
    out dx, al

    mov dx, NE_RBCR0
    mov al, 4
    out dx, al
    mov dx, NE_RBCR1
    xor al, al
    out dx, al

    mov dx, NE_ISR
    mov al, NE_ISR_RDC
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_RREAD
    out dx, al

    mov dx, NE_DATA
    in al, dx
    in al, dx
    mov bl, al
    in al, dx
    mov cl, al
    in al, dx
    mov ch, al

    push cx
    push bx
    mov al, NE_ISR_RDC
    call ne2000_wait_isr
    pop bx
    pop cx

    mov ax, cx
    sub ax, 4
    jbe .ring_empty
    mov cx, ax
    mov dx, NE_RSAR0
    mov al, 4
    out dx, al
    mov al, bh
    mov dx, NE_RSAR1
    out dx, al

    mov dx, NE_RBCR0
    mov al, cl
    out dx, al
    mov al, ch
    mov dx, NE_RBCR1
    out dx, al

    mov dx, NE_ISR
    mov al, NE_ISR_RDC
    out dx, al

    mov dx, NE_CR
    mov al, NE_CMD_RREAD
    out dx, al

    mov dx, NE_DATA
.read_loop:
    in al, dx
    stosb
    loop .read_loop

    push bx
    mov al, NE_ISR_RDC
    call ne2000_wait_isr
    pop bx
    mov al, bl
    dec al
    cmp al, NE_RX_START
    jae .bnry_ok
    mov al, NE_STOP_PG - 1
.bnry_ok:
    mov dx, NE_BNRY
    out dx, al

    mov dx, NE_ISR
    mov al, NE_ISR_PRX
    out dx, al

    popa
    clc
    ret

.ring_empty:
    popa
    stc
    ret

target_ip       db 0, 0, 0, 0
