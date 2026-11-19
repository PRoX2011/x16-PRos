; ========================================================================
; GUI_ENTER_CONF - Moves into A:/CONF.DIR/GUI.DIR
; IN : nothing
; OUT : CF = 1 if the directory is not there
; ========================================================================
gui_enter_conf:
    mov ah, 0x0E
    int 0x22
    call wp_to_root

    mov ah, 0x09
    mov si, cfg_conf_dir
    int 0x22
    jc .fail

    mov ah, 0x09
    mov si, cfg_gui_dir
    int 0x22
    jc .fail
    clc
    ret
.fail:
    mov ah, 0x0F
    int 0x22
    stc
    ret

; ========================================================================
; GUI_PARSE_NUM - Reads a decimal number out of cfg_buf
; IN : BX = byte count in cfg_buf
; OUT : AX = value, CF = 1 if no digit was found
; ========================================================================
gui_parse_num:
    push bx
    push cx
    push dx
    push si
    mov si, cfg_buf
    xor ax, ax
    xor cx, cx
.scan:
    test bx, bx
    jz .done
    mov dl, [si]
    inc si
    dec bx
    cmp dl, '0'
    jb .done
    cmp dl, '9'
    ja .done
    mov cx, 1
    push dx
    mov dx, 10
    mul dx
    pop dx
    sub dl, '0'
    xor dh, dh
    add ax, dx
    jmp .scan
.done:
    test cx, cx
    jz .none
    pop si
    pop dx
    pop cx
    pop bx
    clc
    ret
.none:
    pop si
    pop dx
    pop cx
    pop bx
    stc
    ret

; ========================================================================
; GUI_LOAD_ONE - Reads one number out of a config file
; IN : SI = file name, DI = word to fill, BX = value ceiling
; OUT : the word is left alone when the file is missing or unreadable
; ========================================================================
gui_load_one:
    pusha
    mov [.dest], di
    mov [.max], bx

    mov ah, 0x02
    mov cx, cfg_buf
    int 0x22
    jc .done

    call gui_parse_num
    jc .done
    cmp ax, [.max]
    ja .done
    mov di, [.dest]
    mov [di], ax
.done:
    popa
    ret
.dest dw 0
.max  dw 0

; ========================================================================
; GUI_PARSE_PATTERN - Reads up to eight byte values out of cfg_buf
; IN :  BX = byte count in cfg_buf
;       DI = eight-byte destination
; OUT : CF = 1 when the file held fewer than eight numbers
; ========================================================================
gui_parse_pattern:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, cfg_buf
    xor cx, cx

.next_num:
    cmp cx, 8
    jae .full
    test bx, bx
    jz .short

.skip:
    mov dl, [si]
    cmp dl, '0'
    jb .not_digit
    cmp dl, '9'
    jbe .number
.not_digit:
    inc si
    dec bx
    jnz .skip
    jmp .short

.number:
    xor ax, ax
.digits:
    test bx, bx
    jz .store
    mov dl, [si]
    cmp dl, '0'
    jb .store
    cmp dl, '9'
    ja .store
    push dx
    mov dx, 10
    mul dx
    pop dx
    sub dl, '0'
    xor dh, dh
    add ax, dx
    inc si
    dec bx
    jmp .digits

.store:
    stosb
    inc cx
    jmp .next_num

.full:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

.short:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; ========================================================================
; GUI_NUM_TO_TEXT - Writes AL as decimal at ES:DI
; IN :  AL = value
;       ES:DI = where to put it
; OUT : DI left past the last digit
; ========================================================================
gui_num_to_text:
    push ax
    push bx
    push cx
    push dx

    xor ah, ah
    xor cx, cx
    mov bx, 10
.split:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .split
.emit:
    pop ax
    add al, '0'
    stosb
    loop .emit

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ========================================================================
; GUI_ENTER_WALL_CONF - go to <X>:/CONF.DIR/GUI.DIR/WALL.DIR
; IN : nothing
; OUT : CF = 1 if the directory could not be entered
; ========================================================================
gui_enter_wall_conf:
    call gui_enter_conf
    jc .out
    mov ah, 0x09
    mov si, cfg_wall_dir
    int 0x22
    jnc .ok
    mov ah, 0x0B
    mov si, cfg_wall_dir
    int 0x22
    jc .fail
    mov ah, 0x09
    mov si, cfg_wall_dir
    int 0x22
    jc .fail
.ok:
    clc
    ret
.fail:
    mov ah, 0x0F
    int 0x22
    stc
.out:
    ret

; ========================================================================
; SAVE_WALLPAPER_CFG - Store VARIANT.CFG and PATERN.CFG or IMAGE.CFG
; ========================================================================
save_wallpaper_cfg:
    pusha
    push es

    call gui_enter_wall_conf
    jc .done

    push ds
    pop es
    cld

    mov byte [cfg_buf], '0'
    cmp byte [bg_is_pcx], 0
    je .write_variant
    mov byte [cfg_buf], '1'
.write_variant:
    mov si, cfg_variant_file
    mov cx, 1
    call .write_file

    mov di, cfg_buf
    cmp byte [bg_is_pcx], 0
    jne .pcx

    mov si, bg_pattern
    mov cx, 8
.row:
    lodsb
    call gui_num_to_text
    mov al, 10
    stosb
    loop .row
    mov si, cfg_patern_file
    jmp .write

.pcx:
    mov si, bg_pcx_path
.copy_path:
    lodsb
    test al, al
    jz .end_path
    stosb
    jmp .copy_path
.end_path:
    mov al, 10
    stosb
    mov si, cfg_image_file

.write:
    mov cx, di
    sub cx, cfg_buf
    call .write_file

    mov ah, 0x0F
    int 0x22

.done:
    pop es
    popa
    ret

.write_file:
    mov ah, 0x06
    int 0x22
    mov ah, 0x03
    mov bx, cfg_buf
    int 0x22
    ret

; ========================================================================
; LOAD_WALLPAPER_CFG - Read VARIANT.CFG and PATERN.CFG or IMAGE.CFG
; ========================================================================
load_wallpaper_cfg:
    pusha
    push es

    push ds
    pop es
    cld

    mov ah, 0x09
    mov si, cfg_wall_dir
    int 0x22
    jc .done

    mov ah, 0x02
    mov si, cfg_variant_file
    mov cx, cfg_buf
    int 0x22
    jc .pcx

    call gui_parse_num
    jc .pcx
    cmp ax, 0
    je .pattern

.pcx:
    mov byte [bg_is_pcx], 1
    mov ah, 0x02
    mov si, cfg_image_file
    mov cx, cfg_buf
    int 0x22
    jc .done

    mov si, cfg_buf
    mov di, bg_pcx_path
    cmp bx, 63
    jbe .copy_len_ok
    mov bx, 63
.copy_len_ok:
    xor cx, cx
.copy_pcx:
    test bx, bx
    jz .pcx_term
    lodsb
    cmp al, 13
    je .pcx_term
    cmp al, 10
    je .pcx_term
    test al, al
    jz .pcx_term
    stosb
    inc cx
    dec bx
    jmp .copy_pcx
.pcx_term:
    test cx, cx
    jz .done
    xor al, al
    stosb
    jmp .done

.pattern:
    mov byte [bg_is_pcx], 0
    mov ah, 0x02
    mov si, cfg_patern_file
    mov cx, cfg_buf
    int 0x22
    jc .fallback

    mov di, bg_pattern
    call gui_parse_pattern
    jnc .done

.fallback:
    call set_style_pattern

.done:
    pop es
    popa
    ret

; ========================================================================
; LOAD_GUI_CONFIGS - Reads the appearance settings SETTINGS.PLE writes
; IN : nothing
; OUT : icon_round and name_gap set, defaults kept when a file is missing
; ========================================================================
load_gui_configs:
    pusha
    call gui_enter_conf
    jc .cache_wp

    mov si, cfg_round_file
    mov di, icon_round
    mov bx, ICON_ROUND_MAX
    call gui_load_one

    mov si, cfg_gap_file
    mov di, name_gap
    mov bx, NAME_GAP_MAX
    call gui_load_one

    call load_wallpaper_cfg

    mov ah, 0x0F
    int 0x22

.cache_wp:
    call rebuild_desktop_cache
    popa
    ret

cfg_conf_dir     db 'CONF.DIR', 0
cfg_gui_dir      db 'GUI.DIR', 0
cfg_wall_dir     db 'WALL.DIR', 0
cfg_round_file   db 'IC_ROUND.CFG', 0
cfg_gap_file     db 'NAME_GAP.CFG', 0
cfg_variant_file db 'VARIANT.CFG', 0
cfg_patern_file  db 'PATERN.CFG', 0
cfg_image_file   db 'IMAGE.CFG', 0

icon_round     dw 2
name_gap       dw 6

cfg_buf        times 512 db 0