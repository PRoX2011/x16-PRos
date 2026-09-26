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
.next:
    inc bl
    jmp .slot
.done:
    pop es
    popa
    ret

wm_seg dw 0
