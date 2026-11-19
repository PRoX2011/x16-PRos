; ==================================================================
; x16-PRos -- GUI wallpaper selection, rendering and PCX caching
; ==================================================================

; ========================================================================
; SELECT_PCX_WALLPAPER - Pick a *.PCX file and cache it
; ========================================================================
select_pcx_wallpaper:
    pusha
    push es
    push ds
    pop es
    cld

    call wp_enter_images
    jnc .pick
    call wp_to_root
.pick:
    mov byte [surf_mb_prev], 1
    mov si, wp_pick_title
    mov di, cfg_buf
    call surf_pick
    pushf
    call wp_to_root
    popf
    jc .done

    mov si, cfg_buf
    call cache_pcx_wallpaper
    jc .done

    mov si, cfg_buf
    mov di, bg_pcx_path
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy

    mov byte [bg_is_pcx], 1
    call save_wallpaper_cfg
.done:
    pop es
    popa
    ret

; ========================================================================
; SET_STYLE_PATTERN - Copy built-in bg_style into bg_pattern and cache it
; ========================================================================
set_style_pattern:
    pusha
    push es

    push ds
    pop es
    cld

    mov byte [bg_is_pcx], 0
    mov al, [bg_style]
    xor ah, ah
    shl ax, 3
    mov si, bg_patterns
    add si, ax
    mov di, bg_pattern
    mov cx, 8
    rep movsb

    call cache_pattern_wallpaper

    pop es
    popa
    ret

; ========================================================================
; REBUILD_DESKTOP_CACHE - Render wallpaper and desktop icons into cache
; ========================================================================
rebuild_desktop_cache:
    push ax
    push si
    cmp byte [bg_is_pcx], 0
    je .pattern
    mov si, bg_pcx_path
    call cache_pcx_wallpaper
    jnc .done
    call set_style_pattern
    jmp .done
.pattern:
    call cache_pattern_wallpaper
.done:
    pop si
    pop ax
    ret

; ========================================================================
; APPLY_WALLPAPER - Apply built-in bg_style and save config
; ========================================================================
apply_wallpaper:
    call set_style_pattern
    call save_wallpaper_cfg
    ret

; ========================================================================
; CYCLE_WALLPAPER - Step to the next built-in wallpaper pattern
; ========================================================================
cycle_wallpaper:
    inc byte [bg_style]
    cmp byte [bg_style], BG_STYLE_COUNT
    jb .done
    mov byte [bg_style], 0
.done:
    call apply_wallpaper
    ret

; ========================================================================
; WP_TO_ROOT - Walk back to the root directory on the current drive
; ========================================================================
wp_to_root:
    push ax
.up:
    mov ah, 0x0A
    int 0x22
    jnc .up
    pop ax
    ret

; ========================================================================
; WP_ENTER_IMAGES - Enter PLE.DIR/GUI.DIR/IMAGES.DIR from root
; OUT: CF = 1 if any directory is missing
; ========================================================================
wp_enter_images:
    push ax
    push si
    call wp_to_root
    mov ah, 0x09
    mov si, pledir_name
    int 0x22
    jc .fail
    mov ah, 0x09
    mov si, guidir_name
    int 0x22
    jc .fail
    mov ah, 0x09
    mov si, imgdir_name
    int 0x22
    jc .fail
    pop si
    pop ax
    clc
    ret
.fail:
    pop si
    pop ax
    stc
    ret

; ========================================================================
; BAKE_DESKTOP_ICONS - Render desktop icons into off-screen VRAM cache
; ========================================================================
bake_desktop_icons:
    pusha
    call gfx_clip_reset
    call font_init
    mov word [gfx_vram_off], WP_VRAM_OFF - MENUBAR_H * 80
    call draw_desktop_icons
    mov word [gfx_vram_off], 0
    call pcx_vga_reset
    popa
    ret

; ========================================================================
; CACHE_PATTERN_WALLPAPER - Fill off-screen cache with bg_pattern and icons
; ========================================================================
cache_pattern_wallpaper:
    pusha
    push es
    cld
    call surf_begin_paint
    call pcx_vga_reset

    mov ax, 0xA000
    mov es, ax
    mov di, WP_VRAM_OFF
    mov bx, MENUBAR_H
    mov bp, WP_VRAM_ROWS
.vram_row:
    mov si, bx
    and si, 7
    mov al, [bg_pattern + si]
    mov cx, 80
    rep stosb
    inc bx
    dec bp
    jnz .vram_row

    mov ax, WP_RAM_SEG
    mov es, ax
    xor di, di
    mov dx, 4
.ram_plane:
    mov bx, MENUBAR_H + WP_VRAM_ROWS
    mov bp, WP_RAM_ROWS
.ram_row:
    mov si, bx
    and si, 7
    mov al, [bg_pattern + si]
    mov cx, 80
    rep stosb
    inc bx
    dec bp
    jnz .ram_row
    dec dx
    jnz .ram_plane

    call bake_desktop_icons
    call surf_end_paint
    pop es
    popa
    ret

; ========================================================================
; DRAW_DESKTOP_BG - Blit cached desktop wallpaper and baked icons
; ========================================================================
draw_desktop_bg:
    pusha
    push ds
    push es
    cld
    mov ax, 0xA000
    mov es, ax
    call pcx_vga_reset

    mov dx, 0x3CE
    mov ax, 0x0105
    out dx, ax
    mov ax, 0xA000
    mov ds, ax
    mov si, WP_VRAM_OFF
    mov di, MENUBAR_H * 80
    mov cx, WP_VRAM_ROWS * 80
    rep movsb

    mov ax, 0x0005
    out dx, ax
    mov ax, WP_RAM_SEG
    mov ds, ax
    xor si, si
    mov bl, 1
.ram_plane:
    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    mov di, (MENUBAR_H + WP_VRAM_ROWS) * 80
    mov cx, WP_RAM_PLANE_SZ / 2
    rep movsw
    shl bl, 1
    cmp bl, 0x10
    jb .ram_plane

    mov dx, 0x3C4
    mov ax, 0x0F02
    out dx, ax
    pop es
    pop ds
    popa
    ret

; ========================================================================
; CACHE_PCX_WALLPAPER - Decode and stretch a 16-color PCX to desktop cache
; IN : SI = filename in PLE.DIR/GUI.DIR/IMAGES.DIR
; OUT: CF = 0 on success (cache ready), CF = 1 on error
; ========================================================================
cache_pcx_wallpaper:
    pusha
    push es
    cld

    mov [.path_ptr], si
    mov byte [.cursor_hidden], 0

    mov ah, 0x0E
    int 0x22

    call wp_enter_images
    jc .err_restore

    call pcx_alloc_buf
    jc .err_restore

    mov si, [.path_ptr]
    call pcx_open_stream
    jc .err_cleanup

    call surf_begin_paint
    mov byte [.cursor_hidden], 1
    call pcx_vga_reset

    mov word [wp_src_y], 0xFFFF
    mov word [wp_dst_y], 0
    mov byte [.row_fresh], 0

.dst_row:
    mov ax, [wp_dst_y]
    cmp ax, DESKTOP_H
    jae .decode_done

    mul word [pcx_height]
    mov bx, DESKTOP_H
    div bx
    mov [.target_y], ax

.advance_src:
    mov ax, [wp_src_y]
    cmp ax, [.target_y]
    je .have_row
    call pcx_decode_row
    jc .decode_err
    inc word [wp_src_y]
    mov byte [.row_fresh], 1
    jmp .advance_src

.have_row:
    cmp byte [.row_fresh], 0
    je .store
    mov byte [.row_fresh], 0
    cmp word [pcx_width], 640
    je .store
    call wp_stretch_row_x
.store:
    call wp_store_dst_row
    inc word [wp_dst_y]
    jmp .dst_row

.decode_err:
    mov byte [pcx_status], 1

.decode_done:
    call pcx_vga_reset
    cmp byte [pcx_status], 0
    jne .end_paint
    call bake_desktop_icons
.end_paint:
    cmp byte [.cursor_hidden], 0
    je .close
    call surf_end_paint
.close:
    call pcx_close_free

    mov ah, 0x0F
    int 0x22

    cmp byte [pcx_status], 0
    jne .fail
    mov byte [bg_cache_ready], 1
    pop es
    popa
    clc
    ret

.err_cleanup:
    call pcx_close_free
.err_restore:
    mov ah, 0x0F
    int 0x22
.fail:
    pop es
    popa
    stc
    ret
.path_ptr      dw 0
.target_y      dw 0
.row_fresh     db 0
.cursor_hidden db 0

; ========================================================================
; WP_STRETCH_ROW_X - Stretch decoded row at pcx_buf_seg:3200 to 640 px wide
; ========================================================================
wp_stretch_row_x:
    pusha
    push es
    mov es, [pcx_buf_seg]
    mov byte [.plane], 0
.plane_loop:
    cmp byte [.plane], 4
    jae .copy_back

    mov al, [.plane]
    xor ah, ah
    mov bx, 80
    mul bx
    mov si, ax
    add si, 3200
    mov di, ax
    add di, 3520

    mov bh, 0x80
    xor dx, dx
    mov bp, [pcx_width]
    mov cx, 80
.byte_loop:
    mov ah, 8
    xor bl, bl
.bit_loop:
    shl bl, 1
    test [es:si], bh
    jz .b0
    or bl, 1
.b0:
    add dx, bp
    cmp dx, 640
    jb .no_step
    sub dx, 640
    ror bh, 1
    jnc .no_step
    inc si
.no_step:
    dec ah
    jnz .bit_loop
    mov [es:di], bl
    inc di
    loop .byte_loop

    inc byte [.plane]
    jmp .plane_loop

.copy_back:
    push ds
    push es
    pop ds
    mov si, 3520
    mov di, 3200
    mov cx, 160
    rep movsw
    pop ds
    pop es
    popa
    ret
.plane db 0

; ========================================================================
; WP_STORE_DST_ROW - Write stretched row from pcx_buf_seg:3200 into cache
; ========================================================================
wp_store_dst_row:
    pusha
    push es
    mov ax, [wp_dst_y]
    cmp ax, WP_VRAM_ROWS
    jae .to_ram

    mov bx, 80
    mul bx
    add ax, WP_VRAM_OFF
    mov [.off], ax

    mov ax, 0xA000
    mov es, ax
    mov si, 3200
    mov bl, 1
.vram_plane:
    mov dx, 0x3C4
    mov al, 0x02
    out dx, al
    inc dx
    mov al, bl
    out dx, al

    mov di, [.off]
    push ds
    mov ds, [pcx_buf_seg]
    mov cx, 40
    rep movsw
    pop ds

    shl bl, 1
    cmp bl, 0x10
    jb .vram_plane
    jmp .done

.to_ram:
    sub ax, WP_VRAM_ROWS
    mov bx, 80
    mul bx
    mov di, ax
    mov ax, WP_RAM_SEG
    mov es, ax
    mov si, 3200
    mov cx, 4
.ram_plane:
    push cx
    push di
    push ds
    mov ds, [pcx_buf_seg]
    mov cx, 40
    rep movsw
    pop ds
    pop di
    add di, WP_RAM_PLANE_SZ
    pop cx
    loop .ram_plane

.done:
    pop es
    popa
    ret
.off dw 0

wp_src_y       dw 0
wp_dst_y       dw 0
