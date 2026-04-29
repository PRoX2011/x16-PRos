INSTALL_MAX_DRIVES   equ 4
INSTALL_ENTRY_BYTES  equ 16

INST_BOX_X           equ 1
INST_BOX_Y           equ 2
INST_BOX_W           equ 30
INST_BOX_H           equ 26
INST_LIST_X          equ INST_BOX_X + 2
INST_LIST_Y          equ INST_BOX_Y + 3

INST_INFO_X          equ 32
INST_INFO_Y          equ 2
INST_INFO_W          equ 47
INST_INFO_H          equ 26
INST_INFO_INNER_X    equ INST_INFO_X + 2
INST_INFO_INNER_Y    equ INST_INFO_Y + 3

INST_IC_X            equ INST_INFO_X + 4
INST_IC_Y            equ INST_INFO_Y + 4
INST_IC_W            equ 14
INST_IC_H            equ 8

INST_ATTR_NORMAL     equ 0x1F
INST_ATTR_HIGHLIGHT  equ 0x70
INST_ATTR_BORDER     equ 0x1F
INST_ATTR_DIM        equ 0x17
INST_ATTR_TITLE_BAR  equ 0x1F
INST_ATTR_HINT_BAR   equ 0x1F
INST_ATTR_BG         equ 0x01
INST_ATTR_OK         equ 0x1A
INST_ATTR_ERR        equ 0x1C
INST_ATTR_BUSY       equ 0x1E

%include "programs/lib/font.inc"
%include "programs/lib/tui.inc"

install_run:
    pusha
    push es

    call install_probe_drives
    cmp byte [install_count], 0
    je .leave_text

    mov ah, 0x14
    int 0x22
    mov [install_current_letter], al
    call install_init_index

    mov ax, 0x0012
    int 0x10
    push cs
    pop ds
    push cs
    pop es
    cld
    call tui_init

    call install_draw_screen

.loop:
    call tui_wait_for_key
    cmp al, 27
    je .leave_gfx
    cmp al, 13
    je .pick
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    jmp .loop

.up:
    cmp byte [install_index], 0
    je .loop
    dec byte [install_index]
    call install_draw_list
    call install_draw_info
    jmp .loop

.down:
    mov al, [install_index]
    inc al
    cmp al, [install_count]
    jae .loop
    mov [install_index], al
    call install_draw_list
    call install_draw_info
    jmp .loop

.pick:
    movzx bx, byte [install_index]
    shl bx, 4
    add bx, install_table
    mov al, [bx]
    mov [install_chosen_letter], al

    cmp al, [install_current_letter]
    je .switch_only

    call install_status_busy
    call install_clone_disk
    jc .err

.switch_only:
    mov al, [install_chosen_letter]
    mov [install_letter_buf], al
    mov byte [install_letter_buf+1], 0
    mov ah, 0x12
    mov si, install_letter_buf
    int 0x22

    call install_status_done
    call tui_wait_for_key
    jmp .leave_gfx

.err:
    call install_status_err
    call tui_wait_for_key

.leave_gfx:
    mov ax, 0x0003
    int 0x10
.leave_text:
    pop es
    popa
    ret

install_init_index:
    push ax
    push bx
    push cx
    mov al, [install_current_letter]
    mov bx, install_table
    xor cx, cx
.scan:
    cmp cl, [install_count]
    jae .pick_zero
    cmp [bx], al
    je .got
    add bx, INSTALL_ENTRY_BYTES
    inc cl
    jmp .scan
.pick_zero:
    xor cl, cl
.got:
    mov [install_index], cl
    pop cx
    pop bx
    pop ax
    ret

install_probe_drives:
    pusha
    mov byte [install_count], 0
    mov dl, 0x00
    call install_probe_one
    mov dl, 0x01
    call install_probe_one
    mov dl, 0x80
    call install_probe_one
    mov dl, 0x81
    call install_probe_one
    popa
    ret

install_probe_one:
    pusha
    push es

    mov [.in_dl], dl
    xor ax, ax
    mov es, ax
    xor di, di
    mov ah, 0x08
    int 0x13
    mov [.bios_ah], ah
    mov [.bios_cf], 0
    jnc .no_cf
    mov byte [.bios_cf], 1
.no_cf:
    mov [.r_ch], ch
    mov [.r_cl], cl
    mov [.r_dh], dh

    pop es
    cmp byte [.bios_cf], 0
    jne .leave
    cmp byte [.bios_ah], 0
    jne .leave

    mov al, [install_count]
    cmp al, INSTALL_MAX_DRIVES
    jae .leave

    movzx bx, al
    shl bx, 4
    add bx, install_table

    mov dl, [.in_dl]
    cmp dl, 0x80
    jae .hdd_letter
    mov al, 'A'
    add al, dl
    jmp .set_letter
.hdd_letter:
    mov al, dl
    sub al, 0x80
    add al, 'C'
.set_letter:
    mov [bx+0], al
    mov dl, [.in_dl]
    mov [bx+1], dl

    mov al, 1
    cmp dl, 0x80
    jb .set_type
    mov al, 2
.set_type:
    mov [bx+2], al
    mov byte [bx+3], 0

    mov al, [.r_ch]
    mov ah, [.r_cl]
    shr ah, 6
    inc ax
    mov [bx+4], ax

    mov al, [.r_dh]
    inc al
    mov [bx+6], al

    mov al, [.r_cl]
    and al, 0x3F
    mov [bx+7], al

    push dx
    movzx ax, byte [bx+6]
    movzx dx, byte [bx+7]
    mul dx
    mov dx, [bx+4]
    mul dx
    test dx, dx
    jz .keep
    mov ax, 0xFFFF
.keep:
    mov [bx+8], ax
    pop dx

    inc byte [install_count]
.leave:
    popa
    ret
.in_dl   db 0
.bios_ah db 0
.bios_cf db 0
.r_ch    db 0
.r_cl    db 0
.r_dh    db 0


; ==================================================================
; Drawing routines
; ==================================================================
install_draw_screen:
    call install_draw_bg
    call install_draw_box
    call install_draw_list
    call install_draw_info_box
    call install_draw_info
    ret

install_draw_bg:
    pusha

    mov al, INST_ATTR_BG
    call font_clear_screen

    mov si, setup_welcome_msg
    mov ch, 0
    call install_render_bar

    mov si, setup_bottom_msg
    mov ch, 29
    call install_render_bar

    mov si, install_hint_str
    mov cl, 1
    mov ch, 28
    mov bl, INST_ATTR_HINT_BAR
    call font_print_string

    popa
    ret

install_render_bar:
    pusha
    xor cl, cl
    mov bl, INST_ATTR_TITLE_BAR
.loop:
    lodsb
    call font_put_char
    inc cl
    cmp cl, 80
    jb .loop
    popa
    ret

install_draw_box:
    pusha
    mov cl, INST_BOX_X
    mov ch, INST_BOX_Y
    mov dl, INST_BOX_W
    mov dh, INST_BOX_H
    mov bl, INST_ATTR_BORDER
    call tui_draw_box

    mov si, install_box_title
    mov cl, INST_BOX_X + 2
    mov ch, INST_BOX_Y + 1
    mov bl, INST_ATTR_DIM
    call font_print_string
    popa
    ret

install_draw_info_box:
    pusha
    mov cl, INST_INFO_X
    mov ch, INST_INFO_Y
    mov dl, INST_INFO_W
    mov dh, INST_INFO_H
    mov bl, INST_ATTR_BORDER
    call tui_draw_box

    mov si, install_info_title
    mov cl, INST_INFO_X + 2
    mov ch, INST_INFO_Y + 1
    mov bl, INST_ATTR_DIM
    call font_print_string
    popa
    ret


install_draw_list:
    pusha

    mov al, INST_ATTR_NORMAL >> 4
    mov cl, INST_LIST_X - 1
    mov ch, INST_LIST_Y
    mov dl, INST_BOX_W - 4
    mov dh, INSTALL_MAX_DRIVES + 1
    call font_fill_rect

    mov byte [.idx], 0
.row_loop:
    mov al, [.idx]
    cmp al, [install_count]
    jae .done

    mov al, [.idx]
    add al, INST_LIST_Y
    mov [.row_y], al

    movzx bx, byte [.idx]
    shl bx, 4
    add bx, install_table
    mov [.entry], bx

    mov al, [.idx]
    cmp al, [install_index]
    jne .normal

    mov al, INST_ATTR_HIGHLIGHT >> 4
    mov cl, INST_LIST_X - 1
    mov ch, [.row_y]
    mov dl, INST_BOX_W - 4
    mov dh, 1
    call font_fill_rect

    mov al, 0x10
    mov cl, INST_LIST_X
    mov ch, [.row_y]
    mov bl, INST_ATTR_HIGHLIGHT
    call font_put_char

    mov byte [.attr], INST_ATTR_HIGHLIGHT
    jmp .draw_text

.normal:
    mov byte [.attr], INST_ATTR_NORMAL

.draw_text:
    mov al, '['
    mov cl, INST_LIST_X + 2
    mov ch, [.row_y]
    mov bl, [.attr]
    call font_put_char

    mov bx, [.entry]
    mov al, [bx]
    mov cl, INST_LIST_X + 3
    mov ch, [.row_y]
    mov bl, [.attr]
    call font_put_char

    mov al, ']'
    mov cl, INST_LIST_X + 4
    mov ch, [.row_y]
    mov bl, [.attr]
    call font_put_char

    mov bx, [.entry]
    cmp byte [bx+2], 1
    jne .lbl_hdd
    mov si, install_lbl_floppy
    jmp .lbl_print
.lbl_hdd:
    mov si, install_lbl_hdd
.lbl_print:
    mov cl, INST_LIST_X + 6
    mov ch, [.row_y]
    mov bl, [.attr]
    call font_print_string

    mov bx, [.entry]
    mov al, [bx]
    cmp al, [install_current_letter]
    jne .next
    mov si, install_lbl_cur
    mov cl, INST_LIST_X + 14
    mov ch, [.row_y]
    mov bl, [.attr]
    call font_print_string

.next:
    inc byte [.idx]
    jmp .row_loop
.done:
    popa
    ret
.idx   db 0
.row_y db 0
.entry dw 0
.attr  db 0


install_draw_info:
    pusha

    mov al, INST_ATTR_NORMAL >> 4
    mov cl, INST_INFO_X + 1
    mov ch, INST_INFO_Y + 2
    mov dl, INST_INFO_W - 2
    mov dh, INST_INFO_H - 3
    call font_fill_rect

    movzx bx, byte [install_index]
    shl bx, 4
    add bx, install_table
    mov [.entry], bx

    cmp byte [bx+2], 2
    jne .floppy_colors
    mov byte [.accent], 0x01
    mov byte [.bar_attr], 0x71
    jmp .draw_icon
.floppy_colors:
    mov byte [.accent], 0x02
    mov byte [.bar_attr], 0x72

.draw_icon:
    mov al, 0x08
    mov cl, INST_IC_X + 1
    mov ch, INST_IC_Y + 1
    mov dl, INST_IC_W
    mov dh, INST_IC_H
    call font_fill_rect

    mov al, 0x0F
    mov cl, INST_IC_X
    mov ch, INST_IC_Y
    mov dl, INST_IC_W
    mov dh, INST_IC_H
    call font_fill_rect

    mov al, [.bar_attr]
    shr al, 4
    mov cl, INST_IC_X + 2
    mov ch, INST_IC_Y + 1
    mov dl, INST_IC_W - 4
    mov dh, 2
    call font_fill_rect

    mov al, [.accent]
    mov cl, INST_IC_X
    mov ch, INST_IC_Y + INST_IC_H - 1
    mov dl, INST_IC_W
    mov dh, 1
    call font_fill_rect

    mov al, 0x07
    mov cl, INST_IC_X + 3
    mov ch, INST_IC_Y + 4
    mov dl, INST_IC_W - 6
    mov dh, 3
    call font_fill_rect

    mov bx, [.entry]
    mov al, [bx]
    mov cl, INST_IC_X + 5
    mov ch, INST_IC_Y + 5
    mov bl, 0x70
    call font_put_char
    mov al, ':'
    mov cl, INST_IC_X + 6
    mov ch, INST_IC_Y + 5
    mov bl, 0x70
    call font_put_char

    mov bx, [.entry]
    cmp byte [bx+2], 2
    jne .brand_floppy
    mov si, install_lbl_brand
    mov bl, 0x1F
    jmp .brand_print
.brand_floppy:
    mov si, install_lbl_brand
    mov bl, 0x2F
.brand_print:
    mov cl, INST_IC_X + 3
    mov ch, INST_IC_Y + INST_IC_H - 1
    call font_print_string

    mov bx, [.entry]
    mov byte [.line], INST_INFO_INNER_Y
    add byte [.line], INST_IC_H + 2

    mov si, install_lbl_drive
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    mov bl, INST_ATTR_DIM
    call font_print_string
    mov bx, [.entry]
    mov al, [bx]
    mov cl, INST_INFO_INNER_X + 8
    mov ch, [.line]
    mov bl, INST_ATTR_NORMAL
    call font_put_char
    inc byte [.line]

    mov si, install_lbl_type
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    mov bl, INST_ATTR_DIM
    call font_print_string
    mov bx, [.entry]
    cmp byte [bx+2], 1
    jne .t_hdd
    mov si, install_lbl_floppy
    jmp .t_print
.t_hdd:
    mov si, install_lbl_hdd
.t_print:
    mov cl, INST_INFO_INNER_X + 8
    mov ch, [.line]
    mov bl, INST_ATTR_NORMAL
    call font_print_string
    inc byte [.line]

    mov si, install_lbl_bios
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    mov bl, INST_ATTR_DIM
    call font_print_string
    mov bx, [.entry]
    mov al, [bx+1]
    mov cl, INST_INFO_INNER_X + 8
    mov ch, [.line]
    mov bl, INST_ATTR_NORMAL
    call install_print_hex
    inc byte [.line]

    mov si, install_lbl_chs
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    mov bl, INST_ATTR_DIM
    call font_print_string
    mov bx, [.entry]
    mov ax, [bx+4]
    mov cl, INST_INFO_INNER_X + 8
    mov ch, [.line]
    mov bl, INST_ATTR_NORMAL
    call install_print_dec
    mov al, '/'
    mov bl, INST_ATTR_DIM
    call font_put_char
    inc cl
    mov bx, [.entry]
    movzx ax, byte [bx+6]
    mov bl, INST_ATTR_NORMAL
    call install_print_dec
    mov al, '/'
    mov bl, INST_ATTR_DIM
    call font_put_char
    inc cl
    mov bx, [.entry]
    movzx ax, byte [bx+7]
    mov bl, INST_ATTR_NORMAL
    call install_print_dec
    inc byte [.line]

    mov si, install_lbl_size
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    mov bl, INST_ATTR_DIM
    call font_print_string
    mov bx, [.entry]
    mov ax, [bx+8]
    shr ax, 1
    mov cl, INST_INFO_INNER_X + 8
    mov ch, [.line]
    mov bl, INST_ATTR_NORMAL
    call install_print_dec
    mov al, ' '
    mov bl, INST_ATTR_NORMAL
    call font_put_char
    inc cl
    mov si, install_lbl_kb
    mov bl, INST_ATTR_DIM
    call font_print_string

    add byte [.line], 2

    mov bx, [.entry]
    mov al, [bx]
    cmp al, [install_current_letter]
    jne .target_msg
    mov si, install_msg_source
    mov bl, INST_ATTR_OK
    jmp .footer_print
.target_msg:
    mov si, install_msg_target
    mov bl, INST_ATTR_BUSY
.footer_print:
    mov cl, INST_INFO_INNER_X
    mov ch, [.line]
    call font_print_string

    popa
    ret
.entry    dw 0
.accent   db 0
.bar_attr db 0
.line     db 0

install_status_busy:
    pusha
    mov si, install_msg_busy
    mov bl, INST_ATTR_BUSY
    call install_status_paint
    popa
    ret

install_status_done:
    pusha
    mov si, install_msg_done
    mov bl, INST_ATTR_OK
    call install_status_paint
    popa
    ret

install_status_err:
    pusha
    mov si, install_msg_err
    mov bl, INST_ATTR_ERR
    call install_status_paint
    popa
    ret

install_status_paint:
    push si
    push bx

    mov al, INST_ATTR_NORMAL >> 4
    mov cl, INST_INFO_X + 1
    mov ch, INST_INFO_Y + INST_INFO_H - 2
    mov dl, INST_INFO_W - 2
    mov dh, 1
    call font_fill_rect

    pop bx
    pop si
    push si
    mov cl, INST_INFO_X + 2
    mov ch, INST_INFO_Y + INST_INFO_H - 2
    call font_print_string
    pop si
    ret


install_draw_progress:
    pusha
    ; Clear progress row
    mov al, INST_ATTR_NORMAL >> 4
    mov cl, INST_INFO_X + 1
    mov ch, INST_INFO_Y + INST_INFO_H - 4
    mov dl, INST_INFO_W - 2
    mov dh, 1
    call font_fill_rect

    mov si, install_lbl_prog
    mov cl, INST_INFO_X + 2
    mov ch, INST_INFO_Y + INST_INFO_H - 4
    mov bl, INST_ATTR_DIM
    call font_print_string

    mov ax, [install_lba]
    mov cl, INST_INFO_X + 12
    mov ch, INST_INFO_Y + INST_INFO_H - 4
    mov bl, INST_ATTR_NORMAL
    call install_print_dec

    mov al, '/'
    mov bl, INST_ATTR_DIM
    call font_put_char
    inc cl
    mov ax, [install_total]
    mov bl, INST_ATTR_NORMAL
    call install_print_dec
    popa
    ret

; ==================================================================
; Sector-by-sector clone
; ==================================================================
install_clone_disk:
    pusha
    push es
    push ds
    pop es

    mov al, [install_current_letter]
    mov bx, install_table
    xor cx, cx
.find_src:
    cmp cl, [install_count]
    jae .src_default
    cmp [bx], al
    je .src_found
    add bx, INSTALL_ENTRY_BYTES
    inc cl
    jmp .find_src
.src_default:
    mov bx, install_table
.src_found:
    mov al, [bx+1]
    mov [install_source_bios], al
    movzx ax, byte [bx+6]
    mov [install_src_heads], ax
    movzx ax, byte [bx+7]
    mov [install_src_spt], ax
    mov ax, [bx+8]
    mov [install_total], ax

    movzx bx, byte [install_index]
    shl bx, 4
    add bx, install_table
    mov al, [bx+1]
    mov [install_target_bios], al
    movzx ax, byte [bx+6]
    mov [install_tgt_heads], ax
    movzx ax, byte [bx+7]
    mov [install_tgt_spt], ax
    mov ax, [bx+8]
    cmp ax, [install_total]
    jae .have_total
    mov [install_total], ax
.have_total:
    mov word [install_lba], 0
    call install_draw_progress

.copy:
    mov ax, [install_lba]
    cmp ax, [install_total]
    jae .ok

    mov ax, [install_src_heads]
    mov [install_chs_heads], ax
    mov ax, [install_src_spt]
    mov [install_chs_spt], ax
    mov ax, [install_lba]
    call install_lba_to_chs

    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_source_bios]
    mov bx, install_sector_buf
    mov ax, 0x0201
    mov si, 3
.try_read:
    int 0x13
    jnc .read_ok
    dec si
    jz .fail
    xor ah, ah
    int 0x13
    push si
    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_source_bios]
    mov bx, install_sector_buf
    mov ax, 0x0201
    pop si
    jmp .try_read
.read_ok:
    mov ax, [install_tgt_heads]
    mov [install_chs_heads], ax
    mov ax, [install_tgt_spt]
    mov [install_chs_spt], ax
    mov ax, [install_lba]
    call install_lba_to_chs

    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_target_bios]
    mov bx, install_sector_buf
    mov ax, 0x0301
    mov si, 3
.try_write:
    int 0x13
    jnc .write_ok
    dec si
    jz .fail
    xor ah, ah
    int 0x13
    push si
    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_target_bios]
    mov bx, install_sector_buf
    mov ax, 0x0301
    pop si
    jmp .try_write
.write_ok:

    inc word [install_lba]

    mov ax, [install_lba]
    test ax, 0x001F
    jnz .copy
    call install_draw_progress
    jmp .copy

.ok:
    call install_draw_progress

    ; If target is HDD, patch BPB on its sector 0 so the kernel can
    ; mount the FAT12 image with the right CHS geometry & drive id.
    movzx bx, byte [install_index]
    shl bx, 4
    add bx, install_table
    cmp byte [bx+2], 2
    jne .skip_patch
    call install_patch_target_bpb

.skip_patch:
    pop es
    popa
    clc
    ret

.fail:
    pop es
    popa
    stc
    ret


; ------------------------------------------------------------------
; install_patch_target_bpb -- read target sector 0, rewrite BPB
; geometry/media/drive# for HDD, write back.
; ------------------------------------------------------------------
install_patch_target_bpb:
    pusha
    push es
    push ds
    pop es

    ; Setup target geometry for LBA->CHS
    mov ax, [install_tgt_heads]
    mov [install_chs_heads], ax
    mov ax, [install_tgt_spt]
    mov [install_chs_spt], ax

    ; Read sector 0 from target
    xor ax, ax
    call install_lba_to_chs
    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_target_bios]
    mov bx, install_sector_buf
    mov ax, 0x0201
    int 0x13
    jc .out

    ; Patch BPB:
    ;   [BS+21] media descriptor = 0xF8 (fixed disk)
    ;   [BS+24] sectors per track
    ;   [BS+26] number of heads
    ;   [BS+36] BIOS drive number
    mov byte [install_sector_buf + 21], 0xF8

    mov ax, [install_tgt_spt]
    mov [install_sector_buf + 24], ax

    mov ax, [install_tgt_heads]
    mov [install_sector_buf + 26], ax

    mov al, [install_target_bios]
    mov [install_sector_buf + 36], al

    ; Write sector 0 back
    xor ax, ax
    call install_lba_to_chs
    mov ax, [install_chs_cyl]
    mov ch, al
    mov ah, ah
    shl ah, 6
    or ah, [install_chs_sec]
    mov cl, ah
    mov dh, [install_chs_head]
    mov dl, [install_target_bios]
    mov bx, install_sector_buf
    mov ax, 0x0301
    int 0x13

.out:
    pop es
    popa
    ret


install_lba_to_chs:
    push ax
    push bx
    push cx
    push dx
    xor dx, dx
    div word [install_chs_spt]
    inc dl
    mov [install_chs_sec], dl
    xor dx, dx
    div word [install_chs_heads]
    mov [install_chs_head], dl
    mov [install_chs_cyl], ax
    pop dx
    pop cx
    pop bx
    pop ax
    ret

install_print_hex:
    push ax
    push bx
    mov [.byte], al
    mov [.attr], bl

    mov al, '0'
    call font_put_char
    inc cl
    mov al, 'x'
    mov bl, [.attr]
    call font_put_char
    inc cl

    mov al, [.byte]
    shr al, 4
    call .nibble
    inc cl
    mov al, [.byte]
    and al, 0x0F
    call .nibble
    inc cl

    pop bx
    pop ax
    ret
.nibble:
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .out
.digit:
    add al, '0'
.out:
    push bx
    mov bl, [.attr]
    call font_put_char
    pop bx
    ret
.byte db 0
.attr db 0

install_print_dec:
    push ax
    push bx
    push dx
    push si
    mov [.attr], bl

    mov si, .buf + 6
    mov byte [si], 0
    mov bx, 10
.div:
    xor dx, dx
    div bx
    add dl, '0'
    dec si
    mov [si], dl
    test ax, ax
    jnz .div

.emit:
    mov al, [si]
    or al, al
    jz .done
    push bx
    mov bl, [.attr]
    call font_put_char
    pop bx
    inc cl
    inc si
    jmp .emit
.done:
    pop si
    pop dx
    pop bx
    pop ax
    ret
.buf  times 7 db 0
.attr db 0


; ==================================================================
; Data section
; ==================================================================

section .data

install_count            db 0
install_index            db 0
install_current_letter   db 'A'
install_chosen_letter    db 'A'
install_source_bios      db 0
install_target_bios      db 0
install_letter_buf       db 0, 0

install_src_heads        dw 2
install_src_spt          dw 18
install_tgt_heads        dw 2
install_tgt_spt          dw 18
install_chs_heads        dw 2
install_chs_spt          dw 18
install_chs_cyl          dw 0
install_chs_head         db 0
install_chs_sec          db 0
install_lba              dw 0
install_total            dw 2880

install_hint_str         db 'Up/Down: Select   Enter: Install   Esc: Skip', 0

install_box_title        db 'Available drives:', 0
install_info_title       db 'Selected drive:', 0

install_lbl_floppy       db 'Floppy', 0
install_lbl_hdd          db 'HDD',    0
install_lbl_cur          db '(current)', 0
install_lbl_brand        db 'x16-PRos', 0

install_lbl_drive        db 'Drive: ', 0
install_lbl_type         db 'Type:  ', 0
install_lbl_bios         db 'BIOS:  ', 0
install_lbl_chs          db 'C/H/S: ', 0
install_lbl_size         db 'Size:  ', 0
install_lbl_kb           db 'KB', 0
install_lbl_prog         db 'Sector: ', 0

install_msg_source       db 'Currently active drive.', 0
install_msg_target       db 'Will be cloned from source.', 0
install_msg_busy         db 'Cloning sectors, please wait...', 0
install_msg_done         db 'Done. Press any key to continue.', 0
install_msg_err          db 'Disk error. Press any key.', 0

install_table            times INSTALL_MAX_DRIVES * INSTALL_ENTRY_BYTES db 0
install_sector_buf       times 512 db 0

; damn, I`m tired