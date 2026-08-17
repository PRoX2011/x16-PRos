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

    mov ah, 0x0F
    int 0x22
.done:
    popa
    ret

cfg_conf_dir   db 'CONF.DIR', 0
cfg_gui_dir    db 'GUI.DIR', 0
cfg_round_file db 'IC_ROUND.CFG', 0
cfg_gap_file   db 'NAME_GAP.CFG', 0

icon_round     dw 2
name_gap       dw 6

cfg_buf        times 512 db 0