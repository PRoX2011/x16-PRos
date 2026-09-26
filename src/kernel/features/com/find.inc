; ==================================================================
; x16-PRos - walking a directory for 
;            FindFirst (int 0x21; AH = 4Eh) and 
;            FindNext (int 0x21; AH = 4Fh)
; ==================================================================

FIND_TEMPLATE   equ 0x00
FIND_INDEX      equ 0x0B
FIND_MASK       equ 0x0D
FIND_ATTR       equ 0x15
FIND_TIME       equ 0x16
FIND_DATE       equ 0x18
FIND_SIZE       equ 0x1A
FIND_NAME       equ 0x1E

; ==================================================================
; FIND_RESOLVE_DIR - split a search path into a directory and a pattern
;
; OUT: [cs:find_dir_cluster] = directory to search
;      SI = the pattern
;      CF = 1 if some directory along the way does not exist
; ==================================================================
find_resolve_dir:
    push ax
    push bx
    push cx
    push dx
    push di

    mov ax, [current_dir_cluster]
    mov [cs:find_saved_cluster], ax
    push ds
    pop es
    mov si, current_directory
    mov di, find_saved_path
    mov cx, 64
    cld
    rep movsb

    mov si, com_path_buffer

    cmp byte [si + 1], ':'
    jne .no_drive
    mov al, [si]
    cmp al, 'a'
    jb .letter_ready
    cmp al, 'z'
    ja .letter_ready
    sub al, 'a' - 'A'
.letter_ready:
    cmp al, [current_drive_char]
    jne .fail
    add si, 2
.no_drive:
    cmp byte [si], '\'
    je .from_root
    cmp byte [si], '/'
    jne .scan
.from_root:
    inc si
    mov word [current_dir_cluster], 0
    mov byte [current_directory], 0
.scan:
    mov bx, si
    mov di, si
.find_sep:
    mov al, [di]
    test al, al
    je .last
    cmp al, '\'
    je .component
    cmp al, '/'
    je .component
    inc di
    jmp .find_sep
.component:
    mov byte [di], 0
    inc di
    mov ax, bx
    cmp byte [bx], 0
    je .next
    cmp word [bx], '.'
    je .next
    call fs_change_directory
    jc .fail
.next:
    mov si, di
    jmp .scan
.last:
    mov ax, [current_dir_cluster]
    mov [cs:find_dir_cluster], ax
.restore:
    mov ax, [cs:find_saved_cluster]
    mov [current_dir_cluster], ax
    push ds
    pop es
    push si
    mov si, find_saved_path
    mov di, current_directory
    mov cx, 64
    cld
    rep movsb
    pop si

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

.fail:
    call .restore_only
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

.restore_only:
    mov ax, [cs:find_saved_cluster]
    mov [current_dir_cluster], ax
    push ds
    pop es
    push si
    mov si, find_saved_path
    mov di, current_directory
    mov cx, 64
    cld
    rep movsb
    pop si
    ret

find_dir_cluster    dw 0
find_saved_cluster  dw 0
find_saved_path     times 64 db 0

find_ret_ok:
    xor ax, ax
    and word [bp+6], 0xFFFE
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

find_ret_none:
    mov ax, 0x0012
    or word [bp+6], 1
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop bp
    iret

; ==================================================================
; FIND_DTA_ES_DI - ES:DI = the caller's DTA
; ==================================================================
find_dta_es_di:
    push ax
    mov ax, [dta_segment]
    test ax, ax
    jnz .have_seg
    mov ax, [dos_current_psp]
.have_seg:
    mov es, ax
    mov di, [dta_offset]
    pop ax
    ret

; ==================================================================
; FIND_MAKE_TEMPLATE - "*.EXE" -> "xxxxxxxxEXE" in find_tmpl
; IN : SI = ASCIIZ pattern
;      DS = KERNEL_DATA_SEG
; OUT: CF = 1 if the pattern cannot be expressed in 8.3
; ==================================================================
find_make_template:
    push ax
    push cx
    push si
    push di

    mov di, find_tmpl
    mov cx, 11
    mov al, ' '
    cld
    rep stosb

    mov di, find_tmpl
    xor cx, cx

.base:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    je .ext_start
    cmp al, '*'
    je .base_star
    cmp cx, 8
    jae .bad
    cmp al, 'a'
    jb .base_store
    cmp al, 'z'
    ja .base_store
    sub al, 32
.base_store:
    stosb
    inc cx
    jmp .base

.base_star:
    mov al, '?'
.base_fill:
    cmp cx, 8
    jae .after_star
    stosb
    inc cx
    jmp .base_fill
.after_star:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    jne .after_star

.ext_start:
    mov di, find_tmpl + 8
    xor cx, cx
.ext:
    lodsb
    test al, al
    jz .done
    cmp al, '*'
    je .ext_star
    cmp cx, 3
    jae .bad
    cmp al, 'a'
    jb .ext_store
    cmp al, 'z'
    ja .ext_store
    sub al, 32
.ext_store:
    stosb
    inc cx
    jmp .ext

.ext_star:
    mov al, '?'
.ext_fill:
    cmp cx, 3
    jae .done
    stosb
    inc cx
    jmp .ext_fill

.done:
    pop di
    pop si
    pop cx
    pop ax
    clc
    ret
.bad:
    pop di
    pop si
    pop cx
    pop ax
    stc
    ret

; ==================================================================
; FIND_STEP - find the next entry matching the DTA's search state
; IN : ES:DI = DTA
;      DS = KERNEL_DATA_SEG
; OUT: the DTA is filled, its index advanced
;      CF = 1 when none is left
; ==================================================================
find_step:
    push ax
    push bx
    push cx
    push dx
    push si
.scan:
    mov ax, [cs:find_idx]
    call find_entry_at
    jc .none
    test si, si
    jz .none

    ; end of directory?
    cmp byte [si], 0
    je .none
    cmp byte [si], 0xE5
    je .next
    cmp byte [si], '.'
    je .next

    mov al, [si + 11]
    test al, 0x08
    jnz .next
    mov ah, [cs:find_mask]
    or ah, 0x21
    not ah
    and al, ah
    jnz .next

    call find_match
    jc .next

    mov al, [si + 11]
    mov [es:di + FIND_ATTR], al
    mov ax, [si + 22]
    mov [es:di + FIND_TIME], ax
    mov ax, [si + 24]
    mov [es:di + FIND_DATE], ax
    mov ax, [si + 28]
    mov [es:di + FIND_SIZE], ax
    mov ax, [si + 30]
    mov [es:di + FIND_SIZE + 2], ax
    call find_store_name

    inc word [cs:find_idx]

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret

.next:
    inc word [cs:find_idx]
    jmp .scan

.none:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; ==================================================================
; FIND_ENTRY_AT - point SI at directory entry number AX
; Reads whatever sector holds it into disk_buffer.
; OUT: SI = entry
;      CF = 1 when the index is past the directory
; ==================================================================
find_entry_at:
    push es
    push ax
    push bx
    push cx
    push dx

    cmp word [cs:find_dir_cluster], 0
    jne .subdir

    cmp ax, [fs_root_ents]
    jae .past_end
    push ax
    call fs_read_root_dir
    pop ax
    mov cl, 5
    shl ax, cl
    mov si, disk_buffer
    add si, ax
    jmp .ok

.subdir:
    mov bx, ax
    mov cl, 4
    shr ax, cl
    and bx, 0x0F
    mov [cs:find_slot], bx

    push ax
    mov ax, [cs:find_dir_cluster]
    call fs_cluster_lba
    mov [cs:find_lba], ax
    pop ax

    mov cx, ax
    test cx, cx
    jz .sector_ready
.advance:
    mov ax, [cs:find_lba]
    call fs_next_dir_sector
    jc .past_end
    mov [cs:find_lba], ax
    loop .advance

.sector_ready:
    mov ax, [cs:find_lba]
    call fs_convert_l2hts
    mov bx, disk_buffer
    push es
    mov ax, ds
    mov es, ax
    mov ah, 2
    mov al, 1
    stc
    int 13h
    pop es
    jc .past_end

    mov si, [cs:find_slot]
    mov cl, 5
    shl si, cl
    add si, disk_buffer

.ok:
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    clc
    ret

.past_end:
    xor si, si
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    stc
    ret

; ==================================================================
; FIND_MATCH - compare find_tmpl with the 11 characters at SI
; OUT: CF = 0 on a match
; ==================================================================
find_match:
    push ax
    push cx
    push si
    push di
    mov di, find_tmpl
    mov cx, 11
.loop:
    mov al, [di]
    cmp al, '?'
    je .skip
    cmp al, [si]
    jne .no
.skip:
    inc si
    inc di
    loop .loop
    pop di
    pop si
    pop cx
    pop ax
    clc
    ret
.no:
    pop di
    pop si
    pop cx
    pop ax
    stc
    ret

; ==================================================================
; FIND_STORE_NAME - "NAME    EXT" -> "NAME.EXT", 0 at DTA+1E
; IN : SI = entry
;      ES:DI = DTA
; ==================================================================
find_store_name:
    pusha
    lea bx, [di + FIND_NAME]

    mov cx, 8
    push si
.base:
    mov al, [si]
    cmp al, ' '
    je .base_done
    mov [es:bx], al
    inc bx
    inc si
    loop .base
.base_done:
    pop si

    add si, 8
    cmp byte [si], ' '
    je .terminate
    mov byte [es:bx], '.'
    inc bx
    mov cx, 3
.ext:
    mov al, [si]
    cmp al, ' '
    je .terminate
    mov [es:bx], al
    inc bx
    inc si
    loop .ext

.terminate:
    mov byte [es:bx], 0
    popa
    ret

find_tmpl   times 11 db 0
find_idx    dw 0
find_mask   db 0
find_lba    dw 0
find_slot   dw 0
