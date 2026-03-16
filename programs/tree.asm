; ==================================================================
; x16-PRos -- TREE. Directory tree viewer for x16-PRos
; Copyright (C) 2026 PRoX2011
;
; Usage: tree <directory>
;
; Made by PRoX-dev
; ==================================================================

[BITS 16]
[ORG 0x8000]

ENTRY_SIZE   equ 18
MAX_ENTRIES  equ 28
MAX_DEPTH    equ 6

WBUF         equ 0x9000

SBUFS        equ 0xB000        ; 6 * 512 = 3072 bytes
SBUF_SZ      equ 512

CH_PIPE      equ 0xB3          ; │
CH_TEE       equ 0xC3          ; ├
CH_CORNER    equ 0xC0          ; └
CH_DASH      equ 0xC4          ; ─

start:
    mov ah, 0x0E
    int 0x22

    cmp si, 0
    je .show_dot
    cmp byte [si], 0
    je .show_dot

.skip_sp:
    cmp byte [si], ' '
    jne .copy_arg
    inc si
    jmp .skip_sp

.copy_arg:
    cmp byte [si], 0
    je .show_dot
    mov di, argbuf
.copy_loop:
    lodsb
    cmp al, ' '
    je .copy_done
    cmp al, 0
    je .copy_done
    stosb
    jmp .copy_loop
.copy_done:
    mov byte [di], 0

    cmp byte [argbuf], 0
    je .show_dot

    ; Navigate to specified directory
    mov ah, 0x09
    mov si, argbuf
    int 0x22
    jc .err_nodir

    mov ah, 0x02
    mov si, argbuf
    int 0x21
    jmp .do_tree

.show_dot:
    ; No argument - tree from current directory
    mov ah, 0x02
    mov si, s_dot
    int 0x21

.do_tree:
    mov ah, 0x05
    int 0x21

    mov byte [depth], 0
    mov word [ndirs],  0
    mov word [nfiles], 0
    call tree_recurse

    ; Summary line
    mov ah, 0x05
    int 0x21
    mov ax, [ndirs]
    call print_num
    mov ah, 0x01
    mov si, s_dirs
    int 0x21
    mov ax, [nfiles]
    call print_num
    mov ah, 0x01
    mov si, s_files
    int 0x21
    mov ah, 0x05
    int 0x21

.done:
    mov ah, 0x0F
    int 0x22             ; restore original directory
    ret

.err_nodir:
    mov ah, 0x04
    mov si, s_nodir
    int 0x21
    mov ah, 0x05
    int 0x21
    mov ah, 0x0F
    int 0x22
    ret

tree_recurse:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov al, [depth]
    cmp al, MAX_DEPTH
    jae .tr_done

    ; Get file list
    mov ah, 0x01
    mov si, WBUF
    int 0x22
    jc .tr_done

    mov si, WBUF
    xor cx, cx
.count:
    cmp byte [si], 0
    je .count_done
    cmp cx, MAX_ENTRIES
    jge .count_done
    inc cx
    add si, ENTRY_SIZE
    jmp .count
.count_done:
    cmp cx, 0
    je .tr_done

    xor bh, bh
    mov bl, [depth]
    mov ax, bx
    mov bx, SBUF_SZ
    mul bx
    add ax, SBUFS
    mov bx, ax

    push cx
    mov si, WBUF
    mov di, bx
    mov ax, cx
    mov dx, ENTRY_SIZE
    mul dx
    mov cx, ax
    rep movsb
    mov byte [di], 0
    pop cx

    mov si, bx
    xor dx, dx

.entry_loop:
    cmp byte [si], 0
    je .tr_done

    push si
    push cx
    push dx
    xor bx, bx
.prefix_loop:
    mov cl, [depth]
    xor ch, ch
    cmp bx, cx
    jge .prefix_done
    xor di, di
    mov di, bx
    mov al, [prefix_type + di]
    cmp al, 1
    je .pref_pipe
    ; print "    " (4 spaces)
    mov ah, 0x01
    mov si, s_blank4
    int 0x21
    jmp .pref_next
.pref_pipe:
    ; print "│   "
    mov ah, 0x01
    mov si, s_vbar4
    int 0x21
.pref_next:
    inc bx
    jmp .prefix_loop
.prefix_done:
    pop dx
    pop cx
    pop si

    ; ---- Print connector (├── or └──) ----
    push si
    push cx
    push dx
    mov ax, cx
    dec ax
    cmp dx, ax
    je .corner
    mov ah, 0x01
    mov si, s_tee
    int 0x21
    mov byte [is_last], 0
    jmp .after_conn
.corner:
    mov ah, 0x01
    mov si, s_corner
    int 0x21
    mov byte [is_last], 1
.after_conn:
    pop dx
    pop cx
    pop si

    call fmt_name

    ; ---- Directory or file? ----
    test byte [si + 16], 0x10
    jnz .is_dir

    ; --- File ---
    inc word [nfiles]
    push si
    push cx
    push dx
    mov ah, 0x01
    mov si, namebuf
    int 0x21
    mov ah, 0x05
    int 0x21
    pop dx
    pop cx
    pop si
    jmp .next_entry

.is_dir:
    cmp byte [namebuf], '.'
    je .next_entry

    inc word [ndirs]

    ; Print directory name (green)
    push si
    push cx
    push dx
    mov ah, 0x02
    mov si, namebuf
    int 0x21
    mov ah, 0x05
    int 0x21
    pop dx
    pop cx
    pop si

    mov al, [depth]
    cmp al, MAX_DEPTH - 1
    jge .next_entry

    xor bx, bx
    mov bl, [depth]
    cmp byte [is_last], 1
    je .set_space
    mov byte [prefix_type + bx], 1
    jmp .do_recurse
.set_space:
    mov byte [prefix_type + bx], 0

.do_recurse:
    ; Navigate into subdirectory
    push si
    push cx
    push dx
    mov ah, 0x09
    mov si, namebuf
    int 0x22
    jc .skip_recurse

    inc byte [depth]
    call tree_recurse
    dec byte [depth]

    ; Navigate back to parent
    mov ah, 0x0A
    int 0x22

.skip_recurse:
    pop dx
    pop cx
    pop si

.next_entry:
    add si, ENTRY_SIZE
    inc dx
    jmp .entry_loop

.tr_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fmt_name:
    push ax
    push cx
    push si

    mov di, namebuf

    mov cx, 9
.name_loop:
    lodsb
    dec cx
    cmp al, ' '
    je .name_space
    stosb
    cmp cx, 0
    jg .name_loop
    jmp .do_ext

.name_space:
    add si, cx

.do_ext:
    cmp byte [si], ' '
    je .ext_blank
    mov byte [di], '.'
    inc di
    mov cx, 3
.ext_loop:
    lodsb
    cmp al, ' '
    je .ext_done
    stosb
    loop .ext_loop
.ext_done:
.ext_blank:
    mov byte [di], 0

    pop si
    pop cx
    pop ax
    ret

print_num:
    push ax
    push bx
    push cx
    push dx
    push di

    mov di, numbuf
    mov bx, 10
    xor cx, cx

    or ax, ax
    jnz .divloop
    mov byte [di], '0'
    inc di
    jmp .print_it

.divloop:
    or ax, ax
    jz .done_div
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    jmp .divloop

.done_div:
.poploop:
    pop ax
    mov [di], al
    inc di
    loop .poploop

.print_it:
    mov byte [di], 0
    push si
    mov ah, 0x03
    mov si, numbuf
    int 0x21
    pop si

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==================================================================
; Data section
; ==================================================================

section .data

s_dot    db '.', 0
s_nodir  db 'Directory not found', 0
s_dirs   db ' directories, ', 0
s_files  db ' files', 0

s_tee    db CH_TEE, CH_DASH, CH_DASH, ' ', 0
s_corner db CH_CORNER, CH_DASH, CH_DASH, ' ', 0
s_vbar4  db CH_PIPE, ' ', ' ', ' ', 0
s_blank4 db ' ', ' ', ' ', ' ', 0

depth    db 0
is_last  db 0
ndirs    dw 0
nfiles   dw 0

prefix_type times MAX_DEPTH db 0
namebuf     times 16 db 0
argbuf      times 16 db 0
numbuf      times 8  db 0
