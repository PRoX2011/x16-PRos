; ========================================================================
; pcx.inc - Fast 16-color PCX image decoder for VGA mode 0x12 (640x480x16)
; Copyright (C) 2026 PRoX2011
; ========================================================================

%ifndef PCX_INC
%define PCX_INC

; ========================================================================
; pcx_draw - Draw a 16-color *.PCX image
; IN:  SI = pointer to filename (null-terminated)
;      CX = X coordinate (0..639)
;      DX = Y coordinate (0..479)
; OUT: CF = 0 on success, CF = 1 on failure
; ========================================================================
pcx_draw:
    pusha
    push ds
    push es
    cld

    mov [pcx_dst_x], cx
    mov [pcx_dst_y], dx

    cmp word [pcx_dst_x], 640
    jae .err_exit
    cmp word [pcx_dst_y], 480
    jae .err_exit

    call pcx_alloc_buf
    jc .err_exit

    call pcx_open_stream
    jc .err_cleanup

    test word [pcx_dst_x], 7
    jnz .slow_path
    mov ax, [pcx_dst_x]
    add ax, [pcx_width]
    jc .slow_path
    cmp ax, 640
    ja .slow_path
    mov ax, [pcx_bpl]
    shl ax, 3
    cmp ax, [pcx_width]
    jne .slow_path
%ifdef GRAFX_INC
    cmp byte [gfx_clipn], 0
    jne .slow_path
%endif
%ifdef SURF_INC
    cmp byte [surf_windowed], 0
    jne .slow_path
%endif

.fast_path:
    call pcx_vga_reset
    mov ax, 0xA000
    mov es, ax

.fast_row_loop:
    mov ax, [pcx_cur_y]
    cmp ax, [pcx_height]
    jae .draw_done
    add ax, [pcx_dst_y]
    cmp ax, 480
    jae .draw_done

    mov bx, 80
    mul bx
    mov bx, [pcx_dst_x]
    shr bx, 3
    add ax, bx
    mov di, ax

    call pcx_decode_row
    jc .decode_error

    mov bp, [pcx_bpl]
    mov si, 3200
    mov bl, 1
    push ds
    mov ds, [pcx_buf_seg]
.fast_plane_loop:
    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, bl
    out dx, al

    push si
    push di
    mov cx, bp
    rep movsb
    pop di
    pop si
    add si, 80
    shl bl, 1
    cmp bl, 0x10
    jb .fast_plane_loop
    pop ds

    inc word [pcx_cur_y]
    jmp .fast_row_loop

.slow_path:
.slow_row_loop:
    mov ax, [pcx_cur_y]
    cmp ax, [pcx_height]
    jae .draw_done
    mov bx, ax
    add bx, [pcx_dst_y]
    cmp bx, 480
    jae .draw_done

    call pcx_decode_row
    jc .decode_error

.slow_decode_pixels:
    xor si, si

.slow_pixel_loop:
    cmp si, [pcx_width]
    jae .slow_next_row

    mov bx, si
    shr bx, 3
    mov cx, si
    and cl, 7
    mov ch, 0x80
    shr ch, cl

    xor al, al
    mov es, [pcx_buf_seg]
    test [es:3200 + bx], ch
    jz .sp1
    or al, 1
.sp1:
    test [es:3280 + bx], ch
    jz .sp2
    or al, 2
.sp2:
    test [es:3360 + bx], ch
    jz .sp3
    or al, 4
.sp3:
    test [es:3440 + bx], ch
    jz .sp_plot
    or al, 8

.sp_plot:
    mov cx, [pcx_dst_x]
    add cx, si
    mov dx, [pcx_dst_y]
    add dx, [pcx_cur_y]
    cmp cx, 640
    jae .skip_plot
    cmp dx, 480
    jae .skip_plot
%ifdef SURF_INC
    cmp cx, [surf_cl]
    jl .skip_plot
    cmp cx, [surf_cr]
    jg .skip_plot
    cmp dx, [surf_ct]
    jl .skip_plot
    cmp dx, [surf_cb]
    jg .skip_plot
%endif
%ifdef GRAFX_INC
    call gfx_pixel
%endif
.skip_plot:
    inc si
    jmp .slow_pixel_loop

.slow_next_row:
    inc word [pcx_cur_y]
    jmp .slow_row_loop

.decode_error:
    mov byte [pcx_status], 1
.draw_done:
    call pcx_vga_reset
    call pcx_close_free

    cmp byte [pcx_status], 0
    jne .err_exit
    pop es
    pop ds
    popa
    clc
    ret

.err_cleanup:
    call pcx_close_free
.err_exit:
    pop es
    pop ds
    popa
    stc
    ret

pcx_vga_reset:
    mov dx, 0x3CE
    mov ax, 0x0001
    out dx, ax
    mov ax, 0x0003
    out dx, ax
    mov ax, 0x0005
    out dx, ax
    mov ax, 0xFF08
    out dx, ax
    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    ret

; ========================================================================
; pcx_alloc_buf - Reset stream state and allocate 4096-byte work buffer
; OUT: CF = 0 on success ([pcx_buf_seg] set), CF = 1 on failure
; ========================================================================
pcx_alloc_buf:
    push ax
    push bx
    mov word [pcx_handle], 0
    mov word [pcx_buf_seg], 0
    mov byte [pcx_status], 0
    mov bx, 4096
    mov ah, 0x01
    int 0x23
    jc .fail
    mov [pcx_buf_seg], ax
    pop bx
    pop ax
    clc
    ret
.fail:
    pop bx
    pop ax
    stc
    ret

; ========================================================================
; pcx_open_stream - Open a PCX file in current dir and validate its header
; IN:  SI = filename (null-terminated)
; OUT: CF = 0 on success (header parsed and stream reader ready)
;      CF = 1 on failure (stream closed if opened)
; ========================================================================
pcx_open_stream:
    pusha
    push es

    mov ax, 0x1500
    int 0x22
    jc .fail
    mov [pcx_handle], bx

    ; rread header into buffer offset 0
    mov cx, 128
    mov dx, [pcx_buf_seg]
    xor di, di
    mov ax, 0x1501
    int 0x22
    jc .fail_close
    cmp ax, 128
    jne .fail_close

    ; validate header
    mov es, [pcx_buf_seg]
    cmp byte [es:0], 0x0A
    jne .fail_close
    cmp byte [es:2], 1
    jne .fail_close
    cmp byte [es:3], 1
    jne .fail_close
    cmp byte [es:65], 4
    jne .fail_close

    ; calculate width, height, and bytes per plane row
    mov ax, [es:8]
    sub ax, [es:4]
    inc ax
    test ax, ax
    jz .fail_close
    cmp ax, 640
    ja .fail_close
    mov [pcx_width], ax

    mov ax, [es:10]
    sub ax, [es:6]
    inc ax
    test ax, ax
    jz .fail_close
    cmp ax, 480
    ja .fail_close
    mov [pcx_height], ax

    mov ax, [es:66]
    test ax, ax
    jz .fail_close
    cmp ax, 80
    ja .fail_close
    mov [pcx_bpl], ax
    shl ax, 3
    cmp ax, [pcx_width]
    jb .fail_close


    mov word [pcx_in_left], 0
    mov word [pcx_in_ptr], 128
    mov word [pcx_run_cnt], 0
    mov word [pcx_cur_y], 0

    pop es
    popa
    clc
    ret

.fail_close:
    mov bx, [pcx_handle]
    test bx, bx
    jz .fail
    mov ax, 0x1504
    int 0x22
    mov word [pcx_handle], 0
.fail:
    pop es
    popa
    stc
    ret

; ========================================================================
; pcx_decode_row - Decode one 4-plane PCX scanline into [pcx_buf_seg]:3200
; OUT: CF = 0 on success, CF = 1 on error
; ========================================================================
pcx_decode_row:
    pusha
    push es
    cld
    mov es, [pcx_buf_seg]
    mov byte [pcx_cur_plane], 0

.plane_loop:
    cmp byte [pcx_cur_plane], 4
    jae .ok

    mov al, [pcx_cur_plane]
    xor ah, ah
    mov bx, 80
    mul bx
    add ax, 3200
    mov di, ax
    mov bp, [pcx_bpl]

.plane_bytes:
    test bp, bp
    jle .plane_done

    mov ax, [pcx_run_cnt]
    test ax, ax
    jz .fetch_token

    cmp ax, bp
    jbe .run_fits
    mov ax, bp
.run_fits:
    mov cx, ax
    sub bp, cx
    sub [pcx_run_cnt], cx
    mov al, [pcx_run_val]
    rep stosb
    jmp .plane_bytes

.fetch_token:
    call pcx_read_byte
    jc .err
    cmp al, 0xC0
    jb .single

    and al, 0x3F
    xor ah, ah
    mov [pcx_run_cnt], ax
    call pcx_read_byte
    jc .err
    mov [pcx_run_val], al
    jmp .plane_bytes

.single:
    stosb
    dec bp
    jmp .plane_bytes

.plane_done:
    inc byte [pcx_cur_plane]
    jmp .plane_loop

.ok:
    pop es
    popa
    clc
    ret

.err:
    pop es
    popa
    stc
    ret

; ========================================================================
; pcx_close_free - Close PCX stream and free working buffer
; OUT: nothing (all registers preserved)
; ========================================================================
pcx_close_free:
    push ax
    push bx
    mov bx, [pcx_handle]
    test bx, bx
    jz .free_buf
    mov ax, 0x1504
    int 0x22
    mov word [pcx_handle], 0
.free_buf:
    mov ax, [pcx_buf_seg]
    test ax, ax
    jz .done
    mov ah, 0x02
    int 0x23
    mov word [pcx_buf_seg], 0
.done:
    pop bx
    pop ax
    ret

; ========================================================================
; pcx_read_byte - Refill and read next raw byte from stream
; OUT: AL = byte, CF = 1 on EOF/error
; ========================================================================
pcx_read_byte:
    push bx
    push cx
    push dx
    push di
    push es

    cmp word [pcx_in_left], 0
    jne .have_byte

    mov bx, [pcx_handle]
    mov cx, 3072
    mov dx, [pcx_buf_seg]
    mov di, 128
    mov ax, 0x1501
    int 0x22
    jc .eof
    test ax, ax
    jz .eof
    mov [pcx_in_left], ax
    mov word [pcx_in_ptr], 128

.have_byte:
    mov es, [pcx_buf_seg]
    mov di, [pcx_in_ptr]
    mov al, [es:di]
    inc word [pcx_in_ptr]
    dec word [pcx_in_left]
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    clc
    ret

.eof:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    stc
    ret

pcx_dst_x       dw 0
pcx_dst_y       dw 0
pcx_handle      dw 0
pcx_buf_seg     dw 0
pcx_width       dw 0
pcx_height      dw 0
pcx_bpl         dw 0
pcx_cur_y       dw 0
pcx_cur_plane   db 0
pcx_run_cnt     dw 0
pcx_run_val     db 0
pcx_status      db 0
pcx_in_left     dw 0
pcx_in_ptr      dw 0

%endif ; PCX_INC
