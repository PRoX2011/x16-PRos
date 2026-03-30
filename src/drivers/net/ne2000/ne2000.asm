BITS 16
section .text

CR_STP      equ  0x01
CR_STA      equ  0x02
CR_TXP      equ  0x04
CR_RD_RD    equ  0x08
CR_RD_WR    equ  0x10
CR_NODMA    equ  0x20
CR_PG0      equ  0x00
CR_PG1      equ  0x40
CR_PG2      equ  0x80

CR_PG0_STP  equ  CR_PG0 | CR_NODMA | CR_STP    ; 0x21
CR_PG0_STA  equ  CR_PG0 | CR_NODMA | CR_STA    ; 0x22
CR_PG1_STP  equ  CR_PG1 | CR_NODMA | CR_STP    ; 0x61
CR_PG1_STA  equ  CR_PG1 | CR_NODMA | CR_STA    ; 0x62
CR_DMA_WR   equ  CR_PG0 | CR_RD_WR | CR_STA    ; 0x12
CR_DMA_RD   equ  CR_PG0 | CR_RD_RD | CR_STA    ; 0x0A

ISR_PRX     equ  0x01
ISR_PTX     equ  0x02
ISR_RXE     equ  0x04
ISR_TXE     equ  0x08
ISR_OVW     equ  0x10
ISR_CNT     equ  0x20
ISR_RDC     equ  0x40
ISR_RST     equ  0x80

DCR_INIT      equ  0x49   ; 16-bit DMA, 80x86 byte order, 16-byte FIFO
RCR_MONITOR   equ  0x20
RCR_NORMAL    equ  0x04
TCR_NORMAL    equ  0x00
TCR_LOOPBACK  equ  0x02

TX_PAGE     equ  0x40
RX_PSTART   equ  0x46
RX_PSTOP    equ  0x80

ne2000_init:
        push    bx
        push    cx
        push    si

        mov     [ne2k_iobase], ax
        mov     [ne2k_irq],    bl

        mov     dx, ax
        add     dx, 0x1F        ; Reset port
        in      al, dx          ; Any read/write resets the card
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     cx, 0x200
.init_wait_rst:
        in      al, dx
        test    al, ISR_RST
        jnz     .init_rst_ok
        loop    .init_wait_rst
        stc
        jmp     .init_exit

.init_rst_ok:
        mov     al, 0xFF
        out     dx, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0_STP
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0E        ; DCR (Data Configuration Register)
        mov     al, DCR_INIT    ; 0x49 = 16-bit DMA, normal loopback, 8-byte FIFO
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0A
        xor     al, al
        out     dx, al
        inc     dx
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0F
        xor     al, al
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, 0xFF
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0C
        mov     al, RCR_MONITOR
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0D
        mov     al, TCR_LOOPBACK
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x04
        mov     al, TX_PAGE
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x01
        mov     al, RX_PSTART
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x02
        mov     al, RX_PSTOP
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x03
        mov     al, RX_PSTOP - 1
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0A
        mov     al, 32
        out     dx, al
        inc     dx
        xor     al, al
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x08
        xor     al, al
        out     dx, al
        inc     dx
        out     dx, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_DMA_RD
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x10
        lea     si, [ne2k_prom]
        mov     cx, 16
.init_prom_loop:
        in      ax, dx
        mov     [si],     al
        mov     [si + 1], ah
        add     si, 2
        loop    .init_prom_loop

        ; Wait for RDC.
        ; Same reasoning as RST poll — 0x200 is ample for QEMU/real hardware.
        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     cx, 0x200
.init_prom_rdc_wait:
        in      al, dx
        test    al, ISR_RDC
        jnz     .init_prom_rdc_done
        loop    .init_prom_rdc_wait
        stc
        jmp     .init_exit

.init_prom_rdc_done:
        mov     al, ISR_RDC
        out     dx, al

        lea     si, [ne2k_prom]
        cmp     byte [si + 14], 0x57
        je      .init_sig_ok
        cmp     byte [si + 14], 0xFF
        je      .init_bad_sig
        
        ; Not 0x57, but not 0xFF either — maybe it is an NE2000 clone
        jmp     .init_sig_ok

.init_bad_sig:
        stc
        jmp     .init_exit

.init_sig_ok:
        lea     si, [ne2k_prom]
        lea     bx, [ne2k_mac]

        mov     al, [si]
        cmp     al, [si + 1]
        je      .mac_doubled

        mov     cx, 6
.mac_plain:
        mov     al, [si]
        mov     [bx], al
        inc     si
        inc     bx
        loop    .mac_plain
        jmp     .mac_extracted

.mac_doubled:
        mov     cx, 6
.mac_doubled_loop:
        mov     al, [si]
        mov     [bx], al
        add     si, 2
        inc     bx
        loop    .mac_doubled_loop

.mac_extracted:
        mov     dx, [ne2k_iobase]
        mov     al, CR_PG1_STP
        out     dx, al

        mov     bx, [ne2k_iobase]
        lea     si, [ne2k_mac]
        mov     cx, 6
.par_loop:
        inc     bx
        mov     dx, bx
        mov     al, [si]
        out     dx, al
        inc     si
        loop    .par_loop

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, RX_PSTART
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x08
        mov     cx, 8
.mar_loop:
        mov     al, 0xFF
        out     dx, al
        inc     dx
        loop    .mar_loop

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0_STP
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x03
        mov     al, RX_PSTART
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0C
        mov     al, RCR_NORMAL
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0D
        mov     al, TCR_NORMAL
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, 0xFF
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x0F
        mov     al, ISR_PRX | ISR_PTX | ISR_RXE | ISR_TXE | ISR_OVW
        out     dx, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0_STA
        out     dx, al

        mov     byte [ne2k_rx_cur], RX_PSTART

        clc

.init_exit:
        pop     si
        pop     cx
        pop     bx
        ret

ne2000_send:
        push    bx
        push    cx
        push    si

        mov     bx, cx

        mov     dx, [ne2k_iobase]
        mov     cx, 0x4000
.send_busy_wait:
        in      al, dx
        test    al, CR_TXP
        jz      .send_not_busy
        loop    .send_busy_wait
        stc
        jmp     .send_exit

.send_not_busy:
        mov     dx, [ne2k_iobase]
        add     dx, 0x0A
        mov     al, bl
        out     dx, al
        inc     dx
        mov     al, bh
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, ISR_RDC
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x08
        xor     al, al
        out     dx, al
        inc     dx
        mov     al, TX_PAGE
        out     dx, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_DMA_WR
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x10
        mov     cx, bx
        shr     cx, 1
        jz      .send_odd_byte

.send_word_loop:
        lodsw
        out     dx, ax
        loop    .send_word_loop

.send_odd_byte:
        test    bx, 1
        jz      .send_dma_done
        xor     ah, ah
        lodsb
        out     dx, ax

.send_dma_done:
        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     cx, 0xFFFF
.send_rdc_wait:
        in      al, dx
        test    al, ISR_RDC
        jnz     .send_rdc_done
        loop    .send_rdc_wait
        stc
        jmp     .send_exit

.send_rdc_done:
        mov     al, ISR_RDC
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x04
        mov     al, TX_PAGE
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x05
        mov     al, bl
        out     dx, al
        inc     dx
        mov     al, bh
        out     dx, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0 | CR_NODMA | CR_STA | CR_TXP
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     cx, 0xFFFF
.send_tx_wait:
        in      al, dx
        test    al, ISR_PTX | ISR_TXE
        jnz     .send_tx_done
        loop    .send_tx_wait
        stc
        jmp     .send_exit

.send_tx_done:
        test    al, ISR_TXE
        jnz     .send_tx_error

        mov     al, ISR_PTX
        out     dx, al
        clc
        jmp     .send_exit

.send_tx_error:
        mov     al, ISR_TXE
        out     dx, al
        stc

.send_exit:
        pop     si
        pop     cx
        pop     bx
        ret

ne2000_recv:
        push    bx
        push    si
        push    di

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG1_STA
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        in      al, dx
        mov     bl, al

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0_STA
        out     dx, al

        mov     al, [ne2k_rx_cur]
        cmp     bl, al
        je      .recv_none

        mov     dx, [ne2k_iobase]
        add     dx, 0x0A
        mov     al, 4
        out     dx, al
        inc     dx
        xor     al, al
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x08
        xor     al, al
        out     dx, al
        inc     dx
        mov     al, [ne2k_rx_cur]
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, ISR_RDC
        out     dx, al
        mov     dx, [ne2k_iobase]
        mov     al, CR_DMA_RD
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x10
        in      ax, dx
        mov     [ne2k_rx_hdr + 0], al
        mov     [ne2k_rx_hdr + 1], ah
        in      ax, dx
        mov     [ne2k_rx_hdr + 2], al
        mov     [ne2k_rx_hdr + 3], ah

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     cx, 0xFFFF
.recv_hdr_rdc_wait:
        in      al, dx
        test    al, ISR_RDC
        jnz     .recv_hdr_rdc_done
        loop    .recv_hdr_rdc_wait
        jmp     .recv_skip

.recv_hdr_rdc_done:
        mov     al, ISR_RDC
        out     dx, al

        mov     al, [ne2k_rx_hdr + 0]
        test    al, 0x01
        jz      .recv_skip

        xor     bh, bh
        mov     bl, [ne2k_rx_hdr + 2]
        mov     bh, [ne2k_rx_hdr + 3]

        cmp     bx, 18
        jb      .recv_skip
        cmp     bx, 1518
        ja      .recv_skip

        sub     bx, 4

        xor     ah, ah
        mov     al, [ne2k_rx_cur]
        shl     ax, 8
        add     ax, 4
        add     ax, bx

        cmp     ax, RX_PSTOP * 256
        ja      .recv_two_reads

        xor     ah, ah
        mov     al, [ne2k_rx_cur]
        shl     ax, 8
        add     ax, 4
        mov     cx, bx
        call    ne2k_dma_read
        jmp     .recv_update_bnry

.recv_two_reads:
        xor     ah, ah
        mov     al, [ne2k_rx_cur]
        mov     si, RX_PSTOP
        sub     si, ax
        shl     si, 8
        sub     si, 4

        shl     ax, 8
        add     ax, 4
        mov     cx, si
        call    ne2k_dma_read

        mov     cx, bx
        sub     cx, si
        mov     ax, RX_PSTART * 256
        call    ne2k_dma_read

.recv_update_bnry:
        mov     al, [ne2k_rx_hdr + 1]
        mov     [ne2k_rx_cur], al

        dec     al
        cmp     al, RX_PSTART
        jae     .recv_bnry_ok
        mov     al, RX_PSTOP - 1
.recv_bnry_ok:
        mov     dx, [ne2k_iobase]
        add     dx, 0x03
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, ISR_PRX
        out     dx, al

        mov     cx, bx
        clc
        jmp     .recv_exit

.recv_skip:
        mov     al, [ne2k_rx_hdr + 1]
        cmp     al, RX_PSTART
        jb      .recv_skip_advance_one
        cmp     al, RX_PSTOP
        jb      .recv_skip_use_next
.recv_skip_advance_one:
        mov     al, [ne2k_rx_cur]
        inc     al
        cmp     al, RX_PSTOP
        jb      .recv_skip_use_next
        mov     al, RX_PSTART
.recv_skip_use_next:
        mov     [ne2k_rx_cur], al
        dec     al
        cmp     al, RX_PSTART
        jae     .recv_skip_bnry_ok
        mov     al, RX_PSTOP - 1
.recv_skip_bnry_ok:
        mov     dx, [ne2k_iobase]
        add     dx, 0x03
        out     dx, al

.recv_none:
        stc

.recv_exit:
        pop     di
        pop     si
        pop     bx
        ret

ne2000_irq:
        push    dx

        mov     dx, [ne2k_iobase]
        mov     al, CR_PG0_STA
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        in      al, dx
        out     dx, al

        pop     dx
        ret

ne2k_dma_read:
        push    si

        push    ax
        push    cx
        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        mov     al, ISR_RDC
        out     dx, al
        pop     cx
        pop     ax

        push    ax
        mov     dx, [ne2k_iobase]
        add     dx, 0x0A
        mov     al, cl
        out     dx, al
        inc     dx
        mov     al, ch
        out     dx, al
        pop     ax

        push    ax
        mov     dx, [ne2k_iobase]
        add     dx, 0x08
        out     dx, al
        inc     dx
        mov     al, ah
        out     dx, al
        pop     ax

        mov     dx, [ne2k_iobase]
        mov     al, CR_DMA_RD
        out     dx, al

        mov     dx, [ne2k_iobase]
        add     dx, 0x10

        push    cx
        shr     cx, 1
        jz      .dma_rd_trailing

.dma_rd_word_loop:
        in      ax, dx
        stosw
        loop    .dma_rd_word_loop

.dma_rd_trailing:
        pop     cx
        test    cx, 1
        jz      .dma_rd_poll

        in      ax, dx
        stosb

.dma_rd_poll:
        mov     dx, [ne2k_iobase]
        add     dx, 0x07
        push    cx
        mov     cx, 0xFFFF
.dma_rd_rdc_wait:
        in      al, dx
        test    al, ISR_RDC
        jnz     .dma_rd_rdc_done
        loop    .dma_rd_rdc_wait
.dma_rd_rdc_done:
        mov     al, ISR_RDC
        out     dx, al
        pop     cx

        pop     si
        ret

ne2000_probe:
        push    si
        push    bx

        lea     si, [ne2k_probe_ports]

.probe_loop:
        mov     ax, [si]
        test    ax, ax
        jz      .probe_fail

        ; Try IRQ 9 (common for QEMU/PCI ne2000 clones) then 3
        mov     bl, 9
        call    ne2000_init
        jnc     .probe_ok

        mov     bl, 3
        call    ne2000_init
        jnc     .probe_ok

        add     si, 2
        jmp     .probe_loop

.probe_ok:
        clc
        pop     bx
        pop     si
        ret

.probe_fail:
        stc
        pop     bx
        pop     si
        ret

section .data

ne2k_iobase       dw  0x0000
ne2k_irq          db  0x00
ne2k_mac          db  0, 0, 0, 0, 0, 0
ne2k_rx_cur       db  RX_PSTART
ne2k_rx_hdr       db  0, 0, 0, 0
ne2k_prom         times 32 db 0
ne2k_probe_ports  dw  0x300, 0x240, 0x280, 0x2C0, 0x320, 0x340, 0x360, 0x0000
