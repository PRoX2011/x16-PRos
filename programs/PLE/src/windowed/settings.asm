; ==================================================================
; x16-PRos -- SETTINGS. GUI appearance settings.
; Copyright (C) 2026 PRoX2011
;
; Made by PRoX-dev
; ==================================================================

%include "ple.inc"

PLE_HEADER start, "GUI Settings", "PRoX-dev"
PLE_LOGO          "logo/settings.raw"

MARGIN     equ 8
ROW_H      equ 44
SLIDER_H   equ 14
SLIDER_W   equ 160
LABEL_Y    equ 4
BTN_W      equ 72
BTN_H      equ 18
RST_W      equ 96
HINT_H     equ 18

MAX_TASKS  equ 8

ROUND_MIN  equ 0
ROUND_MAX  equ 8
GAP_MIN    equ 0
GAP_MAX    equ 8

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    call surf_sync
    cmp byte [surf_windowed], 1
    je .ready
    mov ah, 0x06
    int 0x21
    mov ah, 0x24
    mov al, 1
    int 0x23
    mov ah, 0x23
    int 0x23
.ready:
    mov byte [drag_row], 0xFF
    mov byte [saved], 0
    mov word [last_ox], 0xFFFF
    mov word [last_w], 0xFFFF
    mov word [last_h], 0xFFFF

    call load_round_cfg
    call load_gap_cfg

.loop:
    call surf_sync
    cmp byte [surf_close], 0
    jne .exit
    call compute_layout
    call surf_input

    cmp byte [surf_dirty], 0
    jne .full
    mov ax, [surf_ox]
    cmp ax, [last_ox]
    jne .full
    mov ax, [surf_w]
    cmp ax, [last_w]
    jne .full
    mov ax, [surf_h]
    cmp ax, [last_h]
    jne .full
    jmp .input
.full:
    mov byte [surf_dirty], 0
    mov ax, [surf_ox]
    mov [last_ox], ax
    mov ax, [surf_w]
    mov [last_w], ax
    mov ax, [surf_h]
    mov [last_h], ax
    call draw_all

.input:
    cmp byte [drag_row], 0xFF
    jne .in_drag

    cmp byte [surf_mpress], 0
    je .pace

    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    call surf_in_rect
    jc .grab_round

    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    call surf_in_rect
    jc .grab_gap

    mov cx, [btn_x]
    mov dx, [btn_y]
    mov si, BTN_W
    mov di, BTN_H
    call surf_in_rect
    jc .do_save

    mov cx, [rst_x]
    mov dx, [rst_y]
    mov si, RST_W
    mov di, BTN_H
    call surf_in_rect
    jc .do_restart
    jmp .pace

.grab_round:
    mov byte [drag_row], 0
    call track_slider
    jmp .pace
.grab_gap:
    mov byte [drag_row], 1
    call track_slider
    jmp .pace
.do_save:
    call save_round_cfg
    call save_gap_cfg
    mov byte [saved], 1
    call draw_all
    jmp .pace
.do_restart:
    call restart_gui
    jmp .pace

.in_drag:
    cmp byte [surf_mb], 0
    je .release
    call track_slider
    jmp .pace
.release:
    mov byte [drag_row], 0xFF
    jmp .pace

.pace:
    cmp byte [surf_windowed], 1
    je .wpace
    mov ah, 0x01
    int 0x16
    jz .sdelay
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .exit
.sdelay:
    mov ah, 0x86
    mov cx, 0
    mov dx, 20000
    int 0x15
    jmp .loop
.wpace:
    mov ah, 0x14
    mov cx, 1
    int 0x23
    jmp .loop

.exit:
    cmp byte [surf_windowed], 1
    je .wexit
    mov ah, 0x0C
    int 0x21
    retf
.wexit:
    mov ah, 0x12
    int 0x23
    jmp .wexit

; ========================================================================
; compute_layout - place the two sliders and the save button
; IN:  nothing
; OUT: round_x/round_y, gap_x/gap_y, btn_x/btn_y filled
; ========================================================================
compute_layout:
    pusha
    mov word [round_x], MARGIN
    mov word [round_y], MARGIN + 18
    mov word [gap_x], MARGIN
    mov word [gap_y], MARGIN + 18 + ROW_H
    mov word [btn_x], MARGIN
    mov word [rst_x], MARGIN + BTN_W + 8
    mov ax, [surf_h]
    sub ax, MARGIN
    sub ax, BTN_H
    mov [btn_y], ax
    mov [rst_y], ax
    sub ax, HINT_H
    mov [hint_y], ax
    popa
    ret

; ========================================================================
; track_slider - move the dragged slider to the cursor
; IN:  [drag_row] = 0 for the corner slider, 1 for the gap slider
; OUT: the matching value updated, the row redrawn
; ========================================================================
track_slider:
    pusha
    cmp byte [drag_row], 0
    jne .gap

    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov bx, ROUND_MIN
    mov bp, ROUND_MAX
    call surf_slider_val
    jnc .done
    cmp ax, [cfg_round]
    je .done
    mov [cfg_round], ax
    mov byte [saved], 0
    call draw_all
    jmp .done

.gap:
    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov bx, GAP_MIN
    mov bp, GAP_MAX
    call surf_slider_val
    jnc .done
    cmp ax, [cfg_gap]
    je .done
    mov [cfg_gap], ax
    mov byte [saved], 0
    call draw_all
.done:
    popa
    ret

; ========================================================================
; draw_all - repaint the whole surface
; IN:  nothing
; OUT: nothing
; ========================================================================
draw_all:
    pusha
    mov ah, 0x22
    int 0x23

    mov al, 7
    call surf_clear

    mov si, str_round
    mov cx, MARGIN
    mov dx, MARGIN
    xor al, al
    call surf_print

    mov cx, [round_x]
    mov dx, [round_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov ax, [cfg_round]
    mov bx, ROUND_MIN
    mov bp, ROUND_MAX
    call surf_slider

    mov ax, [cfg_round]
    call num_to_str
    mov si, num_buf
    mov cx, [round_x]
    add cx, SLIDER_W + 8
    mov dx, [round_y]
    xor al, al
    call surf_print

    mov si, str_gap
    mov cx, MARGIN
    mov dx, MARGIN + ROW_H
    xor al, al
    call surf_print

    mov cx, [gap_x]
    mov dx, [gap_y]
    mov si, SLIDER_W
    mov di, SLIDER_H
    mov ax, [cfg_gap]
    mov bx, GAP_MIN
    mov bp, GAP_MAX
    call surf_slider

    mov ax, [cfg_gap]
    call num_to_str
    mov si, num_buf
    mov cx, [gap_x]
    add cx, SLIDER_W + 8
    mov dx, [gap_y]
    xor al, al
    call surf_print

    cmp byte [saved], 0
    je .hint_done
    mov si, str_done
    mov cx, MARGIN
    mov dx, [hint_y]
    mov al, 0x02
    call surf_print
.hint_done:

    mov cx, [btn_x]
    mov dx, [btn_y]
    mov si, BTN_W
    mov di, BTN_H
    mov bx, str_save
    xor al, al
    call surf_button

    mov cx, [rst_x]
    mov dx, [rst_y]
    mov si, RST_W
    mov di, BTN_H
    mov bx, str_restart
    xor al, al
    call surf_button

    mov ah, 0x23
    int 0x23
    popa
    ret

; ========================================================================
; num_to_str - render AX into num_buf without leading zeroes
; IN:  AX = value (0..999)
; OUT: num_buf holds the digits, null terminated
; ========================================================================
num_to_str:
    pusha
    mov di, num_buf
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
    pop dx
    add dl, '0'
    mov [di], dl
    inc di
    loop .emit
    mov byte [di], 0
    popa
    ret

; ========================================================================
; find_gui_task - task id of the running window manager
; IN:  nothing
; OUT: AL = task id, CF = 1 when no task is called GUI.PLE
; ========================================================================
find_gui_task:
    push bx
    push cx
    push si
    push di
    mov bl, 1
.probe:
    cmp bl, MAX_TASKS
    jae .none

    push bx
    mov ah, 0x17
    int 0x23
    pop bx
    jc .next
    test al, al
    jz .next

    push bx
    mov di, task_name_buf
    mov ah, 0x19
    int 0x23
    pop bx
    jc .next

    mov si, gui_file
    mov di, task_name_buf
.cmp:
    mov al, [si]
    cmp al, [di]
    jne .next
    test al, al
    jz .hit
    inc si
    inc di
    jmp .cmp
.next:
    inc bl
    jmp .probe
.hit:
    mov al, bl
    pop di
    pop si
    pop cx
    pop bx
    clc
    ret
.none:
    pop di
    pop si
    pop cx
    pop bx
    stc
    ret

; ========================================================================
; restart_gui - kill the window manager, start it again and quit
; IN:  nothing
; OUT: does not return once the new WM is up
; ========================================================================
restart_gui:
    pusha
    call find_gui_task
    jc .done
    mov bl, al

    mov ah, 0x17
    int 0x23
    mov [.parent], dl

    mov ah, 0x18
    int 0x23

    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot
    mov ah, 0x09
    mov si, ple_dir_name
    int 0x22
    jc .restore

    mov ah, 0x11
    mov si, gui_file
    int 0x23
    jc .restore

    mov bl, al
    mov bh, [.parent]
    cmp bh, 0xFF
    je .restore
    mov ah, 0x34
    int 0x23
.restore:
    mov ah, 0x0F
    int 0x22

    mov ah, 0x12
    int 0x23
.done:
    popa
    ret
.parent db 0xFF

; ========================================================================
; enter_gui_conf - move into A:/CONF.DIR/GUI.DIR, creating it if needed
; IN:  nothing
; OUT: CF = 1 if the directory could not be entered
; ========================================================================
enter_gui_conf:
    mov ah, 0x0E
    int 0x22
.toroot:
    mov ah, 0x0A
    int 0x22
    jnc .toroot

    mov ah, 0x09
    mov si, conf_dir_name
    int 0x22
    jc .fail

    mov ah, 0x09
    mov si, gui_dir_name
    int 0x22
    jnc .ok

    mov ah, 0x0B
    mov si, gui_dir_name
    int 0x22
    jc .fail
    mov ah, 0x09
    mov si, gui_dir_name
    int 0x22
    jc .fail
.ok:
    clc
    ret
.fail:
    mov ah, 0x0F
    int 0x22
    stc
    ret

; ========================================================================
; leave_gui_conf - restore the directory saved by enter_gui_conf
; IN:  nothing
; OUT: nothing
; ========================================================================
leave_gui_conf:
    mov ah, 0x0F
    int 0x22
    ret

; ========================================================================
; parse_cfg_num - read a decimal number out of cfg_buf
; IN:  BX = byte count in cfg_buf
; OUT: AX = value, CF = 1 if no digit was found
; ========================================================================
parse_cfg_num:
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
; write_cfg_num - store AX as decimal text in the named file
; IN:  AX = value, SI = file name
; OUT: nothing
; ========================================================================
write_cfg_num:
    pusha
    mov [.name], si
    call num_to_str

    mov si, num_buf
    mov di, cfg_buf
    xor cx, cx
.copy:
    mov al, [si]
    test al, al
    jz .copied
    mov [di], al
    inc si
    inc di
    inc cx
    jmp .copy
.copied:
    mov [.len], cx

    mov ah, 0x06
    mov si, [.name]
    int 0x22

    mov ah, 0x03
    mov si, [.name]
    mov bx, cfg_buf
    mov cx, [.len]
    int 0x22
    popa
    ret
.name dw 0
.len  dw 0

; ========================================================================
; load_round_cfg - read IC_ROUND.CFG into cfg_round
; IN:  nothing
; OUT: cfg_round set, left at its default when the file is missing
; ========================================================================
load_round_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov ah, 0x02
    mov si, round_cfg_file
    mov cx, cfg_buf
    int 0x22
    jc .leave

    call parse_cfg_num
    jc .leave
    cmp ax, ROUND_MAX
    ja .leave
    mov [cfg_round], ax
.leave:
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; load_gap_cfg - read NAME_GAP.CFG into cfg_gap
; IN:  nothing
; OUT: cfg_gap set, left at its default when the file is missing
; ========================================================================
load_gap_cfg:
    pusha
    call enter_gui_conf
    jc .done

    mov ah, 0x02
    mov si, gap_cfg_file
    mov cx, cfg_buf
    int 0x22
    jc .leave

    call parse_cfg_num
    jc .leave
    cmp ax, GAP_MAX
    ja .leave
    mov [cfg_gap], ax
.leave:
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; save_round_cfg - write cfg_round to IC_ROUND.CFG
; IN:  nothing
; OUT: nothing
; ========================================================================
save_round_cfg:
    pusha
    call enter_gui_conf
    jc .done
    mov ax, [cfg_round]
    mov si, round_cfg_file
    call write_cfg_num
    call leave_gui_conf
.done:
    popa
    ret

; ========================================================================
; save_gap_cfg - write cfg_gap to NAME_GAP.CFG
; IN:  nothing
; OUT: nothing
; ========================================================================
save_gap_cfg:
    pusha
    call enter_gui_conf
    jc .done
    mov ax, [cfg_gap]
    mov si, gap_cfg_file
    call write_cfg_num
    call leave_gui_conf
.done:
    popa
    ret

conf_dir_name   db 'CONF.DIR', 0
gui_dir_name    db 'GUI.DIR', 0
round_cfg_file  db 'IC_ROUND.CFG', 0
gap_cfg_file    db 'NAME_GAP.CFG', 0

str_round       db 'Icon corner rounding', 0
str_gap         db 'Icon to label gap', 0
str_save        db 'Save', 0
str_restart     db 'Restart GUI', 0
str_done        db 'Saved successfully.', 0
gui_file        db 'GUI.PLE', 0
ple_dir_name    db 'PLE.DIR', 0
task_name_buf   times 16 db 0

cfg_round       dw 2
cfg_gap         dw 6

round_x         dw 0
round_y         dw 0
gap_x           dw 0
gap_y           dw 0
btn_x           dw 0
btn_y           dw 0
rst_x           dw 0
rst_y           dw 0
hint_y          dw 0

drag_row        db 0xFF
saved           db 0

last_ox         dw 0xFFFF
last_w          dw 0xFFFF
last_h          dw 0xFFFF

num_buf         times 8 db 0
cfg_buf         times 512 db 0

%include "grafx.inc"
%include "surf.inc"

PLE_END
