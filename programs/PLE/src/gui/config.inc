; ========================================================================
; GUI_ENTER_CONF - Moves into A:/CONF.DIR/GUI.DIR
; IN : nothing
; OUT : CF = 1 if the directory is not there
; ========================================================================
gui_enter_conf:
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot

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
; APPLY_WALLPAPER - Copy the built-in bg_style names into bg_pattern and
; keep it on config
; ========================================================================
apply_wallpaper:
    pusha
    push es

    push ds
    pop es
    cld

    mov al, [bg_style]
    xor ah, ah
    shl ax, 3
    mov si, bg_patterns
    add si, ax
    mov di, bg_pattern
    mov cx, 8
    rep movsb

    call save_wallpaper_cfg

    pop es
    popa
    ret

; ========================================================================
; SAVE_WALLPAPER_CFG - store bg_pattern as eight decimal numbers
; ========================================================================
save_wallpaper_cfg:
    pusha
    push es

    call gui_enter_conf
    jc .done

    push ds
    pop es
    cld
    mov si, bg_pattern
    mov di, cfg_buf
    mov cx, 8
.row:
    lodsb
    call gui_num_to_text
    mov al, 10
    stosb
    loop .row

    mov ax, di
    sub ax, cfg_buf
    mov [.len], ax

    mov ah, 0x06
    mov si, cfg_wall_file
    int 0x22

    mov ah, 0x03
    mov si, cfg_wall_file
    mov bx, cfg_buf
    mov cx, [.len]
    int 0x22

    mov ah, 0x0F
    int 0x22

.done:
    pop es
    popa
    ret
.len dw 0

; ========================================================================
; LOAD_WALLPAPER_CFG - Read the pattern back
; ========================================================================
load_wallpaper_cfg:
    pusha
    push es

    push ds
    pop es
    cld

    mov ah, 0x02
    mov si, cfg_wall_file
    mov cx, cfg_buf
    int 0x22
    jc .fallback

    mov di, bg_pattern
    call gui_parse_pattern
    jnc .done

.fallback:
    mov al, [bg_style]
    xor ah, ah
    shl ax, 3
    mov si, bg_patterns
    add si, ax
    mov di, bg_pattern
    mov cx, 8
    rep movsb

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
    jc .done

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
.done:
    popa
    ret

cfg_conf_dir   db 'CONF.DIR', 0
cfg_gui_dir    db 'GUI.DIR', 0
cfg_round_file db 'IC_ROUND.CFG', 0
cfg_gap_file   db 'NAME_GAP.CFG', 0
cfg_wall_file  db 'WALLPAP.CFG', 0

icon_round     dw 2
name_gap       dw 6

cfg_buf        times 512 db 0