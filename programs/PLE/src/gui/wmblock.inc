; ========================================================================
; WM_CREATE - claim the rendezvous block and advertise where it is
; IN : nothing
; OUT : [wm_seg] = block segment
; ========================================================================
wm_create:
    pusha
    push es

    call wm_probe
    jnc .reuse

    mov ah, 0x01
    mov bx, WM_BLOCK_SIZE
    int 0x23
    jc .fail
    mov [wm_seg], ax
    mov es, ax

    xor di, di
    mov cx, WM_BLOCK_SIZE
    xor al, al
    cld
    rep stosb

    mov word [es:WM_OFF_MAGIC], WM_MAGIC
    mov byte [es:WM_OFF_VERSION], WM_VERSION
    mov byte [es:WM_OFF_SLOTS], WM_TASK_MAX

    mov ax, es
    xor cx, cx
    mov es, cx
    mov word [es:WM_VEC * 4], 0
    mov [es:WM_VEC * 4 + 2], ax
    mov es, ax
    jmp .claim

.reuse:
    mov ax, es
    mov [wm_seg], ax

.claim:
    mov di, WM_OFF_ENTRIES
    mov cx, WM_TASK_MAX * WM_ENTRY_SIZE
    xor al, al
    cld
    rep stosb

    mov ah, 0x15
    int 0x23
    mov bl, al
    mov es, [wm_seg]
    mov [es:WM_OFF_OWNER], bl

    mov ah, 0x17
    int 0x23
    mov es, [wm_seg]
    mov [es:WM_OFF_OWNSEG], cx

    pop es
    popa
    clc
    ret
.fail:
    pop es
    popa
    stc
    ret

; ========================================================================
; WM_RELEASE - give up ownership of the block
; IN : nothing
; OUT : the block marked unowned
; ========================================================================
wm_release:
    pusha
    push es
    mov ax, [wm_seg]
    test ax, ax
    jz .done
    mov es, ax
    mov byte [es:WM_OFF_OWNER], WM_OWNER_NONE
.done:
    pop es
    popa
    ret

; ========================================================================
; WM_SET_WINDOW - hand a task its content rectangle
; IN : BL = task id, CX = x, DX = y, SI = width, DI = height
; OUT : nothing (all registers preserved)
; ========================================================================
wm_set_window:
    pusha
    push es
    mov ax, [wm_seg]
    test ax, ax
    jz .done
    mov es, ax
    call wm_entry
    mov bx, ax
    mov byte [es:bx + WM_E_FLAGS], WM_F_WINDOWED | WM_F_DIRTY
    mov [es:bx + WM_E_X], cx
    mov [es:bx + WM_E_Y], dx
    mov [es:bx + WM_E_W], si
    mov [es:bx + WM_E_H], di
.done:
    pop es
    popa
    ret

; ========================================================================
; WM_SET_CLIPS - hand a task the rectangles covering its window
; IN : BL = task id, CX = rectangle count, DS:SI = {x, y, w, h} array
; OUT : nothing (all registers preserved)
; ========================================================================
wm_set_clips:
    pusha
    push es
    mov ax, [wm_seg]
    test ax, ax
    jz .done
    cmp cx, WM_CLIP_MAX
    jbe .fits
    mov cx, WM_CLIP_MAX
.fits:
    mov es, ax
    call wm_entry
    mov bx, ax
    mov [es:bx + WM_E_CLIPN], cl
    mov di, bx
    add di, WM_E_CLIP
    shl cx, 2
    jcxz .done
    cld
    rep movsw
.done:
    pop es
    popa
    ret

; ========================================================================
; WM_ASK_CLOSE - ask a task to shut its window down
; IN : BL = task id
; OUT : nothing (all registers preserved)
; ========================================================================
wm_ask_close:
    pusha
    push es
    mov ax, [wm_seg]
    test ax, ax
    jz .done
    mov es, ax
    call wm_entry
    mov bx, ax
    or byte [es:bx + WM_E_FLAGS], WM_F_CLOSE
.done:
    pop es
    popa
    ret

; ========================================================================
; WM_SWEEP - drop the entries of tasks that are gone
; IN : nothing
; OUT : nothing (all registers preserved)
; ========================================================================
wm_sweep:
    pusha
    push es
    mov ax, [wm_seg]
    test ax, ax
    jz .done
    mov es, ax
    xor bx, bx
.slot:
    cmp bl, WM_TASK_MAX
    jae .done
    call wm_entry
    mov si, ax
    cmp byte [es:si + WM_E_FLAGS], 0
    je .next

    push bx
    mov ah, 0x17
    int 0x23
    pop bx
    jc .drop
    test al, al
    jnz .next
.drop:
    call wm_entry
    mov si, ax
    mov byte [es:si + WM_E_FLAGS], 0
    mov byte [es:si + WM_E_CLIPN], 0
    mov word [es:si + WM_E_KEY], 0
    mov byte [es:si + WM_E_WANT], 0
.next:
    inc bl
    jmp .slot
.done:
    pop es
    popa
    ret

wm_seg dw 0

; ========================================================================
; KBD_FOCUS_HIT - give the keyboard to the window under a press
; IN : [hit_kind], [hit_slot] from win_at
; OUT : [kbd_slot] = that window, or 0xFF for the desktop
; ========================================================================
kbd_focus_hit:
    push ax
    mov al, 0xFF
    cmp byte [hit_kind], 0
    je .set
    mov al, [hit_slot]
.set:
    mov [kbd_slot], al
    pop ax
    ret

; ========================================================================
; KBD_ROUTE - hand a waiting key to the focused window if it reads keys
; IN : nothing
; OUT : CF = 1 if the keyboard belongs to that window (the key is taken,
;       or left waiting while its previous key is unread), CF = 0 for the GUI
; ========================================================================
kbd_route:
    pusha
    push es
    xor bh, bh
    mov bl, [kbd_slot]
    cmp bl, MAX_WIN
    jae .gui
    cmp byte [w_open + bx], 0
    je .gui
    mov ax, [wm_seg]
    test ax, ax
    jz .gui
    mov es, ax
    mov bl, [w_task + bx]
    call wm_entry
    mov di, ax
    test byte [es:di + WM_E_WANT], WM_W_KEYS
    jz .gui
    mov ah, 0x01
    int 0x16
    jz .mine
    cmp word [es:di + WM_E_KEY], 0
    jne .mine
    mov ah, 0x00
    int 0x16
    mov [es:di + WM_E_KEY], ax
.mine:
    pop es
    popa
    stc
    ret
.gui:
    pop es
    popa
    clc
    ret
